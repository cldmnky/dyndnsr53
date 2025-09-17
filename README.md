# dyndnsr53

A lightweight DynDNS API server that provides dynamic DNS updates compatible with the DynDNS v2/v3 protocol. Built specifically for AWS Route53 integration, it allows automatic IP address updates for domain records.

## Features

- **DynDNS v2/v3 Compatible**: Works with standard DynDNS clients and routers
- **AWS Route53 Integration**: Direct integration with Amazon Route53 for DNS record management
- **Provider Architecture**: Pluggable provider system for extensibility
- **JSON Request Logging**: Structured logging with klog for observability
- **Hot Reload Development**: Fast development cycle with air
- **Container Support**: Multi-architecture container builds with ko
- **Comprehensive Testing**: Full test coverage with benchmarks
- **Modern Go Tooling**: Uses Go modules, golangci-lint, and local tool management

## Quick Start

### Prerequisites

- Go 1.24+
- Make
- (Optional) Podman for container operations

### Building

```bash
# Build the binary
make build

# Run tests
make test

# Build for multiple platforms
make build-cross
```

### Running

```bash
# Run locally with test provider
./build/dyndnsr53 serve --provider none --listen :8080

# Or use make for quick development
make run

# Hot reload development server
make dev
```

### Container Operations

```bash
# Build local container
make container-build-local

# Build and run container
make container-run

# Build multi-arch container and push to registry
make container-build

# Push with specific version
VERSION=v1.0.0 make container-build
```

## Configuration

### Providers

#### Route53 Provider

For AWS Route53 integration:

```bash
./dyndnsr53 serve --provider route53 --zone-id Z1234567890ABC --listen :8080
```

Requires AWS credentials configured via:

- AWS credentials file (`~/.aws/credentials`)
- Environment variables (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`)
- IAM roles (when running on EC2)

Required IAM permissions:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "route53:ChangeResourceRecordSets",
                "route53:GetHostedZone"
            ],
            "Resource": "arn:aws:route53:::hostedzone/Z1234567890ABC"
        }
    ]
}
```

#### None Provider

For testing and development:

```bash
./dyndnsr53 serve --provider none --listen :8080
```

This provider logs requests but doesn't update any DNS records.

### DynDNS Client Configuration

Configure your router or DynDNS client with:

- **Server**: `http://your-server:8080/nic/update`
- **Username**: Any value (currently not validated)
- **Password**: Any value (currently not validated)
- **Hostname**: The FQDN to update (e.g., `home.example.com`)

## API Endpoints

### Update Record

```http
GET /nic/update?hostname=<fqdn>&myip=<ip>
```

**Parameters:**

- `hostname`: Fully qualified domain name to update
- `myip`: IP address to set (optional, defaults to client IP)

**Response:**

- `good <ip>`: Update successful
- `nochg <ip>`: No change needed
- `notfqdn`: Invalid hostname format
- `nohost`: Hostname not found
- `911`: Server error

## Development

### Tool Installation

```bash
# Install all development tools locally
make tools

# Individual tools
make ko        # Container builder
make air       # Hot reload
make golangci-lint  # Linter
```

### Code Quality

```bash
# Run linter
make lint

# Fix linting issues
make lint-fix

# Format code
make fmt

# Run security scan
make security

# Verify everything
make verify
```

### Continuous Integration

The project includes automated GitHub Actions workflows for testing, building, and deploying:

```bash
# Create and push a new release tag
git tag v1.0.0
git push origin v1.0.0
```

This triggers:

- Automated testing (unit tests, race detection, linting)
- Multi-architecture container builds (linux/amd64, linux/arm64)
- Security scanning with Trivy
- Publishing to `quay.io/cldmnky/dyndnsr53`

See [GitHub Actions Setup](docs/GITHUB_ACTIONS.md) for configuration details.

### Testing

```bash
# Run all tests
make test

# Run tests with coverage
make coverage

# Run tests with race detection
make test-race

# Run benchmarks
make bench
```

## Deployment

### Container Deployment

The application provides multi-architecture container images:

```bash
# Pull and run
podman run -p 8080:8080 quay.io/cldmnky/dyndnsr53:latest serve --provider none

# With Route53
podman run -p 8080:8080 \
  -e AWS_ACCESS_KEY_ID=your-key \
  -e AWS_SECRET_ACCESS_KEY=your-secret \
  quay.io/cldmnky/dyndnsr53:latest serve --provider route53 --zone-id Z1234567890ABC
```

### Kubernetes Deployment

Example Kubernetes deployment:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dyndnsr53
spec:
  replicas: 1
  selector:
    matchLabels:
      app: dyndnsr53
  template:
    metadata:
      labels:
        app: dyndnsr53
    spec:
      containers:
      - name: dyndnsr53
        image: quay.io/cldmnky/dyndnsr53:latest
        ports:
        - containerPort: 8080
        env:
        - name: AWS_REGION
          value: "us-east-1"
        - name: AWS_ACCESS_KEY_ID
          valueFrom:
            secretKeyRef:
              name: aws-credentials
              key: access-key-id
        - name: AWS_SECRET_ACCESS_KEY
          valueFrom:
            secretKeyRef:
              name: aws-credentials
              key: secret-access-key
        command: ["/ko-app/dyndnsr53"]
        args: ["serve", "--provider=route53", "--zone-id=Z1234567890ABC"]
```

### OpenShift Deployment

For OpenShift deployments with Kustomize, see the [deployment guide](deploy/README.md):

**Setup AWS credentials** (this file will be gitignored):
```bash
cat > .aws.json << 'EOF'
{
  "AccessKey": {
    "AccessKeyId": "YOUR_AWS_ACCESS_KEY_ID",
    "SecretAccessKey": "YOUR_AWS_SECRET_ACCESS_KEY"
  },
  "Region": "us-east-1",
  "ZoneId": "Z0123456789ABCDEFGH"
}
EOF
```

**Deploy using make targets**:
```bash
# Deploy to development
make deploy-dev

# Deploy to production
make deploy-prod

# Deploy specific tag
make deploy-tag TAG=v1.0.0 ENV=production

# Check deployment status
make deploy-status
```

The deploy script will automatically read the AWS credentials from `.aws.json`, encode them as base64, and inject them into the Kubernetes secret.

## Architecture

### Provider Interface

The application uses a provider pattern for DNS updates:

```go
type Provider interface {
    UpdateRecord(hostname, ip string) error
}
```

Current providers:

- **Route53Provider**: AWS Route53 integration
- **NoneProvider**: Testing/development provider

### Request Flow

1. Client sends DynDNS update request
2. Server validates hostname format
3. Server extracts or detects IP address
4. Provider updates DNS record
5. Server returns appropriate response
6. Request details logged in JSON format

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature-name`
3. Make your changes
4. Run tests: `make verify`
5. Commit your changes: `git commit -am 'Add feature'`
6. Push to the branch: `git push origin feature-name`
7. Submit a pull request

## License

This project is licensed under the terms specified in the LICENSE file.

## Support

For issues and questions, please use the GitHub issue tracker.
