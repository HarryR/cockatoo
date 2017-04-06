FROM cockatoo:cuckoo

EXPOSE 8090

RUN apt-get -y install tor

ENTRYPOINT ["/docker-entrypoint.sh"]

CMD ["/usr/bin/supervisord"]

WORKDIR /.cuckoo/

RUN mkdir -p /.cuckoo/conf
RUN cd /.cuckoo/conf && touch esx.conf avd.conf kvm.conf physical.conf vmware.conf vsphere.conf xenserver.conf

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

