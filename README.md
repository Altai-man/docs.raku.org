## docky

A docky demo.

### Installation

When having Rakudo and zef installed, clone the repo,
then in its directory:

```
cd ..
git clone https://github.com/Raku/Pod-To-HTML.git -b enhance # Make sure Pod::To::HTML is at correct branch
cd Pod-To-HTML
zef install .
cd ../docky
git clone https://github.com/Raku/doc.git
zef --deps-only install .
DOCKY_PORT=20000 DOCKY_HOST=localhost raku -Ilib -I../Pod-To-HTML/lib service.p6
```
