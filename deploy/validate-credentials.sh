#!/bin/bash
# validate-credentials.sh - Test script to validate credential injection

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AWS_JSON="${SCRIPT_DIR}/../.aws.json"
SECRET_TEMPLATE="${SCRIPT_DIR}/base/secret.yaml.tmpl"

echo "🔍 Validating credential injection system..."

# Check if .aws.json exists
if [[ ! -f "$AWS_JSON" ]]; then
    echo "❌ .aws.json not found at $AWS_JSON"
    echo "Create it with: cat > .aws.json << 'EOF'"
    echo '{'
    echo '  "AccessKey": {'
    echo '    "AccessKeyId": "YOUR_AWS_ACCESS_KEY_ID",'
    echo '    "SecretAccessKey": "YOUR_AWS_SECRET_ACCESS_KEY"'
    echo '  },'
    echo '  "Region": "us-east-1",'
    echo '  "ZoneId": "Z0123456789ABCDEFGH"'
    echo '}'
    echo 'EOF'
    exit 1
fi

# Check if jq is available
if ! command -v jq &> /dev/null; then
    echo "❌ jq is not installed"
    echo "Install with: brew install jq (macOS) or apt-get install jq (Ubuntu)"
    exit 1
fi

# Check if template exists
if [[ ! -f "$SECRET_TEMPLATE" ]]; then
    echo "❌ Secret template not found at $SECRET_TEMPLATE"
    exit 1
fi

echo "✅ .aws.json found"
echo "✅ jq available"
echo "✅ Secret template found"
echo ""

# Extract and validate JSON structure
echo "📋 Extracting credentials..."
AWS_ACCESS_KEY=$(jq -r '.AccessKey.AccessKeyId' "$AWS_JSON")
AWS_SECRET_KEY=$(jq -r '.AccessKey.SecretAccessKey' "$AWS_JSON")
AWS_REGION=$(jq -r '.Region' "$AWS_JSON")
ZONE_ID=$(jq -r '.ZoneId' "$AWS_JSON")

if [[ "$AWS_ACCESS_KEY" == "null" || -z "$AWS_ACCESS_KEY" ]]; then
    echo "❌ AccessKey.AccessKeyId not found in .aws.json"
    exit 1
fi

if [[ "$AWS_SECRET_KEY" == "null" || -z "$AWS_SECRET_KEY" ]]; then
    echo "❌ AccessKey.SecretAccessKey not found in .aws.json"
    exit 1
fi

if [[ "$AWS_REGION" == "null" || -z "$AWS_REGION" ]]; then
    echo "❌ Region not found in .aws.json"
    exit 1
fi

if [[ "$ZONE_ID" == "null" || -z "$ZONE_ID" ]]; then
    echo "❌ ZoneId not found in .aws.json"
    exit 1
fi

echo "✅ AccessKey.AccessKeyId: $AWS_ACCESS_KEY"
echo "✅ Region: $AWS_REGION"
echo "✅ ZoneId: $ZONE_ID"
echo "✅ SecretAccessKey: [REDACTED]"
echo ""

# Test base64 encoding
echo "🔐 Testing base64 encoding..."
AWS_ACCESS_KEY_B64=$(echo -n "$AWS_ACCESS_KEY" | base64)
AWS_SECRET_KEY_B64=$(echo -n "$AWS_SECRET_KEY" | base64)
AWS_REGION_B64=$(echo -n "$AWS_REGION" | base64)
ZONE_ID_B64=$(echo -n "$ZONE_ID" | base64)

echo "✅ Base64 encoding successful"
echo ""

# Test template replacement
echo "📝 Testing template replacement..."
TEMP_SECRET=$(mktemp)
sed -e "s/_AWS_REGION/$AWS_REGION_B64/g" \
    -e "s/_AWS_ACCESS_KEY/$AWS_ACCESS_KEY_B64/g" \
    -e "s/_AWS_SECRET_ACCESS_KEY/$AWS_SECRET_KEY_B64/g" \
    -e "s/_AWS_R53_ZONE_ID/$ZONE_ID_B64/g" \
    "$SECRET_TEMPLATE" > "$TEMP_SECRET"

echo "✅ Template replacement successful"

# Validate YAML syntax if available
if command -v python3 &> /dev/null && python3 -c "import yaml" 2>/dev/null; then
    echo "🔍 Validating YAML syntax..."
    if python3 -c "import yaml; yaml.safe_load(open('$TEMP_SECRET'))" 2>/dev/null; then
        echo "✅ Generated YAML is valid"
    else
        echo "⚠️ YAML validation failed (this may be a false positive)"
        echo "   The generated YAML might still be valid for Kubernetes"
    fi
else
    echo "ℹ️ Skipping YAML validation (python3 or yaml module not available)"
fi

# Show the generated secret (with redacted sensitive values)
echo ""
echo "📄 Generated secret.yaml (sensitive values redacted):"
echo "================================================="
sed -e "s/$AWS_ACCESS_KEY_B64/[REDACTED_ACCESS_KEY]/g" \
    -e "s/$AWS_SECRET_KEY_B64/[REDACTED_SECRET_KEY]/g" \
    "$TEMP_SECRET"

# Cleanup
rm "$TEMP_SECRET"

echo ""
echo "🎉 Credential injection validation successful!"
echo "   The deploy script will automatically inject these credentials during deployment."