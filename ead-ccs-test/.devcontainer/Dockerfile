# .devcontainer/Dockerfile
FROM ruby:4.0.10-trixie AS base

# Avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      build-essential \
      git \
      curl \
      libpq-dev \
      postgresql-client \
      libvips42 \
      libvips-dev \
      shared-mime-info \
      nodejs \
      npm \
      vim \
      less \
      sudo \
    && rm -rf /var/lib/apt/lists/*

# Install Yarn via npm (avoids the conflicting Debian "yarn" package)
RUN npm install -g yarn || true

# Create a non-root user that matches remoteUser in devcontainer.json
ARG USERNAME=local-dev
ARG USER_UID
ARG USER_GID

RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m -s /bin/bash $USERNAME \
    && echo "$USERNAME ALL=(root) NOPASSWD:ALL" > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME

# Install bundler
ENV BUNDLE_PATH=/usr/local/bundle \
BUNDLE_APP_CONFIG=/usr/local/bundle
RUN gem install bundler

USER $USERNAME
WORKDIR /workspaces