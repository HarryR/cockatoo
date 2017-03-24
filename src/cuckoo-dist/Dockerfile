FROM cockatoo:cuckoo

COPY settings.py /cuckoo/distributed/settings.py
COPY supervisord.conf /etc/supervisor/conf.d/cuckoo.conf

EXPOSE 9003

CMD ["/usr/bin/supervisord"]