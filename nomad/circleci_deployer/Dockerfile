FROM circleci/runner-agent:machine-3
ARG RUBY_VERSION=3.4.3
# Install dependencies - pulled from build-pack-deps:
# https://github.com/docker-library/buildpack-deps/blob/d0ecd4b7313e9bc6b00d9a4fe62ad5787bc197ae/debian/bookworm/Dockerfile
RUN set -ex; \
      sudo apt-get update; \
      sudo apt-get install -y --no-install-recommends \
      autoconf \
      automake \
      bzip2 \
      default-libmysqlclient-dev \
      dpkg-dev \
      file \
      g++ \
      gcc \
      gnupg2 \
      imagemagick \
      libbz2-dev \
      libc6-dev \
      libcurl4-openssl-dev \
      libdb-dev \
      libevent-dev \
      libffi-dev \
      libgdbm-dev \
      libglib2.0-dev \
      libgmp-dev \
      libjpeg-dev \
      libkrb5-dev \
      liblzma-dev \
      libmagickcore-dev \
      libmagickwand-dev \
      libmaxminddb-dev \
      libncurses5-dev \
      libncursesw5-dev \
      libpng-dev \
      libpq-dev \
      libreadline-dev \
      libsqlite3-dev \
      libssl-dev \
      libtool \
      libwebp-dev \
      libxml2-dev \
      libxslt-dev \
      libyaml-dev \
      make \
      patch \
      unzip \
      xz-utils \
      zlib1g-dev \
      podman \
      ; \
      sudo rm -rf /var/lib/apt/lists/*
# Install packages needed for ruby-build
RUN sudo apt-get update -qq && DEBIAN_FRONTEND=noninteractive sudo apt-get install -yq --no-install-recommends \
build-essential \
ca-certificates \
curl \
git \
libz-dev

# Check out ruby-build and install
RUN sudo git clone https://github.com/sstephenson/ruby-build.git /usr/local/ruby-build
RUN sudo /usr/local/ruby-build/install.sh

# Install the version of Ruby we want and add to the path
RUN sudo ruby-build ${RUBY_VERSION} /usr/local/ruby
ENV PATH="/usr/local/ruby/bin:${PATH}"

# Install podman rootless dependencies.
RUN sudo apt-get update -qq && DEBIAN_FRONTEND=noninteractive sudo apt-get install -yq --no-install-recommends \
uidmap \
slirp4netns

# Enabling back support for SHA1 signed certificates
RUN sudo apt-get install crypto-policies
# RUN sudo update-crypto-policies --set DEFAULT:SHA1

RUN echo "$(ruby --version)"
