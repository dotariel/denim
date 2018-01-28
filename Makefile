ROOT_DIR:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))

BINARY=denim
VERSION=0.0.1
OUTPUT_DIR=gen
DIST_DIR=${OUTPUT_DIR}/dist
BUILD=`git rev-parse HEAD`
PLATFORMS=darwin linux windows
ARCHITECTURES=386 amd64
LDFLAGS=-ldflags "-X main.Version=${VERSION} -X main.Build=${BUILD}"

default: build

all: clean dist install

build:
	go build ${LDFLAGS} -o ${OUTPUT_DIR}/${BINARY}

dist:
	$(foreach GOOS, $(PLATFORMS),\
	$(foreach GOARCH, $(ARCHITECTURES), $(shell export GOOS=$(GOOS); export GOARCH=$(GOARCH); go build -v -o ${DIST_DIR}/$(BINARY)-$(GOOS)-$(GOARCH))))

install:
	go install ${LDFLAGS}

clean:
	find ${ROOT_DIR} -name '${BINARY}[-?][a-zA-Z0-9]*[-?][a-zA-Z0-9]*' -delete
	rm -fr ${OUTPUT_DIR}

.PHONY: all build dist install clean