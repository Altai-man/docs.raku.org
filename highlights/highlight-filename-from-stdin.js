const Highlights = require('highlights');
const fs = require('fs');
const path = require('path');
const highlighter = new Highlights();
const modPath = require.resolve('./atom-language-perl6/package.json');
highlighter.requireGrammarsSync({modulePath: modPath});

const rakuGrammarPath = path.join(path.dirname(modPath), 'grammars', 'raku.cson');
const rakuScopeName = fs.existsSync(rakuGrammarPath) ? 'source.raku' : 'source.perl6fe';

const stdin = process.openStdin();
stdin.setEncoding('utf8');
const mystdout = process.stdout;
function process_file(given_path) {
  const full_path = path.resolve(given_path);
  let i = 0;
  let e = true;
  while (e && !fs.existsSync(given_path)) {
    i++;
    if (i > 100000) {
      console.error(`Highlights runner: ERROR Giving up looking for the file. Cannot read file {full_path}`);
      e = false;
    }
  }
  if (i > 0)
    console.error(`Highlights runner: file #{full_path} does not exist. Tried {i} times.`);

  fs.readFile(full_path, 'utf8', (read_err, file_str) => {
    if (read_err)
      return void console.error(read_err);
    highlighter.highlight({fileContents: file_str, scopeName: rakuScopeName}, (hl_err, html) => {
      if (hl_err)
        return void console.error(hl_err);
      const obj = {file: full_path, html};
      mystdout.write(JSON.stringify(obj) + '\n' );
    });
  });
}

const readline = require('readline');
const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout,
  terminal: false
});
rl.on('line', process_file);
