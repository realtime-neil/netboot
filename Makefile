# netboot/Makefile

THIS := $(abspath $(lastword $(MAKEFILE_LIST)))
HERE := $(patsubst %/,%,$(dir $(THIS)))
CWD := $(shell pwd)

$(info $$THIS is [${THIS}])
$(info $$HERE is [${HERE}])
$(info $$CWD is [${CWD}])


.PHONY: all
all: build


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


.PHONY: check
check: lint test


.PHONY: ci-push-images
ci-push-images: BINARY := pixiecore
ci-push-images: REGISTRY := pixiecore
ci-push-images: TAG := dev
ci-push-images: manifest-tool
	$(MAKE) -f Makefile.inc push BINARY=$(BINARY) REGISTRY=$(REGISTRY) GOARCH=amd64   TAG=$(TAG)-amd64
	$(MAKE) -f Makefile.inc push BINARY=$(BINARY) REGISTRY=$(REGISTRY) GOARCH=arm     TAG=$(TAG)-arm
	$(MAKE) -f Makefile.inc push BINARY=$(BINARY) REGISTRY=$(REGISTRY) GOARCH=arm64   TAG=$(TAG)-arm64
	$(MAKE) -f Makefile.inc push BINARY=$(BINARY) REGISTRY=$(REGISTRY) GOARCH=ppc64le TAG=$(TAG)-ppc64le
	$(MAKE) -f Makefile.inc push BINARY=$(BINARY) REGISTRY=$(REGISTRY) GOARCH=s390x   TAG=$(TAG)-s390x
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


# be clever (but not too clever) with Makefile targets and variables
#
# https://stackoverflow.com/questions/19571391/remove-prefix-with-make
# https://www.gnu.org/software/make/manual/html_node/File-Function.html
#
# override BUILD_ID_CMD and BUILD_TIMESTAMP for reproducible builds
#
# https://github.com/ipxe/ipxe/pull/82
# https://git.ipxe.org/ipxe.git/commitdiff/58f6e553625c90d928ddd54b8f31634a5b26f05e
# http://lists.ipxe.org/pipermail/ipxe-devel/2015-February/003978.html
third_party/ipxe/bin%: $(HERE)/pixiecore/boot.ipxe
	( \
	$(MAKE) -C third_party/ipxe/src \
	$(@:third_party/ipxe/%=%) \
	BUILD_ID_CMD="echo 0x00000000" \
	BUILD_TIMESTAMP="0x00000000" \
	EMBED="$<" \
	)
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
	$(MAKE) -C third_party/ipxe/src clean veryclean
