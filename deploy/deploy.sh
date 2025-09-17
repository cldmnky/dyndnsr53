#!/bin/bash
# deploy.sh - Helper script for OpenShift deployment with custom image tags
#
# Features:
# - Automatic AWS credential injection from .aws.json
# - Kustomize-based deployment with environment overlays
# - Dry-run support for testing
# - Verbose mode for debugging
# - Watch deployment rollout
# - Secure credential handling with template restoration
#
# Usage: ./deploy.sh -e ENVIRONMENT -t TAG [-n NAMESPACE] [-w] [-v] [-d] [-h]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_DIR="${SCRIPT_DIR}"

# Default values
ENVIRONMENT=""
IMAGE_TAG=""
NAMESPACE=""
WATCH="false"
VERBOSE="false"
DRY_RUN="false"

usage() {
    echo "Usage: $0 -e ENVIRONMENT -t TAG [-n NAMESPACE]"
    echo ""
    echo "Options:"
    echo "  -e ENVIRONMENT       Environment to deploy (development|production)"
    echo "  -t TAG               Image tag to deploy (default: latest)"
    echo "  -n NAMESPACE         Override default namespace"
    echo "  -w                   Watch deployment rollout status"
    echo "  -v                   Verbose mode - show generated resources"
    echo "  -d                   Dry run - show what would be deployed without applying"
    echo "  -h                   Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -e development -t latest"
    echo "  $0 -e production -t v1.0.0"
    echo "  $0 -e production -t v1.2.3 -n my-custom-namespace"
}

while getopts "e:t:n:wvdh" opt; do
    case $opt in
        e)
            ENVIRONMENT="$OPTARG"
            ;;
        t)
            IMAGE_TAG="$OPTARG"
            ;;
        n)
            NAMESPACE="$OPTARG"
            ;;
        w)
            WATCH="true"
            ;;
        v)
            VERBOSE="true"
            ;;
        d)
            DRY_RUN="true"
            ;;
        h)
            usage
            exit 0
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            usage
            exit 1
            ;;
    esac
done

# Validate required parameters
if [[ -z "$ENVIRONMENT" ]]; then
    echo "Error: Environment is required (-e)" >&2
    usage
    exit 1
fi

if [[ -z "$IMAGE_TAG" ]]; then
    echo "Error: Image tag is required (-t)" >&2
    usage
    exit 1
fi

# Validate environment
if [[ "$ENVIRONMENT" != "development" && "$ENVIRONMENT" != "production" ]]; then
    echo "Error: Environment must be 'development' or 'production'" >&2
    exit 1
fi

# Set default namespace if not provided
if [[ -z "$NAMESPACE" ]]; then
    case "$ENVIRONMENT" in
        development)
            NAMESPACE="dyndnsr53-dev"
            ;;
        production)
            NAMESPACE="dyndnsr53-prod"
            ;;
    esac
fi

echo "🚀 Deploying dyndnsr53 to OpenShift"
echo "Environment: $ENVIRONMENT"
echo "Image Tag: $IMAGE_TAG"
echo "Namespace: $NAMESPACE"
echo ""

# Check if oc is available
if ! command -v oc &> /dev/null; then
    echo "Error: oc CLI tool is not installed or not in PATH" >&2
    exit 1
fi

# Check if jq is available for parsing AWS credentials
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required for processing AWS credentials" >&2
    echo "Install jq: brew install jq (macOS) or apt-get install jq (Ubuntu)" >&2
    exit 1
fi

# Check if kustomize is available
if ! command -v kustomize &> /dev/null; then
    echo "Warning: kustomize not found, using kubectl kustomize"
    KUSTOMIZE_CMD="kubectl kustomize"
else
    KUSTOMIZE_CMD="kustomize"
fi

# Set overlay directory
OVERLAY_DIR="${DEPLOY_DIR}/overlays/${ENVIRONMENT}"

# Auto-detect OpenShift cluster domain
echo "🔍 Auto-detecting OpenShift cluster domain..."
CLUSTER_DOMAIN=$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}' 2>/dev/null || echo "")
if [[ -n "$CLUSTER_DOMAIN" ]]; then
    echo "� Detected cluster domain: $CLUSTER_DOMAIN"
else
    echo "⚠️  Could not auto-detect cluster domain, using existing route configuration"
    CLUSTER_DOMAIN=""
fi

echo "�📝 Updating image tag to $IMAGE_TAG..."
cd "$OVERLAY_DIR"
$KUSTOMIZE_CMD edit set image "quay.io/cldmnky/dyndnsr53:$IMAGE_TAG"

# Update namespace if provided
if [[ "$NAMESPACE" != "dyndnsr53-dev" && "$NAMESPACE" != "dyndnsr53-prod" ]]; then
    echo "📝 Updating namespace to $NAMESPACE..."
    $KUSTOMIZE_CMD edit set namespace "$NAMESPACE"
fi

# Update route hostname with detected cluster domain
if [[ -n "$CLUSTER_DOMAIN" ]]; then
    echo "📝 Updating route hostname for $ENVIRONMENT environment..."
    
    ROUTE_PATCH_FILE="route-patch.yaml"
    if [[ -f "$ROUTE_PATCH_FILE" ]]; then
        # Determine the hostname based on environment
        case "$ENVIRONMENT" in
            development)
                NEW_HOSTNAME="dyndnsr53-dev.$CLUSTER_DOMAIN"
                ;;
            production)
                NEW_HOSTNAME="dyndnsr53.$CLUSTER_DOMAIN"
                ;;
        esac
        
        echo "📝 Setting route hostname to: $NEW_HOSTNAME"
        
        # Update the hostname in the route patch file
        sed -i.bak "s|host: .*|host: $NEW_HOSTNAME|g" "$ROUTE_PATCH_FILE"
    else
        echo "⚠️  Route patch file not found, skipping hostname update"
    fi
