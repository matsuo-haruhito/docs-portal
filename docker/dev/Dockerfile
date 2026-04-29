FROM ruby:4.0.2-alpine3.23

RUN apk update && \
    apk add \
    build-base \
    postgresql-dev \
    postgresql-client \
    yaml-dev \
    tzdata \
    git \
    vim \
    bash \
    nodejs \
    npm \
    sudo \
    shared-mime-info

ARG uid
ARG gid

RUN addgroup -g $gid docker && \
    adduser -S -u $uid -G docker docker && \
    echo 'docker ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers && \
    echo 'docker:docker' | chpasswd

#WORKDIR /app

#COPY entrypoint.sh /usr/local/bin/entrypoint.sh
#RUN chmod +x /usr/local/bin/entrypoint.sh

USER docker

#ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
