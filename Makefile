# netboot/Makefile

THIS := $(abspath $(lastword $(MAKEFILE_LIST)))
HERE := $(patsubst %/,%,$(dir $(THIS)))
CWD := $(shell pwd)


LIBC_SO := $(shell find /usr/lib -name 'libc.so' -exec readlink -f {} +)
ifneq (,$(findstring musl,$(LIBC_SO)))
  GO_LDFLAGS := '-s -w -linkmode external -extldflags "-static"'
else
  GO_LDFLAGS := '-s -w'
endif


GO_FILES := \
  $(HERE)/cmd/pixiecore-apache2/main.go \
  $(HERE)/cmd/pixiecore/main.go \
  $(HERE)/dhcp4/conn.go \
  $(HERE)/dhcp4/conn_linux.go \
  $(HERE)/dhcp4/conn_linux_test.go \
  $(HERE)/dhcp4/conn_test.go \
  $(HERE)/dhcp4/conn_unsupported.go \
  $(HERE)/dhcp4/doc.go \
  $(HERE)/dhcp4/options.go \
  $(HERE)/dhcp4/options_test.go \
  $(HERE)/dhcp4/packet.go \
  $(HERE)/dhcp4/packet_test.go \
  $(HERE)/dhcp6/address_pool.go \
  $(HERE)/dhcp6/boot_configuration.go \
  $(HERE)/dhcp6/conn.go \
  $(HERE)/dhcp6/options.go \
  $(HERE)/dhcp6/options_test.go \
  $(HERE)/dhcp6/packet.go \
  $(HERE)/dhcp6/packet_builder.go \
  $(HERE)/dhcp6/packet_builder_test.go \
  $(HERE)/dhcp6/packet_test.go \
  $(HERE)/dhcp6/pool/random_address_pool.go \
  $(HERE)/dhcp6/pool/random_address_pool_test.go \
  $(HERE)/ipxe/ipxe.go \
  $(HERE)/pcap/reader.go \
  $(HERE)/pcap/reader_test.go \
  $(HERE)/pcap/writer.go \
  $(HERE)/pcap/writer_test.go \
  $(HERE)/pixiecore/api-example/main.go \
  $(HERE)/pixiecore/boot_configuration.go \
  $(HERE)/pixiecore/booters.go \
  $(HERE)/pixiecore/booters_test.go \
  $(HERE)/pixiecore/cli/apicmd.go \
  $(HERE)/pixiecore/cli/bootcmd.go \
  $(HERE)/pixiecore/cli/bootipv6cmd.go \
  $(HERE)/pixiecore/cli/cli.go \
  $(HERE)/pixiecore/cli/debugcmd.go \
  $(HERE)/pixiecore/cli/ipv6apicmd.go \
  $(HERE)/pixiecore/cli/logging.go \
  $(HERE)/pixiecore/cli/quickcmd.go \
  $(HERE)/pixiecore/cli/v1compat.go \
  $(HERE)/pixiecore/dhcp.go \
  $(HERE)/pixiecore/dhcpv6.go \
  $(HERE)/pixiecore/http.go \
  $(HERE)/pixiecore/http_test.go \
  $(HERE)/pixiecore/logging.go \
  $(HERE)/pixiecore/pixicorev6.go \
  $(HERE)/pixiecore/pixiecore.go \
  $(HERE)/pixiecore/pxe.go \
  $(HERE)/pixiecore/tftp.go \
  $(HERE)/pixiecore/urlsign.go \
  $(HERE)/pixiecore/urlsign_test.go \
  $(HERE)/tftp/handlers.go \
  $(HERE)/tftp/interop_test.go \
  $(HERE)/tftp/tftp.go


GOARCHES := amd64 arm arm64 ppc64le s390x


.PHONY: all
all: $(addprefix $(CURDIR)/out/, $(addsuffix /pixiecore, $(GOARCHES)))


$(CURDIR)/out/%/pixiecore: GOARCH=$(notdir $(patsubst %/,%,$(dir $@)))
$(CURDIR)/out/%/pixiecore: $(GO_FILES)
	mkdir -vp $(dir $@)
	GO111MODULE=on CGO_ENABLED=0 GOOS=linux GOARCH=$(GOARCH) GOARM=6 \
	go build -buildmode=pie -ldflags=$(GO_LDFLAGS) -o $@ $(CURDIR)/cmd/pixiecore


.PHONY: install
install:
	go install $(CURDIR)/cmd/pixiecore


.PHONY: manifest-tool
manifest-tool:
	GO111MODULE=off go get -u -v github.com/estesp/manifest-tool


.PHONY: test
test:
	GO111MODULE=on go test ./...
	GO111MODULE=on go test -race ./...


.PHONY: lint
lint:
	GO111MODULE=on go vet ./...


.PHONY: check
check: lint test


# ifeq (,$(strip $(GOARCH)))
#   $(error undefined GOARCH)
# endif
# ifeq (,$(strip $(REGISTRY)))
#   $(error undefined REGISTRY)
# endif
# ifeq (,$(strip $(BINARY)))
#   $(error undefined BINARY)
# endif
# ifeq (,$(strip $(TAG)))
#   $(error undefined TAG)
# endif

.PHONY: images
images: IMAGE_NAME := registry.gitlab.com/realtime-neil/netboot
images:
	{ \
	true \
	&& mkdir -vp $(HERE)/out \
	&& touch $(HERE)/out/netboot.tar \
	&& docker container run \
    --interactive \
    --mount type=bind,readonly,source="$(HERE)",target="$(HERE)" \
    --mount type=bind,source="$(HERE)/out",target="$(HERE)/out" \
    --rm \
	gcr.io/kaniko-project/executor \
	--no-push \
	--context $(HERE) \
	--dockerfile $(HERE)/Dockerfile \
	--destination $(IMAGE_NAME) \
	--target stage1 \
	--tarPath $(HERE)/out/netboot.tar \
	; }


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


.PHONY: update-ipxe
update-ipxe: $(HERE)/ipxe/ipxe.go


IPXE_BINS := \
  third_party/ipxe/bin-i386-efi/ipxe.efi \
  third_party/ipxe/bin-x86_64-efi/ipxe.efi \
  third_party/ipxe/bin/ipxe.pxe \
  third_party/ipxe/bin/undionly.kpxe


$(CURDIR)/ipxe/ipxe.go: go-bindata $(IPXE_BINS)
	rm -vf $@
	go-bindata -o $@ -pkg ipxe -nometadata -nomemcopy -prefix third_party/ipxe $(sort $(dir $(IPXE_BINS)))
	gofmt -s -w $@


.PHONY: go-bindata
go-bindata:
	GO111MODULE=off go get github.com/go-bindata/go-bindata/...


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


.PHONY: clean
clean:
	if false; then go clean; fi
	rm -rf $(HERE)/out $(sort $(dir $(IPXE_BINS)))
	$(MAKE) -C third_party/ipxe/src clean veryclean

