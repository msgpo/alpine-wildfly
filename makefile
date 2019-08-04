# {{{ -- meta

HOSTARCH  := $(shell uname -m | sed "s_armv6l_armhf_")# x86_64# on travis.ci
ARCH      := $(shell uname -m | sed "s_armv6l_armhf_")# armhf/x86_64 auto-detect on build and run
OPSYS     := alpine
SHCOMMAND := /bin/bash
SVCNAME   := wildfly
WFVERSION := 17.0.1.Final#
USERNAME  := woahbase

PUID       := $(shell id -u)
PGID       := $(shell id -g)# gid 100(users) usually pre exists

DOCKERSRC := $(OPSYS)-openjdk8#
DOCKEREPO := $(OPSYS)-$(SVCNAME)
IMAGETAG  := $(USERNAME)/$(DOCKEREPO):$(ARCH)

CNTNAME   := $(SVCNAME) # name for container name : docker_name, hostname : name

BUILD_NUMBER := 0#assigned in .travis.yml
BRANCH       := master

# -- }}}

# {{{ -- flags

BUILDFLAGS := --rm --force-rm --compress \
	-f $(CURDIR)/Dockerfile_$(ARCH) \
	-t $(IMAGETAG) \
	--build-arg DOCKERSRC=$(USERNAME)/$(DOCKERSRC):$(ARCH) \
	--build-arg WFVERSION=$(WFVERSION) \
	--build-arg http_proxy=$(http_proxy) \
	--build-arg https_proxy=$(https_proxy) \
	--build-arg no_proxy=$(no_proxy) \
	--label online.woahbase.source-image=$(DOCKERSRC) \
	--label online.woahbase.build-number=$(BUILD_NUMBER) \
	--label online.woahbase.branch=$(BRANCH) \
	--label org.label-schema.build-date=$(shell date -u +"%Y-%m-%dT%H:%M:%SZ") \
	--label org.label-schema.name=$(DOCKEREPO) \
	--label org.label-schema.schema-version="1.0" \
	--label org.label-schema.url="https://woahbase.online/" \
	--label org.label-schema.usage="https://woahbase.online/\#/images/$(DOCKEREPO)" \
	--label org.label-schema.vcs-ref=$(shell git rev-parse --short HEAD) \
	--label org.label-schema.vcs-url="https://github.com/$(USERNAME)/$(DOCKEREPO)" \
	--label org.label-schema.vendor=$(USERNAME)

CACHEFLAGS := --no-cache=true --pull
MOUNTFLAGS := -v $(CURDIR)/deployments:/opt/jboss/wildfly/standalone/deployments
NAMEFLAGS  := --name docker_$(CNTNAME) --hostname $(CNTNAME)
OTHERFLAGS := -v /etc/localtime:/etc/localtime:ro # -e TZ=Asia/Kolkata -v /etc/hosts:/etc/hosts:ro
PORTFLAGS  := -p 8080:8080 -p 9990:9990

RUNFLAGS   := -c 512 -m 512m \
	-e PGID=$(PGID) -e PUID=$(PUID) \
	-e PASSWORD=insecurebydefault \
	-e SERVERCONFIG=standalone.xml

# -- }}}

# {{{ -- docker targets

all : run

build :
	echo "Building for $(ARCH) from $(HOSTARCH)";
	if [ "$(ARCH)" != "$(HOSTARCH)" ]; then make regbinfmt ; fi;
	docker build $(BUILDFLAGS) $(CACHEFLAGS) .

clean :
	docker images | awk '(NR>1) && ($$2!~/none/) {print $$1":"$$2}' | grep "$(USERNAME)/$(DOCKEREPO)" | xargs -n1 docker rmi

logs :
	docker logs -f docker_$(CNTNAME)

pull :
	docker pull $(IMAGETAG)

push :
	docker push $(IMAGETAG);
	if [ "$(ARCH)" = "$(HOSTARCH)" ]; \
		then \
		LATESTTAG=$$(echo $(IMAGETAG) | sed 's/:$(ARCH)/:latest/'); \
		docker tag $(IMAGETAG) $${LATESTTAG}; \
		docker push $${LATESTTAG}; \
	fi;

restart :
	docker ps -a | grep 'docker_$(CNTNAME)' -q && docker restart docker_$(CNTNAME) || echo "Service not running.";

rm :
	docker rm -f docker_$(CNTNAME)

run :
	docker run --rm -it $(NAMEFLAGS) $(RUNFLAGS) $(PORTFLAGS) $(MOUNTFLAGS) $(OTHERFLAGS) $(IMAGETAG)

shell :
	docker run --rm -it $(NAMEFLAGS) $(RUNFLAGS) $(PORTFLAGS) $(MOUNTFLAGS) $(OTHERFLAGS) --entrypoint $(SHCOMMAND) $(IMAGETAG)

rdebug :
	docker exec -u root -it docker_$(CNTNAME) $(SHCOMMAND)

debug :
	docker exec -it docker_$(CNTNAME) $(SHCOMMAND)

stop :
	docker stop -t 2 docker_$(CNTNAME)

test :
	# test armhf in real device
	# if [ "$(ARCH)" != "armhf" ]; then
	docker run --rm -it $(NAMEFLAGS) $(RUNFLAGS) $(PORTFLAGS) $(MOUNTFLAGS) $(OTHERFLAGS) --entrypoint=/opt/jboss/wildfly/bin/jboss-cli.sh $(IMAGETAG) 'version';
	# fi;

# -- }}}

# {{{ -- other targets

regbinfmt :
	docker run --rm --privileged multiarch/qemu-user-static:register --reset

# -- }}}
