PROJECT_DIR:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
BINARY=denim
OUTPUT_DIR=$(PROJECT_DIR)/gen
DIST_DIR=$(OUTPUT_DIR)/dist
GIT_DESCRIBE:=$(shell git -C $(PROJECT_DIR) describe --tags --always --dirty)
BUILD_DATE:=$(shell git -C $(PROJECT_DIR) log -1 --format=%cI)
BUILD_VERSION?=$(GIT_DESCRIBE:v%=%)
LDFLAGS=-ldflags=all="-X github.com/dotariel/denim/app.Version=$(BUILD_VERSION) -X github.com/dotariel/denim/app.BuildDate=$(BUILD_DATE)"
BUILD_FLAGS=-trimpath -buildvcs=false

default: dist

build:
	@cd src && go build -a -o $(OUTPUT_DIR)/$(BINARY) $(BUILD_FLAGS) $(LDFLAGS)

dist: test dist-linux dist-darwin dist-windows

dist-linux:
	@cd src && CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o $(DIST_DIR)/$(BINARY)_linux_amd64 $(BUILD_FLAGS) $(LDFLAGS)
	@cd src && CGO_ENABLED=0 GOOS=linux GOARCH=arm64 go build -o $(DIST_DIR)/$(BINARY)_linux_arm64 $(BUILD_FLAGS) $(LDFLAGS)

dist-darwin:
	@cd src && CGO_ENABLED=0 GOOS=darwin GOARCH=amd64 go build -o $(DIST_DIR)/$(BINARY)_darwin_amd64 $(BUILD_FLAGS) $(LDFLAGS)
	@cd src && CGO_ENABLED=0 GOOS=darwin GOARCH=arm64 go build -o $(DIST_DIR)/$(BINARY)_darwin_arm64 $(BUILD_FLAGS) $(LDFLAGS)

dist-windows:
	@cd src && CGO_ENABLED=0 GOOS=windows GOARCH=amd64 go build -o $(DIST_DIR)/$(BINARY)_windows_amd64.exe $(BUILD_FLAGS) $(LDFLAGS)

dep:
	@cd src && go mod download

dep-test:
	@cd src && go mod download

install: dep
	@cd src && go build -a -o $(shell go env GOPATH)/bin/$(BINARY) $(BUILD_FLAGS) $(LDFLAGS)

clean:
	@find $(PROJECT_DIR) -name '$(BINARY)[-?][a-zA-Z0-9]*[-?][a-zA-Z0-9]*' -delete
	@rm -fr $(OUTPUT_DIR)

test: dep-test
	@cd src && go test -v -coverprofile=coverage.txt -covermode=atomic ./...

.PHONY: all default build dist dist-linux dist-darwin dist-windows dep dep-test install clean test
