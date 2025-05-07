FROM circleci/runner-agent:machine-3
ARG RUBY_VERSION=3.4.3
# Install packages needed for ruby-build
RUN sudo apt-get update -qq && DEBIAN_FRONTEND=noninteractive sudo apt-get install -yq --no-install-recommends \
  build-essential \
  ca-certificates \
  curl \
  git \
  libz-dev \
  libffi-dev

# Check out ruby-build and install
RUN sudo git clone https://github.com/sstephenson/ruby-build.git /usr/local/ruby-build
RUN sudo /usr/local/ruby-build/install.sh

# Install the version of Ruby we want and add to the path
RUN sudo ruby-build ${RUBY_VERSION} /usr/local/ruby
ENV PATH="/usr/local/ruby/bin:${PATH}"

RUN echo "$(ruby --version)"