fi

# Process AWS credentials from .aws.json
AWS_JSON="${SCRIPT_DIR}/../.aws.json"
if [[ -f "$AWS_JSON" ]]; then
    echo "🔐 Processing AWS credentials from .aws.json..."
    
    # Extract values from JSON
    AWS_ACCESS_KEY=$(jq -r '.AccessKey.AccessKeyId' "$AWS_JSON")
    AWS_SECRET_KEY=$(jq -r '.AccessKey.SecretAccessKey' "$AWS_JSON")
    AWS_REGION=$(jq -r '.Region' "$AWS_JSON")
    ZONE_ID=$(jq -r '.ZoneId' "$AWS_JSON")
    
    # Encode to base64
    AWS_ACCESS_KEY_B64=$(echo -n "$AWS_ACCESS_KEY" | base64)
    AWS_SECRET_KEY_B64=$(echo -n "$AWS_SECRET_KEY" | base64)
    AWS_REGION_B64=$(echo -n "$AWS_REGION" | base64)
    ZONE_ID_B64=$(echo -n "$ZONE_ID" | base64)
    
    # Create secret.yaml from template
    SECRET_TEMPLATE="${SCRIPT_DIR}/base/secret.yaml.tmpl"
    SECRET_FILE="${SCRIPT_DIR}/base/secret.yaml"
    
    if [[ -f "$SECRET_TEMPLATE" ]]; then
        echo "📝 Generating secret.yaml from template..."
        sed -e "s/_AWS_REGION/$AWS_REGION_B64/g" \
            -e "s/_AWS_ACCESS_KEY/$AWS_ACCESS_KEY_B64/g" \
            -e "s/_AWS_SECRET_ACCESS_KEY/$AWS_SECRET_KEY_B64/g" \
            -e "s/_AWS_R53_ZONE_ID/$ZONE_ID_B64/g" \
            "$SECRET_TEMPLATE" > "$SECRET_FILE"
        
        # Set a trap to restore kustomization, secret template, and route changes
        trap "cd '$OVERLAY_DIR' && git checkout HEAD -- kustomization.yaml route-patch.yaml 2>/dev/null || (mv route-patch.yaml.bak route-patch.yaml 2>/dev/null || true); cp \"$SECRET_TEMPLATE\" \"$SECRET_FILE\" && echo '🔄 Restored secret.yaml template, kustomization, and route changes'" EXIT
    else
        echo "⚠️  Warning: Secret template not found at $SECRET_TEMPLATE"
    fi
else
    echo "⚠️  Warning: .aws.json not found. Using existing secret.yaml"
    echo "    Create .aws.json with AWS credentials for automatic injection"
fi

# Check if namespace exists, create if it doesn't
if [[ "$DRY_RUN" == "false" ]]; then
    if ! oc get namespace "$NAMESPACE" &> /dev/null; then
        echo "📦 Creating namespace $NAMESPACE..."
        oc new-project "$NAMESPACE" || oc create namespace "$NAMESPACE"
    fi
else
    echo "🔍 [DRY RUN] Would create namespace $NAMESPACE if it doesn't exist"
fi

# Deploy the application
if [[ "$DRY_RUN" == "true" ]]; then
    echo "🔍 [DRY RUN] Generated resources that would be deployed:"
    echo "=============================================="
    $KUSTOMIZE_CMD build "$OVERLAY_DIR"
elif [[ "$VERBOSE" == "true" ]]; then
    echo "🔄 Deploying to OpenShift..."
    echo "Generated resources:"
    echo "=============================================="
    $KUSTOMIZE_CMD build "$OVERLAY_DIR"
    echo "=============================================="
    oc apply -k "$OVERLAY_DIR"
else
    echo "🔄 Deploying to OpenShift..."
    oc apply -k "$OVERLAY_DIR"
fi

# Wait for deployment to be ready
if [[ "$DRY_RUN" == "false" ]]; then
    # Determine deployment name with environment prefix
    case "$ENVIRONMENT" in
        development)
            DEPLOYMENT_NAME="dev-dyndnsr53"
            ;;
        production)
            DEPLOYMENT_NAME="prod-dyndnsr53"
            ;;
    esac
    
    if [[ "$WATCH" == "true" ]]; then
        echo "⏳ Watching deployment rollout..."
        oc rollout status deployment/$DEPLOYMENT_NAME -n "$NAMESPACE" --timeout=300s
    else
        echo "⏳ Waiting for deployment to be ready..."
        oc rollout status deployment/$DEPLOYMENT_NAME -n "$NAMESPACE" --timeout=300s
    fi

    # Show deployment status
    echo ""
    echo "✅ Deployment complete! Status:"
    oc get pods,svc,route -n "$NAMESPACE" -l app=dyndnsr53

    # Get the route URL if it exists
    if oc get route $DEPLOYMENT_NAME -n "$NAMESPACE" &> /dev/null; then
        ROUTE_URL=$(oc get route $DEPLOYMENT_NAME -n "$NAMESPACE" -o jsonpath='{.spec.host}')
        echo ""
        echo "🌐 Application URL: https://$ROUTE_URL"
        echo "🔍 Health check: https://$ROUTE_URL/health"
    fi
else
    echo ""
    echo "🔍 [DRY RUN] Deployment would be complete!"
    echo "🔍 [DRY RUN] Would wait for rollout and show status"
fi

echo ""
echo "🎉 Deployment successful!"