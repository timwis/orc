# Forked from theodesp/chicken-scheme-alpine
FROM alpine:latest

# Configurations.
ENV CHICKEN_VERSION 4.13.0
ENV PLATFORM linux

# Install Packages
RUN apk update \
  && apk --no-cache --update add make gcc musl-dev \
    ca-certificates openssl sqlite \
  && update-ca-certificates
RUN set -o pipefail && wget -qO- https://code.call-cc.org/releases/$CHICKEN_VERSION/chicken-$CHICKEN_VERSION.tar.gz | tar xzv

WORKDIR /chicken-$CHICKEN_VERSION

# Install Chicken
RUN make PLATFORM=$PLATFORM && make PLATFORM=$PLATFORM install && make PLATFORM=$PLATFORM check
RUN rm -rf /chicken-$CHICKEN_VERSION

ADD https://github.com/register-dynamics/sql-de-lite/archive/pu.tar.gz /usr/vendor/sql-de-lite.tar.gz
RUN cd /usr/vendor/ \
  && tar -xvf sql-de-lite.tar.gz \
  && cd sql-de-lite-pu \
  && chicken-install

ADD https://github.com/register-dynamics/merkle-tree/archive/next.tar.gz /usr/vendor/merkle-tree.tar.gz
RUN cd /usr/vendor/ \
  && tar -xvf merkle-tree.tar.gz \
  && cd merkle-tree-next \
  && chicken-install

WORKDIR /usr/app

COPY chicken .
RUN chicken-install

CMD ["orc"]
