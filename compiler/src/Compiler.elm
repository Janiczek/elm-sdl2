port module Compiler exposing (main)

import Dict exposing (Dict)
import Elm.Parser
import Elm.Processing exposing (ProcessContext)
import Elm.RawFile exposing (RawFile)
import Elm.Syntax.Declaration exposing (Declaration(..))
import Elm.Syntax.Expression exposing (Expression(..))
import Elm.Syntax.File exposing (File)
import Elm.Syntax.Node as Node
import Result.Extra as Result


main : Program Flags Model Msg
main =
    Platform.worker
        { init = init
        , update = update
        , subscriptions = subscriptions
        }


port outputRust : String -> Cmd msg


port print : String -> Cmd msg


type alias Flags =
    { files :
        List
            { filename : String
            , contents : String
            }
    }


type alias Model =
    ()


type Msg
    = NoOp


init : Flags -> ( Model, Cmd Msg )
init flags =
    let
        rustCode : Result String String
        rustCode =
            flags.files
                |> processFiles
                |> Result.andThen compileMain
    in
    ( ()
    , case rustCode of
        Err error ->
            print <| "Couldn't compile: " ++ error

        Ok rustCode_ ->
            outputRust rustCode_
    )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp ->
            ( model, Cmd.none )


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none


processFiles : List { filename : String, contents : String } -> Result String (Dict String File)
processFiles files =
    let
        filenames : List String
        filenames =
            List.map .filename files

        rawFiles : Result String (List RawFile)
        rawFiles =
            files
                |> List.map .contents
                |> Result.combineMap Elm.Parser.parse
                |> Result.mapError Debug.toString
    in
    rawFiles
        |> Result.map
            (\rawFiles_ ->
                let
                    context : ProcessContext
                    context =
                        List.foldl Elm.Processing.addFile Elm.Processing.init rawFiles_

                    files_ : List File
                    files_ =
                        List.map (Elm.Processing.process context) rawFiles_
                in
                List.map2 Tuple.pair filenames files_
                    |> Dict.fromList
            )


compileMain : Dict String File -> Result String String
compileMain files =
    findMainDecl files
        |> Result.andThen findImageCall
        |> Result.map Debug.toString


findImageCall : Expression -> Result String String
findImageCall expr =
    case expr of
        Application [ fn, arg ] ->
            case List.map Node.value [ fn, arg ] of
                [ FunctionOrValue [ "SDL2" ] "image", Literal literal ] ->
                    Ok literal

                _ ->
                    Err "`main` expr was something unexpected"

        _ ->
            Err "`main` expr was something unexpected"


findMainDecl : Dict String File -> Result String Expression
findMainDecl files =
    files
        |> Dict.toList
        |> List.filterMap
            (\( _, file ) ->
                file.declarations
                    |> List.filterMap
                        (\decl ->
                            case Node.value decl of
                                FunctionDeclaration fn ->
                                    let
                                        fnDecl =
                                            Node.value fn.declaration
                                    in
                                    if Node.value fnDecl.name == "main" then
                                        Just <| Node.value fnDecl.expression

                                    else
                                        Nothing

                                _ ->
                                    Nothing
                        )
                    |> List.head
            )
        |> List.head
        |> Result.fromMaybe "Couldn't find `main` declaration"
