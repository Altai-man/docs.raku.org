## docky

A docky demo.

### Installation

When having Rakudo and zef installed and also node, npm, coffeescript and graphviz, clone the repo,
then in its directory:

```
# Install dependencies
zef --deps-only install .
# Fresh docs copy
git clone https://github.com/Raku/doc.git
# Highlighting
cd highlights
git clone https://github.com/Raku/atom-language-perl6.git
npm install .
npm rebuild
cd ..
# This will take a lot of time for the first time, because lots of pod files are cached
# It can take e.g. 5 minutes, you were warned, really
# It will be much faster next time
DOCKY_PORT=20000 DOCKY_HOST=localhost raku -Ilib service.p6
```
