# GitHub Actions Setup

This document explains how to configure the GitHub Actions workflow for automated testing, building, and pushing container images.

## Required Secrets

The GitHub Action workflow requires the following secrets to be configured in your repository:

### 1. Quay.io Registry Secrets

Navigate to your GitHub repository → Settings → Secrets and variables → Actions, then add:

- **`QUAY_USERNAME`**: Your Quay.io username
- **`QUAY_PASSWORD`**: Your Quay.io password or robot token (recommended)

### 2. Setting up Quay.io Robot Account (Recommended)

For better security, use a robot account instead of your personal credentials:

1. Go to [Quay.io](https://quay.io)
2. Navigate to your organization/user settings
3. Create a new Robot Account
4. Grant the robot account `write` permissions to the `dyndnsr53` repository
5. Use the robot account name and token as the GitHub secrets

## Workflow Triggers

The release workflow is triggered when you push a new tag:

```bash
# Create and push a new tag
git tag v1.0.0
git push origin v1.0.0
```

## What the Workflow Does

### 1. Test Job

- Runs on Ubuntu latest
- Sets up Go using the version from `go.mod`
- Downloads dependencies
- Runs unit tests
- Runs tests with race detection
- Runs golangci-lint for code quality

### 2. Build and Push Job

- Runs after tests pass
- Extracts the tag version from the Git ref
- Sets up ko (container builder)
- Logs in to Quay.io registry
- Builds multi-architecture container images (linux/amd64, linux/arm64)
- Pushes images with both the tag version and `latest`
- Generates SBOM (Software Bill of Materials) in SPDX format
- Creates a build summary

### 3. Security Scan Job

- Runs Trivy vulnerability scanner on the built image
- Displays results in GitHub Actions summary
- Uploads scan results as artifacts for download
- Optionally uploads to GitHub Security tab (requires GitHub Advanced Security)

## Image Tags

For a tag `v1.2.3`, the workflow will create and push:

- `quay.io/cldmnky/dyndnsr53:v1.2.3`
- `quay.io/cldmnky/dyndnsr53:latest`

## Build Features

- **Multi-architecture**: Supports both AMD64 and ARM64
- **Distroless base images**: Uses ko's default distroless images for minimal attack surface
- **SBOM generation**: Creates Software Bill of Materials for supply chain security
- **Security scanning**: Automated vulnerability scanning with Trivy
- **Security reports**: Results displayed in GitHub Actions and uploaded as artifacts
- **Build summaries**: Detailed information about each build in GitHub Actions

## Security Scanning

The workflow includes comprehensive security scanning:

- **Trivy Scanner**: Scans container images for known vulnerabilities
- **Results Display**: Security scan results shown in GitHub Actions summary
- **Artifact Upload**: Scan results saved as downloadable artifacts for 30 days
- **Advanced Security**: If GitHub Advanced Security is enabled, results are also uploaded to the Security tab

**Note**: GitHub Advanced Security features (Security tab integration) require a paid GitHub plan for private repositories but are free for public repositories.

## Local Testing

You can test the build process locally using the same tools:

```bash
# Install tools
make tools

# Run tests (same as GitHub Action)
make test
make test-race
make lint

# Build container locally
VERSION=v1.0.0 make container-build-local

# Test the built image
make container-run
```

## Troubleshooting

### Authentication Issues

- Verify your Quay.io credentials are correct
- Check that the robot account has write permissions
- Ensure secrets are properly set in GitHub repository settings

### Build Failures

- Check the Go version compatibility
- Verify all tests pass locally
- Review the GitHub Actions logs for specific error messages

### Registry Push Issues

- Confirm the registry URL is correct (`quay.io/cldmnky`)
- Check repository permissions on Quay.io
- Verify the repository exists and is accessible

### Security Scan Issues

- **"Resource not accessible by integration"**: This indicates GitHub Advanced Security is not enabled
- **Solution**: The workflow will still run security scans and display results in Actions summary
- **Advanced Security**: Enable GitHub Advanced Security for Security tab integration
- **Artifacts**: Security scan results are always available as downloadable artifacts
