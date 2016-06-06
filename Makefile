ROOT_DIR = $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
DATA_DIR = $(ROOT_DIR)/data/
RUN_DIR = $(ROOT_DIR)/run/

VMCLOAK_ISOS_DIR=$(ROOT_DIR)/isos
VMCLOAK_PERSIST_DIR=$(DATA_DIR)/vmcloak
DIST_SAMPLES_DIR=$(DATA_DIR)/samples/
DIST_REPORTS_DIR=$(DATA_DIR)/reports/
PGDATA_DIST_DIR=$(DATA_DIR)/dist-pgdata
DOCKER_BASETAG=harryr/cockatoo
#PGDATA_WORKER_DIR=$(DATA_DIR)/worker-pgdata
MYIP := $(shell src/utils/myip.sh)
MEM_TOTAL=$(shell cat /proc/meminfo | grep MemTotal | awk '{print $$2}')

all:
	@echo "See README.md for information on how to get started"

# Generate a postgresql database password automagically
$(RUN_DIR)/pgpass:
	openssl rand -base64 15 | tr -cd '[:alnum:]\n' > $@

# Create single file containing all environment segments
.PHONY: $(RUN_DIR)/env
$(RUN_DIR)/env: $(RUN_DIR)/pgpass
	@echo '' > $@
	@echo -n 'POSTGRES_PASSWORD=' >> $@ && cat $(RUN_DIR)/pgpass >> $@
	@echo 'CUCKOO_DIST_API=http://127.0.0.1:9003' >> $@
	@echo MYIP=$(MYIP) >> $@
	@echo CPU_COUNT=`cat /proc/cpuinfo  | grep bogomips | wc -l` >> $@
	@echo MAX_VMS=$$(( $(MEM_TOTAL) / 1024 / 1024)) >> $@
	@echo CUCKOO_VPN=yes >> $@

env: $(RUN_DIR)/env

$(VMCLOAK_ISOS_DIR):
	mkdir -p $@

$(WORKER_STORAGE_DIR):
	mkdir -p $@

$(VMCLOAK_PERSIST_DIR):
	mkdir -p $@

$(DIST_SAMPLES_DIR):
	mkdir -p $@

$(DIST_REPORTS_DIR):
	mkdir -p $@

$(WORKER_VMS_DIR):
	mkdir -p $@

#$(PGDATA_WORKER_DIR):
#	mkdir -p $@

$(PGDATA_DIST_DIR):
	mkdir -p $@

.PHONY: vmcloak
vmcloak:
	cd src/$@ && docker build -t $(DOCKER_BASETAG):$@ .

.PHONY: virtualbox5
virtualbox5:
	cd src/$@ && docker build -t $(DOCKER_BASETAG):$@ .

.PHONY: cuckoo
cuckoo: virtualbox5
	cd src/$@ && docker build -t $(DOCKER_BASETAG):$@ .

.PHONY: postgresql
postgresql:
	cd src/$@ && docker build -t $(DOCKER_BASETAG):$@ .

.PHONY: cuckoo-worker
cuckoo-worker: cuckoo
	cd src/$@ && docker build -t $(DOCKER_BASETAG):$@ .

.PHONY: cuckoo-dist
cuckoo-dist: cuckoo
	cd src/$@ && docker build -t $(DOCKER_BASETAG):$@ .

.PHONY: pull
pull:
	docker pull $(DOCKER_BASETAG):virtualbox5
	docker pull $(DOCKER_BASETAG):postgresql
	docker pull $(DOCKER_BASETAG):vmcloak
	docker pull $(DOCKER_BASETAG):cuckoo
	docker pull $(DOCKER_BASETAG):cuckoo-worker
	docker pull $(DOCKER_BASETAG):cuckoo-dist

.PHONY: prereq
prereq:
	sudo apt-get update
	sudo apt-get -y install apt-transport-https ca-certificates supervisor virtualbox-dkms virtualbox openvpn
	sudo apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D
	sudo sh -c "echo 'deb https://apt.dockerproject.org/repo ubuntu-xenial main' > /etc/apt/sources.list.d/docker.list"
	sudo apt-get update
	sudo apt-get -y install linux-image-extra-`uname -r` docker-engine docker-compose


cryptostorm: /etc/openvpn/cryptostorm.conf
/etc/openvpn/cryptostorm.conf:
	sudo service openvpn stop cryptostorm || true
	# Use free Cryptostorm account
	sudo wget -qO $@ https://raw.githubusercontent.com/cryptostorm/cryptostorm_client_configuration_files/master/cryptofree_linux-udp.ovpn
	sudo sh -c "echo 'dev tun1' >> $@"
	sudo sh -c "echo 'auth-user-pass cryptostorm.creds' >> $@"
	sudo sh -c "echo 'auth-nocache' >> $@"
	# Override default route
	#sudo sh -c "echo 'route 0.0.0.0 128.0.0.0 net_gateway' >> $@"
	#sudo sh -c "echo 'route 128.0.0.0 128.0.0.0 net_gateway' >> $@"
	sudo sh -c "echo 'route 0.0.0.0 192.0.0.0 net_gateway' >> $@"
	sudo sh -c "echo 'route 64.0.0.0 192.0.0.0 net_gateway' >> $@"
	sudo sh -c "echo 'route 128.0.0.0 192.0.0.0 net_gateway' >> $@"
	sudo sh -c "echo 'route 192.0.0.0 192.0.0.0 net_gateway' >> $@"

	sudo systemctl daemon-reload
	sudo chmod 600 $@
	# Sshhh... super secret leaked access details below! :P
	sudo sh -c "echo 'acce55' > /etc/openvpn/cryptostorm.creds"
	sudo sh -c "echo '0verrid3' >> /etc/openvpn/cryptostorm.creds"
	sudo chmod 600 /etc/openvpn/cryptostorm.creds
	# echo '201 tun1' >> /etc/iproute2/rt_tables


