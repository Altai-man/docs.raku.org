## docky

A docky demo.

### Installation

When having Rakudo and zef installed, clone the repo,
then in its directory:

```
git clone  https://github.com/Altai-man/docs.raku.org.git
zef --deps-only install .
git clone https://github.com/Raku/doc.git
cd doc
make init-highlights
cd ..
# This will take a lot of time for the first time, because lots of pod files are cached
# It can take e.g. 5 minutes, you were warned, really
# It will be much faster next time
DOCKY_PORT=20000 DOCKY_HOST=localhost raku -Ilib service.p6
```
