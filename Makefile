ROOT_DIR:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
VERSION:=$(shell cat ${ROOT_DIR}/VERSION)

BINARY=denim
OUTPUT_DIR=gen
DIST_DIR=${OUTPUT_DIR}/dist
BUILD=`git rev-parse HEAD`
PLATFORMS=darwin linux windows
ARCHITECTURES=386 amd64
LDFLAGS=-ldflags "-X main.Version=${VERSION} -X main.Build=${BUILD}"

default: dep test

build:
	go build ${LDFLAGS} -o ${OUTPUT_DIR}/${BINARY}

dist:
	$(foreach GOOS, $(PLATFORMS),\
	$(foreach GOARCH, $(ARCHITECTURES), $(shell export GOOS=$(GOOS); export GOARCH=$(GOARCH); go build -v -o ${DIST_DIR}/$(BINARY)-$(GOOS)-$(GOARCH))))

dep:
	go get -v

install:
	go install ${LDFLAGS}

clean:
	find ${ROOT_DIR} -name '${BINARY}[-?][a-zA-Z0-9]*[-?][a-zA-Z0-9]*' -delete
	rm -fr ${OUTPUT_DIR}

test:
	go test -v ./...

.PHONY: all build dist install clean test