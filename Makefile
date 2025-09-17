# Makefile for dyndnsr53
#
# TLDR - Quick Commands:
#   Building:     make build                          # Build binary to ./build/dyndnsr53
#   Testing:      make test                           # Run all tests
#   Running:      make run                            # Build and run the server
#   Development:  make dev                            # Hot reload development
#   Container:    make container-build                # Build multi-arch container
#   Push:         VERSION=v1.0.0 make container-build # Build and push with specific tag
#   Release:      VERSION=v1.0.0 make tag             # Create git tag (triggers CI/CD)
#   Tools:        make tools                          # Install all dev tools locally
#   Help:         make help                           # Show all available targets
#
# Examples:
#   make build && ./build/dyndnsr53 serve --provider none --listen :8080
#   REGISTRY=quay.io/myuser make container-build
#   VERSION=v1.2.3 make container-build               # Tags: v1.2.3 and latest
#   VERSION=v1.2.3 make tag                           # Create tag and trigger CI/CD

# Go parameters
GOCMD=go
GOBUILD=$(GOCMD) build
GOCLEAN=$(GOCMD) clean
GOTEST=$(GOCMD) test
GOGET=$(GOCMD) get
GOMOD=$(GOCMD) mod

# Build directory
BUILD_DIR=./build

# Local bin directory for tools
LOCALBIN ?= $(shell pwd)/bin
$(LOCALBIN):
	mkdir -p $(LOCALBIN)

# Binary names
BINARY_NAME=dyndnsr53
BINARY_UNIX=$(BINARY_NAME)_unix
BINARY_WINDOWS=$(BINARY_NAME).exe

