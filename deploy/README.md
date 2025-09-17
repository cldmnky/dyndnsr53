# OpenShift Deployment for dyndnsr53

This directory contains Kustomize-based OpenShift deployments for the dyndnsr53 DynDNS server.

## Structure

```text
deploy/
├── base/                    # Base Kubernetes resources
│   ├── kustomization.yaml  # Base kustomization
│   ├── deployment.yaml     # Main deployment
│   ├── service.yaml        # Service definition
│   ├── route.yaml          # OpenShift route
│   └── secret.yaml         # Secret template
└── overlays/               # Environment-specific overlays
    ├── development/        # Development environment
    │   ├── kustomization.yaml
    │   ├── deployment-patch.yaml
    │   └── route-patch.yaml
    └── production/         # Production environment
        ├── kustomization.yaml
        ├── deployment-patch.yaml
        └── route-patch.yaml
```

## Quick Start

### Prerequisites

- OpenShift cluster access with `oc` CLI
- `jq` for JSON processing  
- (Optional) `kustomize` CLI

### AWS Credentials Setup

Create an AWS credentials file in the project root (this file will be gitignored):

```bash
cat > ../.aws.json << 'EOF'
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

### Helper Scripts

For convenience, use the provided helper scripts:

```bash
# Deploy with specific tag
./deploy.sh -e production -t v1.0.0

# Deploy to development
./deploy.sh -e development -t latest

# Clean up deployment
./cleanup.sh -e development

# Clean up and delete namespace
./cleanup.sh -e production -d

# Validate credential setup before deployment
./validate-credentials.sh
```
./cleanup.sh -e production -d
```

The deploy script will automatically:
- Read AWS credentials from `.aws.json`
- Base64 encode the credentials
- Inject them into the Kubernetes secret
- Restore the template after deployment to prevent credential leakage

### Manual Deployment

### 1. Prerequisites

- OpenShift cluster access
- `oc` CLI tool installed
- `kustomize` or `kubectl` with kustomize support
- `jq` for JSON processing

### 2. Configure AWS Credentials

Create an AWS credentials file in the project root (see [AWS Credentials Setup](#aws-credentials-setup) above).

### 3. Update Route Hostname

Edit the route hostnames in:

- `base/route.yaml` - Base hostname
- `overlays/development/route-patch.yaml` - Development hostname  
- `overlays/production/route-patch.yaml` - Production hostname

Replace `apps.cluster.example.com` with your OpenShift cluster's route domain.

## Deployment

### Development Environment

Deploy to development with the `none` provider for testing:

```bash
# Create namespace
oc new-project dyndnsr53-dev

# Deploy using kustomize
oc apply -k deploy/overlays/development/

# Check deployment status
oc get pods -n dyndnsr53-dev
oc get route -n dyndnsr53-dev
```

### Production Environment

Deploy to production with Route53 provider:

```bash
# Create namespace
oc new-project dyndnsr53-prod

# Deploy using kustomize
oc apply -k deploy/overlays/production/

# Check deployment status
oc get pods -n dyndnsr53-prod
oc get route -n dyndnsr53-prod
```

### Custom Tag Deployment

To deploy with a specific image tag:

```bash
# Clone the overlay
cp -r deploy/overlays/production deploy/overlays/my-version

# Edit kustomization.yaml to set your desired tag
cd deploy/overlays/my-version
vim kustomization.yaml  # Change newTag to your desired version

# Deploy
oc apply -k .
```

## Configuration

### Environment Variables

The deployment uses these environment variables (from secret):

- `AWS_REGION` - AWS region for Route53
- `AWS_ACCESS_KEY_ID` - AWS access key
- `AWS_SECRET_ACCESS_KEY` - AWS secret key  
- `ZONE_ID` - Route53 hosted zone ID

### Provider Configuration

- **Development**: Uses `none` provider (no actual DNS updates)
- **Production**: Uses `route53` provider (updates AWS Route53)

### Resource Limits

- **Development**: Lower resource requests/limits for cost efficiency
- **Production**: Higher limits with multiple replicas and anti-affinity

## Security Features

- **Non-root container**: Runs as user 65534
- **Read-only filesystem**: Security context prevents privilege escalation
- **Security profiles**: Uses RuntimeDefault seccomp profile
- **Minimal privileges**: Drops all capabilities
- **Service account**: Dedicated service account with minimal permissions

## Health Checks

The deployment includes:

- **Liveness probe**: `/health` endpoint, checked every 30s
- **Readiness probe**: `/health` endpoint, checked every 10s

## Networking

- **Service**: ClusterIP service on port 8080
- **Route**: HTTPS-enabled OpenShift route with edge termination
- **Rate limiting**: Production includes rate limiting annotations

## Monitoring

### Check Application Logs

```bash
# Development
oc logs -f deployment/dev-dyndnsr53 -n dyndnsr53-dev

# Production
oc logs -f deployment/prod-dyndnsr53 -n dyndnsr53-prod
```

### Test the Service

```bash
# Get the route URL
ROUTE_URL=$(oc get route dyndnsr53 -o jsonpath='{.spec.host}')

# Test health endpoint
curl https://$ROUTE_URL/health

# Test DynDNS update (requires authentication)
curl -u "username:password" \
  "https://$ROUTE_URL/nic/update?hostname=test.example.com&myip=1.2.3.4"
```

## Customization

### Adding Authentication

To add DynDNS authentication, uncomment and configure the auth credentials in `base/secret.yaml`:

```yaml
data:
  auth-username: dXNlcm5hbWU=  # base64 encoded username
  auth-password: cGFzc3dvcmQ=  # base64 encoded password
```

### Scaling

Adjust replicas in the overlay's `deployment-patch.yaml`:

```yaml
spec:
  replicas: 3  # Increase for higher availability
```

### Custom Arguments

Modify the container args in `deployment-patch.yaml` for different configurations:

```yaml
args:
- serve
- --provider=route53
- --zone-id=$(ZONE_ID)
- --listen=:8080
- --auth-file=/etc/dyndns/auth  # Example: file-based auth
```

## Troubleshooting

### Common Issues

1. **Image pull errors**: Verify the image tag exists in the registry
2. **Route not accessible**: Check OpenShift router and route configuration  
3. **AWS permissions**: Verify IAM permissions for Route53 operations
4. **Secret encoding**: Ensure base64 encoding is correct (no newlines)

### Debug Commands

```bash
# Check pod status
oc describe pod -l app=dyndnsr53

# Check service endpoints
oc get endpoints dyndnsr53

# Check route status
oc describe route dyndnsr53

# View container logs
oc logs -l app=dyndnsr53 --tail=100
```

## Cleanup

```bash
# Remove development deployment
oc delete -k deploy/overlays/development/
oc delete project dyndnsr53-dev

# Remove production deployment
oc delete -k deploy/overlays/production/
oc delete project dyndnsr53-prod
```
