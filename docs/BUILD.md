# Build and Development Guide

## Prerequisites

- Go 1.24 or later
- Make
- [ko](https://ko.build/) for container builds (auto-installed via Makefile)
- [entr](http://eradman.org/entrproject/) for hot reload (auto-installed via Makefile)

## Quick Start

### Install Development Tools
```bash
make tools
```
This installs `ko` for container builds and `entr` for hot reload.

## Building

### Local Development Build
```bash
make build
```

### Cross-compilation
```bash
make build-cross
```

### With Version Information
```bash
make build-with-version
```

## Container Builds

The project uses [ko](https://ko.build/) for efficient Go container builds:

### Build Multi-architecture Container
```bash
make container-build
```

### Build Local Container Only
```bash
make container-build-local
```

### Build and Run Container
```bash
make container-run
```

### Container Information
```bash
make container-info
```

### Push to Registry
```bash
REGISTRY=your-registry.com make container-build
```

## Testing

### Run All Tests
```bash
make test
```

### Test Coverage
```bash
make coverage
```

### Test with Coverage HTML Report
```bash
make coverage-html
```

## Development Workflow

### Hot Reload Development
```bash
make dev
```
This automatically rebuilds and restarts the server when Go files change.

### Standard Workflow
1. **Setup**: `make tools` to install development tools
2. **Build**: `make build` for quick builds during development
3. **Test**: `make test` after changes
4. **Container**: `make container-build-local` for testing containers
5. **Clean**: `make clean` to remove build artifacts

## Available Make Targets

Run `make help` to see all available targets:

```bash
make help
```

## Container Technology

This project uses **ko** instead of traditional Dockerfile builds because:
- **Faster builds**: No need for multi-stage Dockerfiles
- **Smaller images**: Automatically optimized base images
- **Multi-architecture**: Built-in cross-platform support
- **Go-optimized**: Designed specifically for Go applications
- **Security**: Uses distroless base images by default

## Container Registry

By default, containers are tagged as `docker.io/dyndnsr53`. Override with:

```bash
REGISTRY=ghcr.io/yourusername make container-build
```

## Version Information

The build system automatically injects version information:
- Git commit hash
- Build timestamp
- Version tag (if available)

View version information:
```bash
./build/dyndnsr53 version
```