# Git versioning
VERSION ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo "dev")
COMMIT ?= $(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")
BUILD_DATE ?= $(shell date -u +"%Y-%m-%dT%H:%M:%SZ")

# Build flags
LDFLAGS = -ldflags="-X main.version=$(VERSION) -X main.commit=$(COMMIT) -X main.buildDate=$(BUILD_DATE)"

# Container settings
REGISTRY ?= quay.io/cldmnky
IMAGE_NAME ?= $(REGISTRY)/dyndnsr53
PLATFORMS ?= linux/amd64,linux/arm64

# Tool Binaries
KO ?= $(LOCALBIN)/ko
AIR ?= $(LOCALBIN)/air
GOLANGCI_LINT ?= $(LOCALBIN)/golangci-lint

# Tool Versions
GOLANGCI_LINT_VERSION ?= v1.54.2

.PHONY: all build-all build-cross build-linux build-windows build-darwin clean test coverage deps help run dev install tools ko air golangci-lint lint lint-fix container-build container-build-local container-build-local-multiarch container-push container-run container-info

## Create build directory
$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

## Default target
all: test build-binary

## Build the binary (alias for build-binary)
build: build-binary

## Build the binary target - creates ./build/dyndnsr53
build-binary: $(BUILD_DIR)
	$(GOBUILD) $(LDFLAGS) -o $(BUILD_DIR)/$(BINARY_NAME) -v ./

## Build for multiple architectures - creates all platform binaries
build-cross: build-linux build-windows build-darwin

## Build for Linux
build-linux: $(BUILD_DIR)
	CGO_ENABLED=0 GOOS=linux GOARCH=amd64 $(GOBUILD) $(LDFLAGS) -o $(BUILD_DIR)/$(BINARY_UNIX)-amd64 -v ./
	CGO_ENABLED=0 GOOS=linux GOARCH=arm64 $(GOBUILD) $(LDFLAGS) -o $(BUILD_DIR)/$(BINARY_UNIX)-arm64 -v ./

## Build for Windows
build-windows: $(BUILD_DIR)
	CGO_ENABLED=0 GOOS=windows GOARCH=amd64 $(GOBUILD) $(LDFLAGS) -o $(BUILD_DIR)/$(BINARY_WINDOWS) -v ./

## Build for macOS
build-darwin: $(BUILD_DIR)
	CGO_ENABLED=0 GOOS=darwin GOARCH=amd64 $(GOBUILD) $(LDFLAGS) -o $(BUILD_DIR)/$(BINARY_NAME)-darwin-amd64 -v ./
	CGO_ENABLED=0 GOOS=darwin GOARCH=arm64 $(GOBUILD) $(LDFLAGS) -o $(BUILD_DIR)/$(BINARY_NAME)-darwin-arm64 -v ./

## Run tests
test:
	$(GOTEST) -v ./...

## Run tests with coverage
coverage: $(BUILD_DIR)
	$(GOTEST) -v -coverprofile=$(BUILD_DIR)/coverage.out ./...
	$(GOCMD) tool cover -html=$(BUILD_DIR)/coverage.out -o $(BUILD_DIR)/coverage.html

## Run tests with race detection
test-race:
	$(GOTEST) -v -race ./...

## Run benchmarks
bench:
	$(GOTEST) -v -bench=. ./...

## Format code
fmt:
	$(GOCMD) fmt ./...

## Tidy dependencies
tidy:
	$(GOMOD) tidy

## Download dependencies
deps:
	$(GOMOD) download

## Update dependencies
deps-update:
	$(GOMOD) get -u ./...
	$(GOMOD) tidy

## Clean build artifacts
clean:
	$(GOCLEAN)
	rm -rf $(BUILD_DIR)
	rm -rf $(LOCALBIN)

## Run the application - builds then runs ./build/dyndnsr53
run: build
	$(BUILD_DIR)/$(BINARY_NAME)

## Run with hot reload (requires air) - auto-rebuilds on file changes
dev: air
	@echo "Starting development server with hot reload..."
	@echo "Edit Go files and the server will automatically rebuild and restart"
	$(AIR) -c .air.toml

## Install the binary to GOPATH/bin
install:
	$(GOCMD) install $(LDFLAGS) ./

##@ Build Dependencies

## Install development tools
tools: ko air golangci-lint

## Download ko locally if necessary
.PHONY: ko
ko: $(KO)
$(KO): $(LOCALBIN)
	test -s $(LOCALBIN)/ko || GOBIN=$(LOCALBIN) go install github.com/google/ko@latest

## Download air locally if necessary
.PHONY: air
air: $(AIR)
$(AIR): $(LOCALBIN)
	test -s $(LOCALBIN)/air || GOBIN=$(LOCALBIN) go install github.com/air-verse/air@latest

## Download golangci-lint locally if necessary
.PHONY: golangci-lint
golangci-lint: $(GOLANGCI_LINT)
$(GOLANGCI_LINT): $(LOCALBIN)
	@[ -f $(GOLANGCI_LINT) ] || { \
		set -e ;\
		curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s -- -b $(shell dirname $(GOLANGCI_LINT)) $(GOLANGCI_LINT_VERSION) ;\
	}

## Run golangci-lint linter
.PHONY: lint
lint: golangci-lint
	$(GOLANGCI_LINT) run

## Run golangci-lint linter and perform fixes
.PHONY: lint-fix
lint-fix: golangci-lint
	$(GOLANGCI_LINT) run --fix

# Container targets using ko
# Ko automatically pushes images when building, tags with both VERSION and latest
container-build: ko ## Build multi-arch container image using ko
	@echo "Building container image with ko: $(IMAGE_NAME):$(VERSION)"
	@echo "Image will be tagged as: $(VERSION) and latest"
	@echo "Platforms: $(PLATFORMS)"
	@echo "Note: This will attempt to push to registry. Use 'make container-build-local' for local builds."
	VERSION=$(VERSION) COMMIT=$(COMMIT) BUILD_DATE=$(BUILD_DATE) KO_DOCKER_REPO=$(REGISTRY) $(KO) build --platform=$(PLATFORMS) --tags=$(VERSION),latest --base-import-paths .

container-build-local: ko ## Build container image for local platform only
	@echo "Building local container image with ko: ko.local/github.com/cldmnky/dyndnsr53:$(VERSION)"
	VERSION=$(VERSION) COMMIT=$(COMMIT) BUILD_DATE=$(BUILD_DATE) KO_DOCKER_REPO=ko.local $(KO) build --tags=$(VERSION),latest --preserve-import-paths .

container-build-local-multiarch: ko ## Build multi-arch container image locally (no push)
	@echo "Building local multi-arch container image with ko: ko.local/github.com/cldmnky/dyndnsr53:$(VERSION)"
	@echo "Platforms: $(PLATFORMS)"
	VERSION=$(VERSION) COMMIT=$(COMMIT) BUILD_DATE=$(BUILD_DATE) KO_DOCKER_REPO=ko.local $(KO) build --platform=$(PLATFORMS) --tags=$(VERSION),latest --preserve-import-paths .

container-push: container-build ## Push container image to registry
	@echo "Container images are automatically pushed by ko build"
	@echo "Images pushed: $(IMAGE_NAME):$(VERSION) and $(IMAGE_NAME):latest"

container-run: container-build-local ## Build and run container locally
	@echo "Running container: ko.local/github.com/cldmnky/dyndnsr53:$(VERSION)"
	@echo "Starting DynDNS server on http://localhost:8080"
	/opt/podman/bin/podman run --rm -p 8080:8080 ko.local/github.com/cldmnky/dyndnsr53:$(VERSION) serve --provider none --listen :8080

## Show ko build information
container-info:
	@echo "Container build tool: ko"
	@echo "Registry: $(REGISTRY)"
	@echo "Image name: $(IMAGE_NAME)"
	@echo "Platforms: $(PLATFORMS)"
	@echo "Version: $(VERSION)"

## Security scan
security:
	gosec ./...

## Verify everything works
verify: deps tidy fmt test lint

## Create and push a git tag (triggers GitHub Actions release)
tag:
	@if [ -z "$(VERSION)" ]; then \
		echo "Error: VERSION is required. Usage: make tag VERSION=v1.0.0"; \
		exit 1; \
	fi
	@echo "Creating and pushing tag: $(VERSION)"
	git tag $(VERSION)
	git push origin $(VERSION)
	@echo "Tag $(VERSION) pushed. GitHub Actions will now build and push the container image."

## Show help
help:
	@echo "dyndnsr53 - DynDNS Route53 Server"
	@echo ""
	@echo "TLDR - Quick Commands:"
	@echo "  make build                           # Build binary to ./build/dyndnsr53"
	@echo "  make test                            # Run all tests"
	@echo "  make run                             # Build and run the server"
	@echo "  make dev                             # Hot reload development"
	@echo "  make container-build                 # Build multi-arch container"
	@echo "  VERSION=v1.0.0 make container-build  # Build and push with specific tag"
	@echo "  VERSION=v1.0.0 make tag              # Create git tag (triggers CI/CD)"
	@echo "  make tools                           # Install all dev tools locally"
	@echo ""
	@echo "Available targets:"
	@echo ""
	@echo "Build targets:"
	@grep -E '^## (Build|Create|Default).*' $(MAKEFILE_LIST) | sed 's/## /  /'
	@echo ""
	@echo "Test targets:"
	@grep -E '^## (Run tests|Run benchmarks).*' $(MAKEFILE_LIST) | sed 's/## /  /'
	@echo ""
	@echo "Development targets:"
	@grep -E '^## (Run the|Run with|Format|Tidy|Download|Update|Install the|Install development).*' $(MAKEFILE_LIST) | sed 's/## /  /'
	@echo ""
	@echo "Container targets:"
	@grep -E '^container-.*:.*##' $(MAKEFILE_LIST) | sed 's/:.*## / - /'
	@echo ""
	@echo "Tool targets:"
	@grep -E '^## (Download.*locally).*' $(MAKEFILE_LIST) | sed 's/## /  /'
	@echo ""
	@echo "Quality targets:"
	@grep -E '^## (Run golangci|Security|Verify).*' $(MAKEFILE_LIST) | sed 's/## /  /'
	@echo ""
	@echo "Pipeline targets:"
	@grep -E '^## (CI|Release).*' $(MAKEFILE_LIST) | sed 's/## /  /'
	@echo ""
	@echo "Examples:"
	@echo "  make build && ./build/dyndnsr53 serve --provider none --listen :8080"
	@echo "  REGISTRY=quay.io/myuser make container-build"
	@echo "  VERSION=v1.2.3 make container-build    # Tags: v1.2.3 and latest"
	@echo "  VERSION=v1.2.3 make tag                # Create tag and trigger CI/CD"
	@echo ""
	@echo "Registry: $(REGISTRY)"
	@echo "Image:    $(IMAGE_NAME)"
	@echo "Version:  $(VERSION)"

## CI pipeline
ci: verify coverage

## Release pipeline
release: clean verify build-cross container-build

.DEFAULT_GOAL := help