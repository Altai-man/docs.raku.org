FROM fedora:32
RUN mkdir /app
COPY . /app
WORKDIR /app
# install main dependencies
RUN yum install -y nodejs graphviz openssl-devel git coffee-script make gcc gcc-g++
# we need a static code highlighter
RUN cd highlights && git clone https://github.com/Raku/atom-language-perl6.git && npm install . && npm rebuild
# install fresh Rakudo
RUN curl -1sLf 'https://dl.cloudsmith.io/public/nxadm-pkgs/rakudo-pkg/setup.rpm.sh' | sudo -E bash
RUN dnf install -y rakudo-pkg
# Update PATH, set env variables
ENV PATH=/root/.raku/bin:/opt/rakudo-pkg/bin:/opt/rakudo-pkg/share/perl6/site/bin:$PATH DOCKY_PORT="10000" DOCKY_HOST="0.0.0.0"
# So install zef, update it
RUN /opt/rakudo-pkg/bin/install-zef
RUN zef update
# We need our fork of Pod::To::HTML for a faster renderer
git clone https://github.com/Altai-man/Pod-To-HTML.git && cd Pod-To-HTML && zef install .
# We need our fork of Documentable at this stage
RUN git clone -b search-categories-streamlined https://github.com/Raku/Documentable.git && cd Documentable && zef install .
# We need our fork of docs at this stage
RUN git clone -b search-categories https://github.com/Raku/doc.git
# Install raku dependencies and check sanity
RUN zef install Cro::WebApp
RUN zef install --deps-only . && raku -c -Ilib service.p6
EXPOSE 10000
CMD raku -Ilib service.p6
