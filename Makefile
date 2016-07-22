ROOT_DIR = $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
DATA_DIR = $(ROOT_DIR)/data/
RUN_DIR = $(ROOT_DIR)/run/

# Tune how cuckoo worker connects to internet
CUCKOO_VPN := no
CUCKOO_DEFAULT_ROUTE := internet # cryptostorm 
CUCKOO_MACHINERY := virtualbox

VMCLOAK_ISOS_DIR=$(ROOT_DIR)/isos
VMCLOAK_PERSIST_DIR=$(DATA_DIR)/vmcloak
MALTRIEVE_DIR=$(DATA_DIR)/maltrieve/
QEMU_PERSIST_DIR=$(DATA_DIR)/qemu
DIST_SAMPLES_DIR=$(DATA_DIR)/samples/
DIST_REPORTS_DIR=$(DATA_DIR)/reports/
PGDATA_DIST_DIR=$(DATA_DIR)/dist-pgdata
DOCKER_BASETAG=harryr/cockatoo
#PGDATA_WORKER_DIR=$(DATA_DIR)/worker-pgdata
MYIP_IFACE = $(shell src/utils/myip.sh)
MYIP := $(shell echo $(MYIP_IFACE) | cut -f 1 -d ' ')
MYIFACE := $(shell echo $(MYIP_IFACE) | cut -f 2 -d ' ')
MYIFACE := tun1
MEM_TOTAL := $(shell cat /proc/meminfo | grep MemTotal | awk '{print $$2}')

all:
	@echo "See README.md for information on how to get started"

# Generate a postgresql database password automagically
$(RUN_DIR)/pgpass:
	openssl rand -base64 15 | tr -cd '[:alnum:]\n' > $@

# Create single file containing all environment segments
.PHONY: $(RUN_DIR)/env
$(RUN_DIR)/env: DERP:=$(shell tempfile)
$(RUN_DIR)/env: $(RUN_DIR)/pgpass
	echo '' > $(DERP)
	echo -n 'POSTGRES_PASSWORD=' >> $(DERP)
	cat $(RUN_DIR)/pgpass >> $(DERP)
	echo 'CUCKOO_DIST_API=http://127.0.0.1:9003' >> $(DERP)
	echo MYIP=$(MYIP) >> $(DERP)
	echo CPU_COUNT=`cat /proc/cpuinfo  | grep bogomips | wc -l` >> $(DERP)
	echo MAX_VMS=$$(( $(MEM_TOTAL) / 1024 / 1024 / 2)) >> $(DERP)
	echo CUCKOO_VPN=$(CUCKOO_VPN) >> $(DERP)
	echo CUCKOO_MACHINERY=$(CUCKOO_MACHINERY) >> $(DERP)
	echo CUCKOO_INTERNET_ETH=$(MYIFACE) >> $(DERP)
	echo CUCKOO_DEFAULT_ROUTE=$(CUCKOO_DEFAULT_ROUTE) >> $(DERP)
	#echo VM_MAX_N=2 >> $(DERP)
	mv -f $(DERP) $@

env: $(RUN_DIR)/env 

$(MALTRIEVE_DIR):
	mkdir -p $@
	chmod 777 $@

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
	docker pull ubuntu:16.04
	cd src/$@ && docker build -t $(DOCKER_BASETAG):$@ .

.PHONY: cuckoo
cuckoo: virtualbox5
	cd src/$@ && docker build -t $(DOCKER_BASETAG):$@ .

.PHONY: postgresql
postgresql:
	cd src/$@ && docker build -t $(DOCKER_BASETAG):$@ .

.PHONY: maltrieve
maltrieve:
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

docker-gc:
	docker pull spotify/docker-gc
	docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v /etc:/etc spotify/docker-gc

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
build: virtualbox5 cuckoo cuckoo-worker cuckoo-dist postgresql vmcloak maltrieve

# Configure hostonly networks consistently before starting
# This ensures that vboxnet0 is up and has a known IP / subnet
.PHONY: pre-run
pre-run:
	vboxmanage list hostonlyifs > /dev/null
	sleep 3
	vboxmanage list hostonlyifs > /dev/null
	vboxmanage hostonlyif ipconfig vboxnet0 --ip 172.28.128.1
	vboxmanage dhcpserver remove --ifname vboxnet0 || true

.PHONY: run
run: pre-run
	mkdir -p $(RUN_DIR)/supervisor/
	sudo supervisord -n -c supervisord.conf 

