#!/bin/bash
# cleanup.sh - Helper script for cleaning up OpenShift deployments

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default values
ENVIRONMENT=""
NAMESPACE=""
DELETE_NAMESPACE="false"

usage() {
    echo "Usage: $0 -e ENVIRONMENT [-n NAMESPACE] [-d]"
    echo ""
    echo "Options:"
    echo "  -e ENVIRONMENT       Environment to clean up (development|production|all)"
    echo "  -n NAMESPACE         Override default namespace"
    echo "  -d                   Delete the namespace as well"
    echo "  -h                   Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -e development"
    echo "  $0 -e production -d"
    echo "  $0 -e all"
    echo "  $0 -e development -n my-custom-namespace"
}

while getopts "e:n:dh" opt; do
    case $opt in
        e)
            ENVIRONMENT="$OPTARG"
            ;;
        n)
            NAMESPACE="$OPTARG"
            ;;
        d)
            DELETE_NAMESPACE="true"
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

# Validate environment
if [[ "$ENVIRONMENT" != "development" && "$ENVIRONMENT" != "production" && "$ENVIRONMENT" != "all" ]]; then
    echo "Error: Environment must be 'development', 'production', or 'all'" >&2
    exit 1
fi

# Check if oc is available
if ! command -v oc &> /dev/null; then
    echo "Error: oc CLI tool is not installed or not in PATH" >&2
    exit 1
fi

cleanup_environment() {
    local env="$1"
    local ns="$2"
    
    echo "🧹 Cleaning up $env environment..."
    
    # Set default namespace if not provided
    if [[ -z "$ns" ]]; then
        case "$env" in
            development)
                ns="dyndnsr53-dev"
                ;;
            production)
                ns="dyndnsr53-prod"
                ;;
        esac
    fi
    
    echo "Namespace: $ns"
    
    # Check if namespace exists
    if ! oc get namespace "$ns" &> /dev/null; then
        echo "⚠️  Namespace $ns does not exist, skipping..."
        return 0
    fi
    
    # Delete the kustomization resources
    overlay_path="${SCRIPT_DIR}/overlays/${env}"
    if [[ -d "$overlay_path" ]]; then
        echo "🗑️  Deleting resources from $env overlay..."
        oc delete -k "$overlay_path" --ignore-not-found=true
    else
        echo "⚠️  Overlay directory $overlay_path not found, deleting resources by label..."
        oc delete all,secret,route,sa -n "$ns" -l app=dyndnsr53 --ignore-not-found=true
    fi
    
    # Delete namespace if requested
    if [[ "$DELETE_NAMESPACE" == "true" ]]; then
        echo "🗑️  Deleting namespace $ns..."
        oc delete namespace "$ns" --ignore-not-found=true
    fi
    
    echo "✅ Cleanup complete for $env environment"
}

echo "🚀 Starting OpenShift cleanup"
echo ""

# Clean up based on environment selection
case "$ENVIRONMENT" in
    all)
        cleanup_environment "development" ""
        echo ""
        cleanup_environment "production" ""
        ;;
    development|production)
        cleanup_environment "$ENVIRONMENT" "$NAMESPACE"
        ;;
esac

echo ""
echo "🎉 Cleanup complete!"

# Restore secret template if it exists
SECRET_TEMPLATE="${SCRIPT_DIR}/base/secret.yaml.tmpl"
SECRET_FILE="${SCRIPT_DIR}/base/secret.yaml"

if [[ -f "$SECRET_TEMPLATE" ]]; then
    echo "🔄 Restoring secret.yaml template..."
    cp "$SECRET_TEMPLATE" "$SECRET_FILE"
fi

# Show remaining resources if any
echo ""
echo "📊 Remaining dyndnsr53 resources across all namespaces:"
if oc get all,secret,route,sa --all-namespaces -l app=dyndnsr53 2>/dev/null | grep -q "dyndnsr53"; then
    oc get all,secret,route,sa --all-namespaces -l app=dyndnsr53
else
    echo "No dyndnsr53 resources found."
fi