FROM ubuntu:16.04
MAINTAINER Harry <docker-virtualbox5@midnight-labs.org>

ENV DEBIAN_FRONTEND noninteractive

# The virtualbox driver device must be mounted from host
VOLUME /dev/vboxdrv

RUN apt-get update
RUN apt-get -y install curl wget

COPY .install-virtualbox.sh /
RUN /.install-virtualbox.sh
