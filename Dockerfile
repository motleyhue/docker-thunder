FROM quay.io/continuouspipe/php7.1-nginx:stable

RUN set -x && curl -sL https://deb.nodesource.com/setup_8.x > /tmp/install-node.sh \
 && bash /tmp/install-node.sh \
 && apt-get update -qq \
 && DEBIAN_FRONTEND=noninteractive apt-get -qq -y --no-install-recommends install \
    bzip2 \
    g++ \
    nodejs \
 \
 # Configure Node dependencies \
 && npm config set --global loglevel warn \
 && rm -rf /usr/lib/node_modules/gulp /usr/lib/node_modules/marked /usr/lib/node_modules/node-gyp /usr/lib/node_modules/node-sass \
 && npm install --global \
    gulp \
    node-gyp \
 \
 && npm cache clean --force \
 \
 # Clean the image \
 && apt-get auto-remove -qq -y \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

ARG GITHUB_TOKEN=
ARG ASSETS_S3_BUCKET=
ARG ASSETS_ENV=
ARG ASSETS_DATABASE_ENABLED=false
ARG AWS_ACCESS_KEY_ID=
ARG AWS_SECRET_ACCESS_KEY=
ARG DEVELOPMENT_MODE=false
ARG RUN_BUILD=
ENV DEVELOPMENT_MODE=$DEVELOPMENT_MODE

COPY . /app
COPY ./tools/docker/etc/ /etc/
WORKDIR /app
RUN chown -R build:build /app && container build
