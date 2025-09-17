# Multi-stage Containerfile for dyndnsr53
# Supports linux/amd64 and linux/arm64

# Build stage
FROM --platform=$BUILDPLATFORM golang:1.21-alpine AS builder

# Build arguments
ARG TARGETPLATFORM
ARG BUILDPLATFORM
ARG TARGETOS
ARG TARGETARCH

# Install build dependencies
RUN apk add --no-cache git ca-certificates tzdata

# Set working directory
WORKDIR /src

# Copy go mod files
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy source code
COPY . .

# Build version info
ARG VERSION=dev
ARG COMMIT=unknown
ARG BUILD_DATE

# Build the binary
RUN CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} \
    go build \
    -ldflags="-w -s -X main.version=${VERSION} -X main.commit=${COMMIT} -X main.buildDate=${BUILD_DATE}" \
    -a -installsuffix cgo \
    -o dyndnsr53 \
    ./

# Verify the binary works
RUN ./dyndnsr53 --help

# Runtime stage
FROM --platform=$TARGETPLATFORM scratch

# Import from builder
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo
COPY --from=builder /src/dyndnsr53 /usr/local/bin/dyndnsr53

# Create non-root user
USER 65534:65534

# Expose default port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD ["/usr/local/bin/dyndnsr53", "--help"]

# Default command
ENTRYPOINT ["/usr/local/bin/dyndnsr53"]
CMD ["serve", "--help"]

# Labels
LABEL org.opencontainers.image.title="dyndnsr53"
LABEL org.opencontainers.image.description="A DynDNS-compatible API server for Route53"
LABEL org.opencontainers.image.url="https://github.com/cldmnky/dyndnsr53"
LABEL org.opencontainers.image.source="https://github.com/cldmnky/dyndnsr53"
LABEL org.opencontainers.image.licenses="Apache-2.0"
LABEL org.opencontainers.image.version="${VERSION}"
LABEL org.opencontainers.image.revision="${COMMIT}"
LABEL org.opencontainers.image.created="${BUILD_DATE}"