.PHONY: build
build: virtualbox5 cuckoo cuckoo-worker cuckoo-dist postgresql vmcloak

# Configure hostonly networks consistently before starting
# This ensures that vboxnet0 is up and has a known IP / subnet
.PHONY: pre-run
pre-run:
	vboxmanage list hostonlyifs > /dev/null
	sleep 3
	vboxmanage list hostonlyifs > /dev/null
	vboxmanage hostonlyif ipconfig vboxnet0 --ip 172.28.128.1
	vboxmanage dhcpserver remove --ifname vboxnet0 || true

shell-cuckoo-worker:
	docker exec -ti cuckoo-worker bash

.PHONY: run
run: pre-run
	mkdir -p $(RUN_DIR)/supervisor/
	supervisord -n -c supervisord.conf 

stop-vmcloak:
	@docker kill -s TERM vmcloak || true

.PHONY: stop-cuckoo-worker
stop-cuckoo-worker:
	@docker kill -s TERM cuckoo-worker || true
	sleep 3

.PHONY: stop-cuckoo-dist-api
stop-cuckoo-dist-api:
	@docker kill -s TERM cuckoo-dist-api || true
	sleep 3

.PHONY: stop-cuckoo-dist-db
stop-cuckoo-dist-db:
	@docker kill -s TERM cuckoo-dist-db || true
	sleep 3

stop: stop-vmcloak stop-cuckoo-worker stop-cuckoo-dist-api stop-cuckoo-dist-db

.PHONY: console
console:
	supervisorctl -c supervisord.conf

# Start a shell in the vmcloak container
run-vmcloak: vmcloak  $(VMCLOAK_PERSIST_DIR) stop-vmcloak
	@docker rm vmcloak || true
	docker run --name vmcloak -h vmcloak --net=host --privileged -v $(VMCLOAK_PERSIST_DIR):/root/.vmcloak/ -v /dev/vboxdrv:/dev/vboxdrv -v $(VMCLOAK_ISOS_DIR):/mnt/isos -ti harryr/cockatoo:vmcloak bash

run-cuckoo-worker: $(RUN_DIR)/env pre-run stop-cuckoo-worker
	@docker rm cuckoo-worker || true
	mkdir -p /tmp/rooter
	docker run --name cuckoo-worker --env-file=$(RUN_DIR)/env --net=host --privileged --cap-add net_admin -v $(ROOT_DIR)/run/rooter.sock:/cuckoo/rooter.sock -v /cuckoo/storage/ -v $(VMCLOAK_PERSIST_DIR):/root/.vmcloak/ -v /root/.vmcloak/vms/ -v /dev/vboxdrv:/dev/vboxdrv -v /tmp/rooter:/tmp/rooter -t harryr/cockatoo:cuckoo-worker

run-cuckoo-dist-api: $(RUN_DIR)/env $(DIST_SAMPLES_DIR) $(DIST_REPORTS_DIR) stop-cuckoo-dist-api
	@docker rm cuckoo-dist-api || true
	docker run --name cuckoo-dist-api -h cuckoo-dist-api -p 9003:9003 --link cuckoo-dist-db:db --env-file=$(RUN_DIR)/env -v $(VMCLOAK_PERSIST_DIR):/root/.vmcloak/ -v $(DIST_REPORTS_DIR):/mnt/reports -v $(DIST_SAMPLES_DIR):/mnt/samples -t harryr/cockatoo:cuckoo-dist

run-rooter: cryptostorm
	sudo python $(ROOT_DIR)/src/cuckoo/cuckoo/utils/rooter.py -g nogroup -v $(ROOT_DIR)/run/rooter.sock

# Start the Cuckoo Worker PostgreSQL container
#run-cuckoo-worker-db: postgresql $(PGDATA_WORKER_DIR) $(RUN_DIR)/pgpass
#	docker run -v $(PGDATA_WORKER_DIR):/var/lib/postgresql/data/ -e POSTGRES_PASSWORD=`cat $(RUN_DIR)/pgpass` -ti harryr/cockatoo:postgresql

# Start the Cuckoo Dist Server PostgreSQL container
run-cuckoo-dist-db: $(PGDATA_DIST_DIR) $(RUN_DIR)/env stop-cuckoo-dist-db
	@docker rm cuckoo-dist-db || true
	docker run --name cuckoo-dist-db -h cuckoo-dist-db -p 5432:5432 --env-file=$(RUN_DIR)/env -v $(PGDATA_DIST_DIR):/var/lib/postgresql/data/ harryr/cockatoo:postgresql

