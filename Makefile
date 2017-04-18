ROOT_DIR = $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
DATA_DIR = $(ROOT_DIR)/data/
RUN_DIR = $(ROOT_DIR)/run/

# Tune how cuckoo worker connects to internet
CUCKOO_VPN := no
CUCKOO_DEFAULT_ROUTE ?= tor  # internet
CUCKOO_MACHINERY ?= virtualbox

VBOXNET=vboxnet0

VMCLOAK_ISOS_DIR=$(ROOT_DIR)/isos
VMCLOAK_PERSIST_DIR=$(DATA_DIR)/vmcloak
MALTRIEVE_DIR=$(DATA_DIR)/maltrieve/
QEMU_PERSIST_DIR=$(DATA_DIR)/qemu
DIST_SAMPLES_DIR=$(DATA_DIR)/samples/
DIST_REPORTS_DIR=$(DATA_DIR)/reports/
DOCKER_BASETAG=harryr/cockatoo

MYIP_IFACE ?= $(shell src/utils/myip.sh)
MYIP ?= $(shell echo $(MYIP_IFACE) | cut -f 1 -d ' ')
MYIFACE ?= $(shell echo $(MYIP_IFACE) | cut -f 2 -d ' ')
MEM_TOTAL ?= $(shell cat /proc/meminfo | grep MemTotal | awk '{print $$2}')
CPU_COUNT ?= $(shell cat /proc/cpuinfo  | grep bogomips | wc -l)

DOCKER_X11 = -e DISPLAY=$(DISPLAY) -e QT_X11_NO_MITSHM=1 -v $(HOME)/.Xauthority:/root/.Xauthority -v /tmp/.X11-unix:/tmp/.X11-unix

VIRTUALBOX_MODE ?= headless  # gui

all: build

.PHONY: bootstrap
bootstrap: prereq build

ufw:
	./src/utils/ufw-firewall.sh

# Create single file containing all environment segments
$(RUN_DIR)/env: DERP:=$(shell tempfile)
$(RUN_DIR)/env:
	echo '' > $(DERP)
	echo CUCKOO_MYIP=$(MYIP) >> $(DERP)
	echo CUCKOO_STARTUP_COUNT=$$(( ($(CPU_COUNT) / 4) + 1 )) >> $(DERP)
	echo CUCKOO_MAX_VMS=$$(( $(MEM_TOTAL) / 1024 / 1024 / 3)) >> $(DERP)
	echo CUCKOO_VPN=$(CUCKOO_VPN) >> $(DERP)
	echo CUCKOO_MACHINERY=$(CUCKOO_MACHINERY) >> $(DERP)
	echo CUCKOO_INTERNET_ETH=$(MYIFACE) >> $(DERP)
	echo CUCKOO_DEFAULT_ROUTE=$(CUCKOO_DEFAULT_ROUTE) >> $(DERP)
	echo CUCKOO_DEBUG=$(CUCKOO_DEBUG) >> $(DERP)
	echo CUCKOO_VIRTUALBOX_MODE=$(VIRTUALBOX_MODE) >> $(DERP)
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
.PHONY: $1-$2
$1-$2:

$2: build-$2

endef


CONTAINERS=maltrieve virtualbox5 vmcloak cuckoo cuckoo-worker
$(foreach name,$(CONTAINERS),$(eval $(call prefixrule,container,$(name))))


kill-all: $(addprefix kill-,$(CONTAINERS))

kill-%: container-%
	docker kill -s TERM $* || true


delete-all: $(addprefix delete-,$(CONTAINERS))

delete-%: container-%
	docker rm -f $* 2> /dev/null || true


attach-%: container-%
	docker attach $*


shell-%: container-%
	docker exec -ti $* bash


build: $(addprefix build-,$(CONTAINERS))

build-%: container-%
	cd src/$* && docker build -t $(DOCKER_BASETAG):$* .


.PHONY: prereq
prereq:
	sudo apt-get update
	sudo apt-get -y install jq apt-transport-https ca-certificates supervisor openvpn
	sudo apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D
	sudo sh -c "echo 'deb https://apt.dockerproject.org/repo ubuntu-xenial main' > /etc/apt/sources.list.d/docker.list"
	sudo apt-get update
	sudo apt-get -y install linux-image-extra-`uname -r` docker-engine docker-compose

	sudo ./src/virtualbox5/install-virtualbox.sh

docker-gc:
	docker volume prune -f
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


# Supervisorctl
run-supervisor:
	sudo supervisorctl -c supervisord.conf

supervise-cuckoo:
	docker exec -ti cuckoo supervisorctl


start-netdata:
	docker pull titpetric/netdata
	docker run --name netdata --restart=unless-stopped -tid --cap-add SYS_PTRACE -v /proc:/host/proc:ro -v /sys:/host/sys:ro -p 19999:19999 titpetric/netdata


run-maltrieve: 
	docker run --rm=true --name maltrieve -h maltrieve \
			   -v $(MALTRIEVE_DIR):/archive --net=host -ti \
			   $(DOCKER_BASETAG):maltrieve

archive:
	./src/utils/archive.py

run-loop:
	./src/utils/loop.sh

# Start a shell in the vmcloak container
run-vmcloak: vmcloak  $(VMCLOAK_PERSIST_DIR) pre-run
	docker run --rm=true $(DOCKER_X11) --name vmcloak --net=host \
			   --privileged -v $(VMCLOAK_PERSIST_DIR):/.vmcloak/ \
			   -v /dev/vboxdrv:/dev/vboxdrv -v $(VMCLOAK_ISOS_DIR):/mnt/isos \
			   -ti $(DOCKER_BASETAG):vmcloak bash

# Run the Cuckoo worker container
run-cuckoo: $(RUN_DIR)/env pre-run
	# --restart=unless-stopped --name cuckoo-worker
	docker run --rm --name cuckoo --env-file=$(RUN_DIR)/env \
		--net=host --privileged --cap-add net_admin \
		$(DOCKER_X11) \
		-v /.cuckoo/storage/ \
		-v /.vmcloak/ \
		-v $(VMCLOAK_PERSIST_DIR)/image:/.vmcloak/image/ \
		-v $(QEMU_PERSIST_DIR):/root/qemu/ \
		-v /dev/vboxdrv:/dev/vboxdrv \
		-it $(DOCKER_BASETAG):cuckoo-worker # bash