psql:
	PGPASSWORD=`cat run/pgpass` psql -h localhost -U postgres

stop-vmcloak:
	@docker kill -s TERM vmcloak || true

stop-worker:
	@docker kill -s TERM cuckoo-worker || true
	sleep 3

kill-worker:
	docker kill cuckoo-worker || true

stop-dist:
	@docker kill -s TERM cuckoo-dist-api || true
	sleep 3

stop-db:
	@docker kill -s TERM cuckoo-dist-db || true
	sleep 3

stop-maltrieve:
	@docker kill -s TERM maltrieve || true
	sleep 3

stop: stop-vmcloak stop-worker stop-dist stop-db stop-maltrieve

# Supervisorctl
supervise:
	sudo supervisorctl -c supervisord.conf
supervise-dist:
	docker exec -ti cuckoo-dist-api supervisorctl
supervise-worker:
	docker exec -ti cuckoo-worker supervisorctl

# Shells in containers
shell-db:
	docker exec -ti cuckoo-dist-db bash
shell-worker:
	docker exec -ti cuckoo-worker bash
shell-dist:
	docker exec -ti cuckoo-dist-api bash

run-maltrieve: maltrieve stop-maltrieve
	@docker rm maltrieve || true
	docker run --name maltrieve -h maltrieve --link cuckoo-dist-api:dist -v $(MALTRIEVE_DIR):/archive -t $(DOCKER_BASETAG):maltrieve

# Start a shell in the vmcloak container
run-vmcloak: vmcloak  $(VMCLOAK_PERSIST_DIR) stop-vmcloak
	@docker rm vmcloak || true
	docker run --name vmcloak --net=host --privileged -v $(VMCLOAK_PERSIST_DIR):/root/.vmcloak/ -v /dev/vboxdrv:/dev/vboxdrv -v $(VMCLOAK_ISOS_DIR):/mnt/isos -ti harryr/cockatoo:vmcloak bash

run-worker: $(RUN_DIR)/env pre-run stop-worker
	@docker rm cuckoo-worker || true
	mkdir -p /tmp/rooter
	docker run --name cuckoo-worker --env-file=$(RUN_DIR)/env \
		--net=host --privileged --cap-add net_admin \
		-v $(ROOT_DIR)/run/rooter.sock:/cuckoo/rooter.sock \
		-v /cuckoo/storage/ \
		-v $(VMCLOAK_PERSIST_DIR):/root/.vmcloak/ \
		-v $(QEMU_PERSIST_DIR):/root/qemu/ \
		-v /root/.vmcloak/vms/ \
		-v /dev/vboxdrv:/dev/vboxdrv \
		-v /tmp/rooter:/tmp/rooter \
		-t $(DOCKER_BASETAG):cuckoo-worker

run-dist: $(RUN_DIR)/env $(DIST_SAMPLES_DIR) $(DIST_REPORTS_DIR) stop-dist
	@docker rm cuckoo-dist-api || true
	docker run --name cuckoo-dist-api -h cuckoo-dist-api -p 9003:9003 --link cuckoo-dist-db:db --env-file=$(RUN_DIR)/env -v $(VMCLOAK_PERSIST_DIR):/root/.vmcloak/ -v $(DIST_REPORTS_DIR):/mnt/reports -v $(DIST_SAMPLES_DIR):/mnt/samples -t $(DOCKER_BASETAG):cuckoo-dist

run-rooter: cryptostorm
	sudo python $(ROOT_DIR)/src/cuckoo/cuckoo/utils/rooter.py -g nogroup -v $(ROOT_DIR)/run/rooter.sock

# Start the Cuckoo Worker PostgreSQL container
#run-cuckoo-worker-db: postgresql $(PGDATA_WORKER_DIR) $(RUN_DIR)/pgpass
#	docker run -v $(PGDATA_WORKER_DIR):/var/lib/postgresql/data/ -e POSTGRES_PASSWORD=`cat $(RUN_DIR)/pgpass` -ti harryr/cockatoo:postgresql

# Start the Cuckoo Dist Server PostgreSQL container
run-db: $(PGDATA_DIST_DIR) $(RUN_DIR)/env stop-db
	@docker rm cuckoo-dist-db || true
	docker run --name cuckoo-dist-db -h cuckoo-dist-db -p 5432:5432 --env-file=$(RUN_DIR)/env -v $(PGDATA_DIST_DIR):/var/lib/postgresql/data/ $(DOCKER_BASETAG):postgresql

