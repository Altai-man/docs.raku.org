## docs.raku.org website source code (BETA)

This is the source code of the updated `docs.raku.org` website.

### Contributing

We need your help! Do not hesitate to fix and improve things if you like the project's idea.

We need volunteers to:

- Reviewing project's documentation (just send patches for all the silly typos!)
- Improve Raku code (there are still some mysteries and a lot of room for improvement)
- Utilize plenty of opportunities to speed up the website rendering
- Improve infrastructure (you write kubernetes? We love you and need your help!)

If you feel interested in contributing, feel warmly welcome to

- Send PRs
- Address existing tickets
- Ping [Altai-man](https://github.com/Altai-man) if you want to help with infrastructure or just pondering what
  you can help with

### Installation

The most safe way to run the website locally is to use Docker. We provide a Dockerfile which
does all the mundane steps for you, so you need to build the container and run it:

#### Docker

```
-> docker build -t next-docs -f infra/Dockerfile.cro .
-> docker run -p 10000:10000 next-docs
# Now you can access the site via browser at `http://localhost:10000`
```

#### Cro + Nginx setup

A docker-compose setup exists. It describes two containers,
one is the actual Cro application and the other one is a Nginx container
to reverse-proxy requests and add things like caching and avoiding exposure of the app itself.

#### Manual installation

Another way is to do everything manually.

When having Rakudo and zef installed, but also NodeJS, Coffeescript and graphviz, do
the following:

```
# Get a fresh docs copy
git clone https://github.com/Raku/doc.git
# Get patched Documentable and Pod::To::HTML
git clone -b devel https://github.com/Raku/Documentable.git && cd Documentable && zef install . && cd ..
git clone -b devel https://github.com/Raku/Pod-To-HTML.git && cd Pod-To-HTML && zef install . && cd ..

# Install missing Raku-level dependencies
zef --deps-only install .
# Setup highlighting
cd highlights && git clone https://github.com/Raku/atom-language-perl6.git && npm install . && npm rebuild && cd ..
# This will take A LOT of time for the first time, because lots of pod files are to be cached
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

As the ultimate temporary solution we simply cache all pages on first run.
For dev environment it is not so important and the cache is not heated by the app,
but for production environment should be.

The cache heater is enabled if the `PRODUCTION_ENV` env variable is set.

#### Examples execution

We use containers provided by the [glot](https://github.com/glotcode) project to execute
code examples. In production environment we send snippets to our secret server and for
testing environment you may want to set up something simpler.

Until https://github.com/glotcode/docker-run/issues/6 is not resolved we use our own
small server to pass the code execution requests to the executor. To recreate the setup:

``` sh
docker pull glot/raku:latest # pull the raku image
DOCKY_EXAMPLES_EXECUTOR_KEY=... raku tools/glot-server.raku # run the server with a certain token
# Run the application locally with additional env variables:
DOCKY_PORT=20000 DOCKY_HOST=localhost DOCKY_EXAMPLES_EXECUTOR_HOST=http://localhost:8088/run DOCKY_EXAMPLES_EXECUTOR_KEY=... raku -Ilib service.p6
# OR run it in a docker container, while providing appropriate values for the DOCKY_EXAMPLES_EXECUTOR_HOST and DOCKY_EXAMPLES_EXECUTOR_KEY env variables
```

Note the docker setup uses host network to be able to access the examples server.
It is possible to avoid this and get back to docker-only setup when the upstream issue is resolved.

#### Updating the content

The application keeps a version of the `doc` repository content cached.
To ask it for an update, send a GET request to `/update?token=...` route with
an appropriate security token. The server then proceeds to update the git repo
and the pages registry.
