ROOT_DIR = $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
DATA_DIR = $(ROOT_DIR)/data/
RUN_DIR = $(ROOT_DIR)/run/

# Tune how cuckoo worker connects to internet
CUCKOO_VPN := no
CUCKOO_DEFAULT_ROUTE := internet # cryptostorm 
CUCKOO_MACHINERY := virtualbox

VBOXNET=vboxnet0

VMCLOAK_ISOS_DIR=$(ROOT_DIR)/isos
VMCLOAK_PERSIST_DIR=$(DATA_DIR)/vmcloak
MALTRIEVE_DIR=$(DATA_DIR)/maltrieve/
QEMU_PERSIST_DIR=$(DATA_DIR)/qemu
DIST_SAMPLES_DIR=$(DATA_DIR)/samples/
DIST_REPORTS_DIR=$(DATA_DIR)/reports/
DOCKER_BASETAG=cockatoo

MYIP_IFACE = $(shell src/utils/myip.sh)
MYIP := $(shell echo $(MYIP_IFACE) | cut -f 1 -d ' ')
MYIFACE := $(shell echo $(MYIP_IFACE) | cut -f 2 -d ' ')
MEM_TOTAL := $(shell cat /proc/meminfo | grep MemTotal | awk '{print $$2}')
CPU_COUNT := $(shell cat /proc/cpuinfo  | grep bogomips | wc -l)

DOCKER_X11 = -e DISPLAY=$(DISPLAY) -e QT_X11_NO_MITSHM=1 -v $(HOME)/.Xauthority:/root/.Xauthority -v /tmp/.X11-unix:/tmp/.X11-unix

VIRTUALBOX_MODE = gui  # headless

all:
	@echo "make first-time  # To build & start everything"

first-time: prereq build-all create-all

# Create single file containing all environment segments
$(RUN_DIR)/env: DERP:=$(shell tempfile)
$(RUN_DIR)/env: src/cuckoo-psql/data/conf/env
	echo '' > $(DERP)
	echo 'CUCKOO_DIST_API=http://127.0.0.1:9003' >> $(DERP)
	echo CUCKOO_MYIP=$(MYIP) >> $(DERP)
	echo CUCKOO_CPU_COUNT=$(CPU_COUNT) >> $(DERP)
	echo CUCKOO_MAX_VMS=$$(( $(MEM_TOTAL) / 1024 / 1024 / 2)) >> $(DERP)
	echo CUCKOO_VPN=$(CUCKOO_VPN) >> $(DERP)
	echo CUCKOO_MACHINERY=$(CUCKOO_MACHINERY) >> $(DERP)
	echo CUCKOO_INTERNET_ETH=$(MYIFACE) >> $(DERP)
	echo CUCKOO_DEFAULT_ROUTE=$(CUCKOO_DEFAULT_ROUTE) >> $(DERP)
	echo CUCKOO_DEBUG=$(CUCKOO_DEBUG) >> $(DERP)
	echo CUCKOO_VIRTUALBOX_MODE=$(VIRTUALBOX_MODE) >> $(DERP)
	#echo VM_MAX_N=2 >> $(DERP)
	cat $+ >> $(DERP)
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


define prefixrule
.PHONY: $1-$2 $2
$1-$2:

$2: build-$2

endef


MAKEFILES=cuckoo-psql
$(foreach name,$(MAKEFILES),$(eval $(call prefixrule,make,$(name))))


CONTAINERS=maltrieve virtualbox5  vmcloak cuckoo cuckoo-rooter cuckoo-worker cuckoo-dist
$(foreach name,$(CONTAINERS),$(eval $(call prefixrule,container,$(name))))


kill-all: $(addprefix kill-,$(CONTAINERS))

kill-%: container-%
	docker kill -s TERM $* || true


delete-all: $(addprefix delete-,$(CONTAINERS)) $(addprefix delete-,$(MAKEFILES))

delete-%: container-%
	docker rm -f $* 2> /dev/null || true

delete-%: make-%
	make -C src/$* docker-delete


stop-all: $(addprefix stop-,$(CONTAINERS)) $(addprefix stop-,$(MAKEFILES))

stop-%: container-%
	docker stop $* 2> /dev/null || true

stop-%: make-%
	make -C src/$* docker-stop


create-all: $(addprefix create-,$(CONTAINERS)) $(addprefix create-,$(MAKEFILES))

start-all: $(addprefix start-,$(CONTAINERS)) $(addprefix start-,$(MAKEFILES))

start-%: container-%
	docker start $* || true

start-%: make-%
	make -C src/$* docker-start


