FROM harryr/cockatoo:virtualbox5
MAINTAINER Harry Roberts <harry.roberts@xiphosresearch.co.uk>

# Example:
# docker run --net=host --privileged -v /dev/vboxdrv:/dev/vboxdrv -v /home/user/OperatingSystems:/mnt/vmcloak/iso -ti harryr/cockatoo:vmcloak /root/makevm.sh derp winxp XP_Pro.iso XXXXX-XXXXX-XXXXX-XXXXX-XXXXX

RUN apt-get -y install mkisofs genisoimage python2.7 python-pip dmidecode lshw sudo gcc-mingw-w64-i686 libffi-dev

RUN apt-get -y install libssl-dev

RUN apt-get clean 

RUN mkdir -p /mnt/isos/ /root/.vmcloak/
COPY makevm.sh /root/makevm.sh

VOLUME /root/.vmcloak/
VOLUME /mnt/isos

COPY vmcloak/requirements.txt /root/vmcloak-requirements.txt
RUN pip install -r /root/vmcloak-requirements.txt

COPY vmcloak /root/src
RUN cd /root/src && make -C utils && python setup.py install

CMD ["/root/makevm.sh"]
