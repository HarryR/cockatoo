FROM cockatoo:vmcloak

MAINTAINER harryr, https://github.com/harryr
# Based on https://github.com/blacktop/docker-cuckoo

# grab gosu for easy step-down from root
# RUN gpg --keyserver ha.pool.sks-keyservers.net --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4
# RUN arch="$(dpkg --print-architecture)" \
# 	&& set -x \
# 	&& curl -o /usr/local/bin/gosu -fSL "https://github.com/tianon/gosu/releases/download/1.3/gosu-$arch" \
# 	&& curl -o /usr/local/bin/gosu.asc -fSL "https://github.com/tianon/gosu/releases/download/1.3/gosu-$arch.asc" \
# 	&& gpg --verify /usr/local/bin/gosu.asc \
# 	&& rm /usr/local/bin/gosu.asc \
# 	&& chmod +x /usr/local/bin/gosu

ENV DEBIAN_FRONTEND noninteractive
ENV SSDEEP ssdeep-2.13
ENV PIP_NO_CACHE_DIR off
ENV PIP_DISABLE_PIP_VERSION_CHECK on

RUN apt-get install -y python-pip 
RUN pip install --upgrade pip wheel

# Install Cuckoo Sandbox Required Dependencies
RUN buildDeps='ca-certificates \
               build-essential \
               libssl-dev \
               libffi-dev \
               libxml2-dev \
               libxslt1-dev \
               libjpeg8-dev \
               zlib1g-dev \
               python-dev \
               python-pip \
               apt-utils \
               adduser \
               numactl \
               curl' \
  && set -x \
  && apt-get update -qq \
  && apt-get install -y $buildDeps \
                          python \
                          tcpdump \
                          git-core \
                          supervisor \
                          net-tools iptables \
                          python-dpkt \
                          python-magic \
                          python-gridfs \
                          python-chardet \
                          python-libvirt --no-install-recommends

RUN echo "Install ssdeep..." \
  && curl -Ls https://downloads.sourceforge.net/project/ssdeep/$SSDEEP/$SSDEEP.tar.gz > /tmp/$SSDEEP.tar.gz \
  && cd /tmp \
  && tar zxvf $SSDEEP.tar.gz \
  && cd $SSDEEP \
  && ./configure \
  && make \
  && make install \
  && echo "Install pydeep..." \
  && cd /tmp \
  && git clone https://github.com/kbandla/pydeep.git \
  && cd pydeep \
  && python setup.py build \
  && python setup.py install

RUN apt-get install -y python-psycopg2 ipython python-pil python-m2crypto python-m2ext
RUN /usr/local/bin/pip install mitmproxy

# git clone https://github.com/HarryR/cuckoo.git --branch bugfixes --single-branch /cuckoo \
# chown -R cuckoo:cuckoo /cuckoo \

COPY cuckoo/requirements.txt /tmp/cuckoo-requirements.txt
RUN /usr/local/bin/pip install -r /tmp/cuckoo-requirements.txt

COPY cuckoo/distributed/requirements.txt /tmp/distributed-requirements.txt
RUN /usr/local/bin/pip install -r /tmp/distributed-requirements.txt

RUN /usr/local/bin/pip install yara beanstalkc

COPY cuckoo /cuckoo
WORKDIR /cuckoo

#RUN python setup.py sdist
#RUN python setup.py develop
#RUN python setup.py install

RUN groupadd cuckoo \
 && useradd -d / -M -g cuckoo cuckoo \
 && useradd -d / -M -g cuckoo cuckoo-run \
 && cd /cuckoo \
 && python utils/community.py -waf

RUN echo "Clean up unnecessary files..." \
 && apt-get purge -y --auto-remove $buildDeps \
 && apt-get clean

VOLUME ["/cuckoo/conf", "/root/.vmcloak"]

