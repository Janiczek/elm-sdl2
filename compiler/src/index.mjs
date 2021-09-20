import fs from 'fs/promises';
import util from 'util';
import child_process from 'child_process';
import Mustache from 'mustache';
import Elm from '../dist/compiler.js';
Mustache.escape = x => x;
const exec = util.promisify(child_process.exec);
const filename = '../example/ExampleImage.elm';
const contents = await fs.readFile(filename, 'utf-8');
const rustTemplate = await fs.readFile('./src/template.rs', 'utf-8');
const flags = {files: [{filename, contents}]};
const app = Elm.Elm.Compiler.init({flags});
app.ports.outputRust.subscribe(async compiledCode => {
  console.log('Got some compiled Rust code!');
  const rustFile = Mustache.render(rustTemplate, {compiledCode});
  await fs.writeFile('./output/src/main.rs', rustFile);
  await exec('cd ./output && cargo run');
});
app.ports.print.subscribe(async msg => console.log(msg));
