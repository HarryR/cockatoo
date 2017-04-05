FROM cockatoo:cuckoo

#RUN apt-get update
#RUN apt-get install -y qemu-kvm qemu-system-arm qemu-system-common qemu-system-mips qemu-system-ppc qemu-system-sparc qemu-system-x86 qemu-system-misc qemu 

EXPOSE 8090

RUN apt-get -y install tor

ENTRYPOINT ["/docker-entrypoint.sh"]

CMD ["/usr/bin/supervisord"]

RUN mkdir -p /.cuckoo/conf
COPY supervisord.conf /etc/supervisor/conf.d/cuckoo.conf
COPY conf/memory.conf /.cuckoo/conf/memory.conf
COPY conf/reporting.conf /.cuckoo/conf/reporting.conf
COPY conf/routing.conf /.cuckoo/conf/routing.conf
COPY conf/virtualbox.conf /.cuckoo/conf/virtualbox.conf
COPY conf/qemu.conf /.cuckoo/conf/qemu.conf
COPY conf/auxiliary.conf /.cuckoo/conf/auxiliary.conf
COPY conf/processing.conf /.cuckoo/conf/processing.conf
COPY conf/cuckoo.conf /.cuckoo/conf/cuckoo.conf
COPY docker-entrypoint.sh /

WORKDIR /.cuckoo/
RUN cd /.cuckoo/conf && touch esx.conf avd.conf kvm.conf physical.conf vmware.conf vsphere.conf xenserver.conf
