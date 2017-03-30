FROM cockatoo:cuckoo

RUN apt-get install -y net-tools iptables

VOLUME /tmp/rooter
VOLUME /cuckoo/run

CMD python /cuckoo/utils/rooter.py  -g cuckoo -v /cuckoo/run/rooter.sock