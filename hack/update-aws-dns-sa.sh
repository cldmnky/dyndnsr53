#!/usr/bin/env bash
# update-aws-dns-sa.sh
# Usage: ./update-aws-dns-sa.sh <ZONE_ID>
# Updates the existing AWS IAM user policy to include the new route53:GetHostedZone permission

set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Usage: $0 <ZONE_ID>"
  echo "Updates the IAM policy for user route53-sa-<ZONE_ID> to include route53:GetHostedZone permission"
  exit 1
fi

ZONE_ID="$1"
USER_NAME="route53-sa-$ZONE_ID"
POLICY_NAME="route53-policy-$ZONE_ID"

echo "Updating IAM policy for user: $USER_NAME"
echo "Policy name: $POLICY_NAME"
echo "Zone ID: $ZONE_ID"
echo

# Check if user exists
if ! aws iam get-user --user-name "$USER_NAME" >/dev/null 2>&1; then
    echo "Error: User $USER_NAME does not exist."
    echo "Run ./create-aws-dns-sa.sh $ZONE_ID to create the user first."
    exit 1
fi

# Check if policy exists
if ! aws iam get-user-policy --user-name "$USER_NAME" --policy-name "$POLICY_NAME" >/dev/null 2>&1; then
    echo "Error: Policy $POLICY_NAME does not exist for user $USER_NAME."
    echo "Run ./create-aws-dns-sa.sh $ZONE_ID to create the policy first."
    exit 1
fi

echo "Current policy:"
aws iam get-user-policy --user-name "$USER_NAME" --policy-name "$POLICY_NAME" --query 'PolicyDocument' --output json
echo

# Create updated policy JSON
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

echo "New policy:"
cat "$tmp_policy" | jq .
echo

read -p "Do you want to update the policy? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Update the policy
    echo "Updating policy..."
    aws iam put-user-policy --user-name "$USER_NAME" --policy-name "$POLICY_NAME" --policy-document file://$tmp_policy
    
    echo "✅ Policy updated successfully!"
    echo
    echo "Updated policy now includes:"
    echo "  - route53:ChangeResourceRecordSets (update DNS records)"
    echo "  - route53:ListResourceRecordSets (list existing records)"
    echo "  - route53:GetHostedZone (get zone info for FQDN validation) ← NEW!"
    echo "  - route53:GetChange (check operation status)"
else
    echo "Policy update cancelled."
fi

# Clean up
rm "$tmp_policy"