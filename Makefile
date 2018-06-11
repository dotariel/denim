PROJECT_DIR:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
BINARY=denim
OUTPUT_DIR=$(PROJECT_DIR)/gen
DIST_DIR=$(OUTPUT_DIR)/dist
PROJECT_VERSION:=$(shell cat $(PROJECT_DIR)/VERSION | tr -d '\n')
PROJECT_COMMIT:=$(shell git -C $(PROJECT_DIR) rev-parse --short HEAD)
PROJECT_BUILD_VERSION:=$(PROJECT_VERSION).$(PROJECT_COMMIT)
PROJECT_BUILD_DATE="$(shell date -u +%FT%T.000Z)"
LDFLAGS=-ldflags=all="-X github.com/dotariel/denim/app.Version=$(PROJECT_BUILD_VERSION) -X github.com/dotariel/denim/app.BuildDate=$(PROJECT_BUILD_DATE)"

default: dist

build:
	@cd cmd && go build -a -o $(OUTPUT_DIR)/$(BINARY) $(LDFLAGS)

dist: dep dist-linux dist-windows dist-darwin

dist-linux:
	@cd cmd && CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o $(DIST_DIR)/linux/$(BINARY)

dist-windows:
	@cd cmd && CGO_ENABLED=0 GOOS=windows GOARCH=amd64 go build -o $(DIST_DIR)/windows/$(BINARY)

dist-darwin:
	@cd cmd && CGO_ENABLED=0 GOOS=darwin GOARCH=amd64 go build -o $(DIST_DIR)/darwin/$(BINARY)

dep:
	@go get -v -d ./...

dep-test:
	@go get -t ./...

install: dep
	@cd cmd && go build -a -o $(GOPATH)/bin/$(BINARY) $(LDFLAGS)

clean:
	@find $(PROJECT_DIR) -name '$(BINARY)[-?][a-zA-Z0-9]*[-?][a-zA-Z0-9]*' -delete
	@rm -fr $(OUTPUT_DIR)

test: dep-test
	@go test -v ./...

.PHONY: all
