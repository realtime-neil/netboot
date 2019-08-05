# netboot/Makefile

THIS := $(abspath $(lastword $(MAKEFILE_LIST)))
HERE := $(patsubst %/,%,$(dir $(THIS)))
CWD := $(shell pwd)

$(info $$THIS is [${THIS}])
$(info $$HERE is [${HERE}])
$(info $$CWD is [${CWD}])

# Local customizations to the above.
ifneq ($(wildcard Makefile.defaults),)
include Makefile.defaults
endif

.PHONY: all
all:
	$(error Please request a specific thing, there is no default target)


.PHONY: manifest-tool
manifest-tool:
	GO111MODULE=off go get -u -v github.com/estesp/manifest-tool


.PHONY: ci-prepare
ci-prepare: manifest-tool


.PHONY: build
build:
	GO111MODULE=on go install ./cmd/pixiecore


.PHONY: test
test:
	GO111MODULE=on go test ./...
	GO111MODULE=on go test -race ./...


.PHONY: lint
lint:
	GO111MODULE=on go vet ./...


.PHONY: ci-push-images
ci-push-images: BINARY=pixiecore REGISTRY=pixiecore TAG=dev
ci-push-images: manifest-tool
	$(MAKE) -f Makefile.inc push GOARCH=amd64   TAG=$(TAG)-amd64
	$(MAKE) -f Makefile.inc push GOARCH=arm     TAG=$(TAG)-arm
	$(MAKE) -f Makefile.inc push GOARCH=arm64   TAG=$(TAG)-arm64
	$(MAKE) -f Makefile.inc push GOARCH=ppc64le TAG=$(TAG)-ppc64le
	$(MAKE) -f Makefile.inc push GOARCH=s390x   TAG=$(TAG)-s390x
	{ \
	manifest-tool push from-args \
	--platforms linux/amd64,linux/arm,linux/arm64,linux/ppc64le,linux/s390x \
	--template $(REGISTRY)/pixiecore:$(TAG)-ARCH \
	--target $(REGISTRY)/pixiecore:$(TAG) \
	; }


.PHONY: ci-config
ci-config:
	(cd .circleci && go run gen-config.go >config.yml)


.PHONY: go-bindata
go-bindata:
	GO111MODULE=off go get github.com/go-bindata/go-bindata/...


.PHONY: update-ipxe
update-ipxe: go-bindata
	{ \
	EMBED=$(HERE)/pixiecore/boot.ipxe \
	$(MAKE) -C third_party/ipxe/src \
	bin/ipxe.pxe \
	bin/undionly.kpxe \
	bin-x86_64-efi/ipxe.efi \
	bin-i386-efi/ipxe.efi \
	; }
	$(RM) -r third_party/ipxe/bin
	mkdir -vp third_party/ipxe/bin
	mv -f third_party/ipxe/src/bin/ipxe.pxe            third_party/ipxe/bin/ipxe.pxe
	mv -f third_party/ipxe/src/bin/undionly.kpxe       third_party/ipxe/bin/undionly.kpxe
	mv -f third_party/ipxe/src/bin-x86_64-efi/ipxe.efi third_party/ipxe/bin/ipxe-x86_64.efi 
	mv -f third_party/ipxe/src/bin-i386-efi/ipxe.efi   third_party/ipxe/bin/ipxe-i386.efi
	go-bindata -o third_party/ipxe/ipxe-bin.go -pkg ipxe -nometadata -nomemcopy -prefix third_party/ipxe/bin/ third_party/ipxe/bin
	gofmt -s -w third_party/ipxe/ipxe-bin.go
	$(RM) -r third_party/ipxe/bin
	$(MAKE) -C third_party/ipxe/src veryclean
