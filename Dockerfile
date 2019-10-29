# netboot/Dockerfile
FROM golang:alpine AS build
WORKDIR /go/src/github.com/danderson/netboot
RUN apk add -U gcc git make musl-dev perl xz-dev
COPY . .
RUN make -j$(nproc)

FROM alpine:latest AS deploy
RUN apk add -U ca-certificates
COPY --from=build /go/src/github.com/danderson/netboot/out/pixiecore /pixiecore
ENTRYPOINT [ "/pixiecore" ]
CMD [ "help" ]
