## docs.raku.org website source code (BETA)

This is the source code of the updated `docs.raku.org` website.

### Contributing

We need your help! Do not hesitate to fix and improve things if you like the project's idea.

We need volunteers to:

- Reviewing project's documentation (just send patches for all the silly typos!)
- Improve JS side of things (we lack some small goodies like a spinner for `Run example` action, as well as a search page...)
- Improve Raku code (there are still some mysteries and a lot of room for improvement)
- Utilize plenty of opportunities to speed up the website rendering
- Improve infrastructure (you write kubernetes? We love you and need your help!)

If you feel interested in contributing, feel warmly welcome to

- Send PRs
- Address existing tickets
- Ping [Altai-man](https://github.com/Altai-man) if you want to help with infrastructure or just pondering what
  you can help with

### Installation

= = WARNING START = =

As we are in beta, lots of things were re-done in a breaking matter and not everybody likes that transition period.
While we strive to keep the main, existing website going until this one is accepted (or ouch rejected) and matured,
this also means we have to dance around our workflow not to break existing ones, so expect
e.g. cloning branches until all the cuts are tied.

= = WARNING END = =

The most safe way to run the website locally is to use Docker. We provide a Dockerfile which
does all the mundane steps for you, so you need to build the container and run it:

#### Docker

```
-> docker build -t next-docs -f infra/Dockerfile.cro .
-> docker run -p 10000:10000 next-docs
# Now you can access the site via browser at `http://localhost:10000`
```

#### Manual installation

Another way is to do everything manually.

When having Rakudo and zef installed, but also NodeJS, Coffeescript and graphviz, do
the following:

```
# Get a fresh docs copy
git clone -b search-categories https://github.com/Raku/doc.git
# Get patched Documentable
git clone -b search-categories-streamlined https://github.com/Raku/Documentable.git && cd Documentable && zef install . && cd ..
# Install missing Raku-level dependencies
zef --deps-only install .
# Setup highlighting
cd highlights && git clone https://github.com/Raku/atom-language-perl6.git && npm install . && npm rebuild && cd ..
# This will take A LOT of time for the first time, because lots of pod files are cached
# It can take e.g. 5 minutes, you were warned, really
# It will be much faster next time
DOCKY_PORT=20000 DOCKY_HOST=localhost raku -Ilib service.p6
# Now you can access the site via browser at `http://localhost:20000`
```

#### Page rendering speed

As for now, rendering a page takes a huge amount of time, much more than the desired
"less than 100 ms" hard limit. While we already did some steps toward improving
this process, [here](https://github.com/Raku/Pod-To-HTML/pull/80), [here](https://github.com/Raku/Pod-To-HTML/pull/83),
[here](https://github.com/Altai-man/Pod-To-HTML/commit/456c210614c2b682ff20caa5ae9927994f9811aa) etc
it is clearly not enough.

As an ultimate temporary solution we simply cache pages on first run.
For dev environment it is not so important and caching is not applied, for production
environment it is.

The cache heater is enabled if the `PRODUCTION_ENV` env variable is set.

#### Examples execution

We use containers provided by the [glot](https://github.com/glotcode) project to execute
code examples. In production environment we send snippets to our secret server and for
testing environment you probably want to setup yourself a Docker container if you 
want to work on this piece of the website (which is welcome!).

See instructions for setting up your container [here](https://github.com/glotcode/docker-run/blob/main/docs/install/docker-ubuntu-20.10.md)

Next you want to setup environment variables that will be used for sending requests,
`DOCKY_EXAMPLES_EXECUTOR_HOST` and `DOCKY_EXAMPLES_EXECUTOR_KEY` to specify the host and
the access token, once its done you can play with examples execution locally.