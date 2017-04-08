FROM harryr/cockatoo:vmcloak

MAINTAINER harryr, https://github.com/harryr


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
  && apt-get install -y $buildDeps \
                          python \
                          tcpdump \
                          git-core \
                          supervisor \
                          openvpn \
                          strace \
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

RUN /usr/local/bin/pip install yara

RUN groupadd cuckoo \
 && useradd -d / -M -g cuckoo cuckoo \
 && useradd -d / -M -g cuckoo cuckoo-run

COPY cuckoo /cuckoo
WORKDIR /cuckoo

# Necessary to avoid weird apparmor problems
# apparmor="DENIED" operation="open" info="Failed name lookup - disconnected path" error=-13 profile="/usr/sbin/tcpdump"
RUN cp /usr/sbin/tcpdump /usr/local/bin/tcpdump && setcap cap_net_raw,cap_net_admin=eip /usr/local/bin/tcpdump

RUN python stuff/monitor.py
RUN python setup.py sdist
RUN python setup.py develop

ENV HOME=/
RUN mkdir /.cuckoo && /usr/local/bin/cuckoo community

#RUN echo "Clean up unnecessary files..." \
# && apt-get purge -y --auto-remove $buildDeps \
# && apt-get clean

ENTRYPOINT /usr/local/bin/cuckoo