attach-%: container-%
	docker attach $*


shell-%: container-%
	docker exec -ti $* bash

shell-%: make-%
	make -C src/$* docker-shell


build-all: $(addprefix build-,$(CONTAINERS)) $(addprefix build-,$(MAKEFILES))

build-%: container-%
	cd src/$* && docker build -t $(DOCKER_BASETAG):$* .

build-%: make-%
	make -C src/$* docker-build


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


# Configure hostonly networks consistently before starting
# This ensures that vboxnet0 is up and has a known IP / subnet
.PHONY: pre-run
pre-run:
	# sudo /sbin/vboxconfig 
	@CNT=0; OK=1; \
	echo -n "Configuring $(VBOXNET) .."; \
	while [ $$CNT -lt 4 ]; do \
		CNT=$$(($$CNT + 1)); \
		vboxmanage list hostonlyifs > /dev/null; \
		vboxmanage hostonlyif ipconfig $(VBOXNET) --ip 172.28.128.1; \
		OK=$$?; if [ $$OK -eq 0 ]; then echo "OK"; break; fi; \
		echo "."; sleep 1; \
	done;
	@vboxmanage dhcpserver remove --ifname $(VBOXNET) || true

.PHONY: run
run: pre-run
	mkdir -p $(RUN_DIR)/supervisor/
	sudo supervisord -n -c supervisord.conf 

psql:
	make -C src/cuckoo-psql psql


# Supervisorctl
supervise:
	sudo supervisorctl -c supervisord.conf
supervise-dist:
	docker exec -ti cuckoo-dist supervisorctl
supervise-worker:
	docker exec -ti cuckoo-worker supervisorctl


run-maltrieve: maltrieve stop-maltrieve
	@docker rm maltrieve || true
	docker run --rm=true --name maltrieve -h maltrieve --link cuckoo-dist-api:dist -v $(MALTRIEVE_DIR):/archive -t $(DOCKER_BASETAG):maltrieve

run-maltrieve-loop:
	./src/utils/maltrieve-loop.sh

# Start a shell in the vmcloak container
run-vmcloak: vmcloak  $(VMCLOAK_PERSIST_DIR) pre-run
	docker run --rm=true $(DOCKER_X11) --name vmcloak --net=host \
			   --privileged -v $(VMCLOAK_PERSIST_DIR):/root/.vmcloak/ \
			   -v /dev/vboxdrv:/dev/vboxdrv -v $(VMCLOAK_ISOS_DIR):/mnt/isos \
			   -ti cockatoo:vmcloak bash

create-cuckoo-worker: $(RUN_DIR)/env pre-run
	mkdir -p /tmp/rooter
	docker run --rm --name cuckoo-worker --env-file=$(RUN_DIR)/env \
		--net=host --privileged --cap-add net_admin \
		$(DOCKER_X11) \
		-v $(ROOT_DIR)/run/rooter.sock:/cuckoo/rooter.sock \
		-v /cuckoo/storage/ \
		-v $(VMCLOAK_PERSIST_DIR):/root/.vmcloak/ \
		-v $(QEMU_PERSIST_DIR):/root/qemu/ \
		-v /root/.vmcloak/vms/ \
		-v /dev/vboxdrv:/dev/vboxdrv \
		-v /tmp/rooter:/tmp/rooter \
		-it $(DOCKER_BASETAG):cuckoo-worker
		# --restart=unless-stopped --name cuckoo-worker \

create-cuckoo-dist: $(RUN_DIR)/env $(DIST_SAMPLES_DIR) $(DIST_REPORTS_DIR)
	docker run -d --name cuckoo-dist -h cuckoo-dist -p 9003:9003 \
			   --link cuckoo-psql:db --env-file=$(RUN_DIR)/env \
			   -v $(VMCLOAK_PERSIST_DIR):/root/.vmcloak/ \
			   -v $(DIST_REPORTS_DIR):/mnt/reports \
			   -v $(DIST_SAMPLES_DIR):/mnt/samples \
			   --restart=unless-stopped \
			   -it $(DOCKER_BASETAG):cuckoo-dist

create-cuckoo-rooter:
	docker run --rm=true --name cuckoo-rooter -h cuckoo-rooter --net=host -p 9003:9003 \
			   --env-file=$(RUN_DIR)/env -v /tmp/rooter:/tmp/rooter \
			   -v $(ROOT_DIR)/run:/cuckoo/run -it $(DOCKER_BASETAG):cuckoo-rooter			   
			   # --restart=unless-stopped \ 

create-cuckoo-psql:
	make -C src/cuckoo-psql docker-create

