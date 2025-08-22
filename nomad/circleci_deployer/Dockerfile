FROM quay.io/podman/stable:latest AS podman
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
      fuse-overlayfs \
      uidmap \
      slirp4netns \
      build-essential \
      ca-certificates \
      curl \
      git \
      libz-dev \
      ; \
      sudo rm -rf /var/lib/apt/lists/*

# Check out ruby-build and install
RUN sudo git clone https://github.com/sstephenson/ruby-build.git /usr/local/ruby-build
RUN sudo /usr/local/ruby-build/install.sh

# Install the version of Ruby we want and add to the path
RUN sudo ruby-build ${RUBY_VERSION} /usr/local/ruby
ENV PATH="/usr/local/ruby/bin:${PATH}"

RUN echo "$(ruby --version)"

# Copy podman's podman-in-podman compatible configuration files
# Pulled from https://quay.io/repository/podman/stable/manifest/sha256:b83bf5b82d8d02a49dfa7f8b5c35e6ffc826e6dfb1592b7ec2e17100dd47c810
COPY --from=podman --chown=circleci /etc/containers/storage.conf /etc/containers/storage.conf
COPY --from=podman --chown=circleci /home/podman/.config/containers/containers.conf /home/circleci/.config/containers/containers.conf
COPY --from=podman --chown=circleci /etc/containers/containers.conf /etc/containers/containers.conf
RUN /bin/sh -c "mkdir -p /home/circleci/.local/share/containers"

