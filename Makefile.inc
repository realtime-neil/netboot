# -*- mode: makefile-gmake -*-

THIS := $(abspath $(lastword $(MAKEFILE_LIST)))
HERE := $(patsubst %/,%,$(dir $(THIS)))
CWD := $(shell pwd)

$(info $$THIS is [${THIS}])
$(info $$HERE is [${HERE}])
$(info $$CWD is [${CWD}])

# Inputs. Invoke from the parent makefile with these options set.
GOARCH:=
BINARY:=
TAG:=
REGISTRY:=
GOCMD:=go
DOCKER_SUDO:=
GITCOMMIT:=
GITBRANCH:=

ifeq (,$(strip $(GOARCH)))
$(error undefined GOARCH)
endif
ifeq (,$(strip $(REGISTRY)))
$(error undefined REGISTRY)
endif
ifeq (,$(strip $(BINARY)))
$(error undefined BINARY)
endif
ifeq (,$(strip $(TAG)))
$(error undefined TAG)
endif

# Other variables.
GITCOMMIT:=$(shell git describe --long --always --dirty)
BUILD_DIR:=build/$(GOARCH)/$(BINARY)
DOCKERCMD:=docker
ifneq ($(DOCKER_SUDO),)
DOCKERCMD:=sudo docker
endif

FROM_IMAGE:=alpine:latest
ifneq ($(GOARCH),amd64)
  FROM_IMAGE:=$(GOARCH)/alpine:latest
endif
ifeq ($(GOARCH),arm)
  FROM_IMAGE:=arm32v6/alpine:latest
endif
ifeq ($(GOARCH),arm64)
  FROM_IMAGE:=arm64v8/alpine:latest
endif


build/$(GOARCH)/$(BINARY)/$(BINARY):
	mkdir -vp $(dir $@)
	GO111MODULE=on CGO_ENABLED=0 GOOS=linux GOARCH=$(GOARCH) GOARM=6 \
		go build -o $@ $(HERE)/cmd/$(BINARY)


.PHONY: image
image: build/$(GOARCH)/$(BINARY)/$(BINARY)
	$(DOCKERCMD) image build \
	--build-arg BINARY=$(BINARY) \
	--build-arg FROM_IMAGE=$(FROM_IMAGE) \
	--tag $(REGISTRY)/$(BINARY):$(TAG) \
	--file $(HERE)/Dockerfile \
	$(dir $<)


.PHONY: push
push: image
	$(DOCKERCMD) image push $(REGISTRY)/$(BINARY):$(TAG)
