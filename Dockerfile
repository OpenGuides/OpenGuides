FROM ubuntu:focal

RUN echo "debconf debconf/frontend select Teletype" | debconf-set-selections
RUN apt update && \
    apt install -y cpanminus \
    build-essential \
    openssl \
    openguides \
    && apt clean
RUN cpanm --quiet --notest Config::Tiny Geo::HelmertTransform Test::HTML::Content Wiki::Toolkit::Plugin::Ping Devel::Cover::Report::Coveralls Test::JSON Class::Accessor Lucy OpenGuides Plack Starman Plack::App::CGIBin CGI::Emulate::PSGI CGI::Compile
COPY . /tmp/openguides
ENV AUTOMATED_TESTING=1
WORKDIR /tmp/openguides
COPY docker/wiki.conf .
RUN perl Build.PL && ./Build install && rm -rf /tmp/openguides
COPY docker/app.psgi /usr/app/app.psgi
RUN mkdir /usr/app/indexes
RUN useradd openguides -s /bin/bash -m -U
RUN chown -R openguides: /usr/app
USER openguides
WORKDIR /usr/app/
CMD plackup
