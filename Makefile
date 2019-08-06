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


IPXE_BINS := \
  third_party/ipxe/bin-i386-efi/ipxe.efi \
  third_party/ipxe/bin-x86_64-efi/ipxe.efi \
  third_party/ipxe/bin/ipxe.pxe \
  third_party/ipxe/bin/undionly.kpxe

# https://stackoverflow.com/questions/19571391/remove-prefix-with-make
# https://www.gnu.org/software/make/manual/html_node/File-Function.html
third_party/ipxe/bin%: $(HERE)/pixiecore/boot.ipxe
	(cd third_party/ipxe/src && $(MAKE) $(@:third_party/ipxe/%=%) EMBED=$<;)
	mkdir -vp $(dir $@)
	cp -v third_party/ipxe/src/$(@:third_party/ipxe/%=%) $@


ipxe/ipxe.go: go-bindata $(IPXE_BINS)
	rm -vf $@
	go-bindata -o $@ -pkg ipxe -nometadata -nomemcopy -prefix third_party/ipxe $(sort $(dir $(IPXE_BINS)))
	gofmt -s -w $@


.PHONY: update-ipxe
update-ipxe: ipxe/ipxe.go


.PHONY: clean
clean:
	rm -rf $(sort $(dir $(IPXE_BINS)))
	$(MAKE) -C third_party/ipxe/src veryclean
