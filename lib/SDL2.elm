module SDL2 exposing (SDLProgram, animation, image, picture)


type SDLProgram
    = Image String
    | Picture Frame
    | Animation (Int -> Frame)



-- TODO | Game { init, update, view, subscriptions }
-- TODO remove the Image one once Picture is working?


image : String -> SDLProgram
image filepath =
    Image filepath


picture : Frame -> SDLProgram
picture frame =
    Picture frame


animation : (Int -> Frame) -> SDLProgram
animation toFrame =
    Animation toFrame
