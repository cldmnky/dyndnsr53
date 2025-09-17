#!/usr/bin/env bash
# create-aws-dns-sa.sh
# Usage: ./create-aws-dns-sa.sh <ZONE_ID>
# Creates an AWS IAM user with permissions to manage Route53 records in the given zone.

set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Usage: $0 <ZONE_ID>"
  exit 1
fi

ZONE_ID="$1"
USER_NAME="route53-sa-$ZONE_ID"
POLICY_NAME="route53-policy-$ZONE_ID"

# Create IAM user
echo "Creating IAM user: $USER_NAME"
aws iam create-user --user-name "$USER_NAME"

# Create inline policy JSON
# Permissions required:
# - route53:ChangeResourceRecordSets: Update DNS records
# - route53:ListResourceRecordSets: List existing records (optional)
# - route53:GetHostedZone: Get zone information for FQDN validation
# - route53:GetChange: Check operation status
tmp_policy=$(mktemp)
cat > "$tmp_policy" <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "route53:ChangeResourceRecordSets",
        "route53:ListResourceRecordSets",
        "route53:GetHostedZone"
      ],
      "Resource": "arn:aws:route53:::hostedzone/$ZONE_ID"
    },
    {
      "Effect": "Allow",
      "Action": [
        "route53:GetChange"
      ],
      "Resource": "*"
    }
  ]
}
EOF

# Attach policy to user
echo "Attaching policy to user: $POLICY_NAME"
aws iam put-user-policy --user-name "$USER_NAME" --policy-name "$POLICY_NAME" --policy-document file://$tmp_policy

# Create access key
echo "Creating access key for user: $USER_NAME"
aws iam create-access-key --user-name "$USER_NAME"

# Clean up
rm "$tmp_policy"
