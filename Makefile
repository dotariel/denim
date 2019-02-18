PROJECT_DIR:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
BINARY=denim
OUTPUT_DIR=$(PROJECT_DIR)/gen
DIST_DIR=$(OUTPUT_DIR)/dist
PROJECT_VERSION:=$(shell cat $(PROJECT_DIR)/VERSION | tr -d '\n')
PROJECT_COMMIT:=$(shell git -C $(PROJECT_DIR) rev-parse --short HEAD)
PROJECT_BUILD_VERSION:=$(PROJECT_VERSION).$(PROJECT_COMMIT)
PROJECT_BUILD_DATE="$(shell date -u +%FT%T.000Z)"
LDFLAGS=-ldflags=all="-X github.com/dotariel/denim/app.Version=$(PROJECT_BUILD_VERSION) -X github.com/dotariel/denim/app.BuildDate=$(PROJECT_BUILD_DATE)"
LINUX_ARGS:=GOOS=linux
DARWIN_ARGS:=GOOS=darwin
WINDOWS_ARGS=GOOS=windows

default: dist

build:
	@cd cmd && go build -a -o $(OUTPUT_DIR)/$(BINARY) $(LDFLAGS)

dist: test dist-linux dist-darwin dist-windows

dist-linux:
	@cd cmd && $(LINUX_ARGS) go get -u -d ./... && CGO_ENABLED=0 $(LINUX_ARGS) go build -o $(DIST_DIR)/$(BINARY)_linux_amd64

dist-darwin:
	@cd cmd && $(DARWIN_ARGS) go get -u -d ./... && CGO_ENABLED=0 $(DARWIN_ARGS) go build -o $(DIST_DIR)/$(BINARY)_darwin_amd64

dist-windows:
	@cd cmd && $(WINDOWS_ARGS) go get -u -d ./... && CGO_ENABLED=0 $(WINDOWS_ARGS) go build -o $(DIST_DIR)/$(BINARY)_windows_amd64.exe

dep:
	@go get -v -u -d ./...

dep-test:
	@go get ./...

install: dep
	@cd cmd && go build -a -o $(GOPATH)/bin/$(BINARY) $(LDFLAGS)

clean:
	@find $(PROJECT_DIR) -name '$(BINARY)[-?][a-zA-Z0-9]*[-?][a-zA-Z0-9]*' -delete
	@rm -fr $(OUTPUT_DIR)

test: dep-test
	@go test -v -coverprofile=coverage.txt -covermode=atomic ./...

.PHONY: all
