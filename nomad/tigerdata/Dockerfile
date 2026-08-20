FROM circleci/runner-agent:machine-3
ARG RUBY_VERSION=3.4.3
# 1. Install dependencies - pulled from build-pack-deps:
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
      jq \
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
      build-essential \
      ca-certificates \
      curl \
      git \
      libz-dev \
      ; \
      sudo rm -rf /var/lib/apt/lists/*

RUN set -ex; \
      sudo install -m 0755 -d /etc/apt/keyrings; \
      curl -fsSL https://download.docker.com/linux/debian/gpg \
      | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg; \
      sudo chmod a+r /etc/apt/keyrings/docker.gpg; \
      echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.gpg] \
      https://download.docker.com/linux/debian bookworm stable" \
      | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null; \
      sudo apt-get update; \
      sudo apt-get install -y --no-install-recommends docker-ce-cli; \
      sudo rm -rf /var/lib/apt/lists/*; \
      docker --version

# 2. Install the latest stable Google Chrome, required by Capybara feature specs
RUN set -ex; \
      curl -fsSL -o /tmp/google-chrome-stable_current_amd64.deb \
      https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb; \
      sudo apt-get update; \
      sudo apt-get install -y --no-install-recommends \
      /tmp/google-chrome-stable_current_amd64.deb; \
      rm /tmp/google-chrome-stable_current_amd64.deb; \
      sudo rm -rf /var/lib/apt/lists/*; \
      google-chrome --version

# 3. Install the ChromeDriver matching the Chrome installed above. ChromeDriver
# refuses to drive a Chrome with a different major version, so resolve the
# newest driver sharing Chrome's major rather than whatever is currently
# "stable" -- the Debian package feed and the Chrome for Testing stable channel
# roll forward independently and are frequently a major version apart. Fail the
# build outright if no matching driver exists, since a mismatched pair would
# otherwise ship an image that only breaks once tests run.
RUN set -ex; \
      CHROME_VERSION="$(google-chrome --version | awk '{print $3}')"; \
      CHROME_MAJOR="${CHROME_VERSION%%.*}"; \
      CHROMEDRIVER_URL="$(curl -fsSL \
      https://googlechromelabs.github.io/chrome-for-testing/known-good-versions-with-downloads.json \
      | jq -r --arg major "$CHROME_MAJOR" \
      'last(.versions[] | select(.version | startswith($major + ".")) | select(.downloads.chromedriver != null) | select(any(.downloads.chromedriver[]; .platform == "linux64"))) | .downloads.chromedriver[]? | select(.platform == "linux64") | .url')"; \
      if [ -z "$CHROMEDRIVER_URL" ]; then \
      echo "No linux64 ChromeDriver published for Chrome major ${CHROME_MAJOR}" >&2; \
      exit 1; \
      fi; \
      curl -fsSL -o /tmp/chromedriver.zip "$CHROMEDRIVER_URL"; \
      unzip -q /tmp/chromedriver.zip -d /tmp; \
      sudo install -m 0755 /tmp/chromedriver-linux64/chromedriver /usr/local/bin/chromedriver; \
      rm -rf /tmp/chromedriver.zip /tmp/chromedriver-linux64; \
      DRIVER_MAJOR="$(chromedriver --version | awk '{print $2}' | cut -d. -f1)"; \
      test "$DRIVER_MAJOR" = "$CHROME_MAJOR"; \
      chromedriver --version

# Check out ruby-build and install
RUN sudo git clone https://github.com/sstephenson/ruby-build.git /usr/local/ruby-build
RUN sudo /usr/local/ruby-build/install.sh

# Install the version of Ruby we want and add to the path
RUN sudo ruby-build ${RUBY_VERSION} /usr/local/ruby
ENV PATH="/usr/local/ruby/bin:${PATH}"

RUN echo "$(ruby --version)"
