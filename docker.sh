#!/bin/sh

docker build --pull -t rubygems . && \
docker run -ti --rm --name=rubygems -v ${PWD}:/app rubygems sh
