FROM fedora:32
RUN mkdir /app
COPY . /app
WORKDIR /app
RUN yum install -y nodejs graphviz openssl-devel git coffee-script
RUN echo -e "[rakudo-pkg]\nname=rakudo-pkg\nbaseurl=https://dl.bintray.com/nxadm/rakudo-pkg-rpms/Fedora/32/x86_64\ngpgcheck=0\nenabled=1" | sudo tee -a /etc/yum.repos.d/rakudo-pkg.repo
RUN dnf install -y rakudo-pkg
ENV PATH=~/.raku/bin:/opt/rakudo-pkg/bin:/opt/rakudo-pkg/share/perl6/site/bin:$PATH DOCKY_PORT="10000" DOCKY_HOST="0.0.0.0"
RUN /opt/rakudo-pkg/bin/install-zef-as-user
RUN zef update
RUN zef install Cro::WebApp
RUN zef install Documentable
RUN zef install --deps-only . && raku -c -Ilib service.p6
EXPOSE 10000
CMD raku -Ilib service.p6
