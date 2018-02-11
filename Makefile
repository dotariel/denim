ROOT_DIR:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
VERSION:=$(shell cat ${ROOT_DIR}/VERSION)

BINARY=denim
OUTPUT_DIR=gen
DIST_DIR=${OUTPUT_DIR}/dist
BUILD=`git rev-parse HEAD`
BUILD_DATE:=`date -u '+%Y-%m-%d_%I:%M:%S%p'`
PLATFORMS=darwin linux windows
ARCHITECTURES=386 amd64
LDFLAGS=-ldflags "-X github.com/dotariel/denim/app.Version=${VERSION} -X github.com/dotariel/denim/app.Build=${BUILD} -X github.com/dotariel/denim/app.BuildDate=${BUILD_DATE}"

default: test

build:
	go build ${LDFLAGS} -o ${OUTPUT_DIR}/${BINARY}

dist:
	$(foreach GOOS, $(PLATFORMS),\
	$(foreach GOARCH, $(ARCHITECTURES), $(shell export GOOS=$(GOOS); export GOARCH=$(GOARCH); go build -v ${LDFLAGS} -o ${DIST_DIR}/$(GOOS)/$(GOARCH)/$(BINARY))))

dep:
	go get -v .

install: dep
	go install -a ${LDFLAGS}

clean:
	find ${ROOT_DIR} -name '${BINARY}[-?][a-zA-Z0-9]*[-?][a-zA-Z0-9]*' -delete
	rm -fr ${OUTPUT_DIR}

test:
	go get -t ./...
	go test -v ./...

.PHONY: all build dist install clean test dep
