FROM ruby:alpine3.6

MAINTAINER Andrius Kairiukstis <k@andrius.mobi>

RUN apk update \
\
&& apk add \
     bash \
     build-base \
     git \
     libxml2-dev \
     libxslt-dev \
     libffi-dev \
     pcre-dev \
     libstdc++ \
     libxml2 \
     libxslt \
     libffi \
     libzmq \
     pcre \
     zlib \
     tzdata \
     tmux \
     vim \
     mc \
\
&& cp -R /usr/share/zoneinfo/Europe/Amsterdam /etc/localtime \
&& echo 'Europe/Amsterdam' > /etc/timezone \
\
&& find /usr/lib/libzmq.so* -type f | head -1 | awk '{print ""$1" /usr/lib/libzmq.so"}' | xargs ln -s \
\
&& gem install --no-rdoc --no-ri \
     pry

WORKDIR /app
ADD . /app/
