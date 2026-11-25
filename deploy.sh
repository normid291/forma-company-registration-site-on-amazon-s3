#!/usr/bin/env bash
#
# Deploy the static site to an S3 website endpoint.
#
#   BUCKET=forma-static-1234 AWS_REGION=us-east-1 ./deploy.sh
#
# Environment:
#   BUCKET       Bucket name. Defaults to forma-static-<epoch>.
#   AWS_REGION   Target region. Defaults to us-east-1.
#   PROJECT      Project tag. Defaults to forma-static-site.
#   ENVIRONMENT  Environment tag. Defaults to demo.
#
set -euo pipefail

REGION="${AWS_REGION:-us-east-1}"
BUCKET="${BUCKET:-forma-static-$(date +%s)}"
PROJECT="${PROJECT:-forma-static-site}"
ENVIRONMENT="${ENVIRONMENT:-demo}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

say() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }

say "Target bucket: $BUCKET in $REGION"

# 1. Bucket. Every region except us-east-1 needs an explicit location constraint.
if aws s3api head-bucket --bucket "$BUCKET" 2>/dev/null; then
  say "Bucket already exists, reusing it"
else
  say "Creating bucket"
  if [ "$REGION" = "us-east-1" ]; then
    aws s3api create-bucket --bucket "$BUCKET" --region "$REGION" >/dev/null
  else
    aws s3api create-bucket \
      --bucket "$BUCKET" \
      --region "$REGION" \
      --create-bucket-configuration "LocationConstraint=$REGION" >/dev/null
  fi
fi

say "Tagging bucket"
aws s3api put-bucket-tagging \
  --bucket "$BUCKET" \
  --tagging "TagSet=[{Key=Project,Value=$PROJECT},{Key=ManagedBy,Value=opencode},{Key=Environment,Value=$ENVIRONMENT}]"

# 2. A website endpoint cannot serve a private bucket, so public access is required.
say "Allowing public access"
aws s3api delete-public-access-block --bucket "$BUCKET" >/dev/null

say "Enabling static website hosting"
aws s3api put-bucket-website \
  --bucket "$BUCKET" \
  --website-configuration \
  '{"IndexDocument":{"Suffix":"index.html"},"ErrorDocument":{"Key":"index.html"}}'

say "Attaching public read policy"
POLICY=$(cat <<JSON
{
  "Version": "2012-10-17",
  "Statement": [{
    "Sid": "PublicReadForWebsiteHosting",
    "Effect": "Allow",
    "Principal": "*",
    "Action": "s3:GetObject",
    "Resource": "arn:aws:s3:::$BUCKET/*"
  }]
}
JSON
)
aws s3api put-bucket-policy --bucket "$BUCKET" --policy "$POLICY"

# 3. Upload. HTML revalidates every load, assets are cached for a year.
say "Uploading HTML"
aws s3 cp "$ROOT/index.html" "s3://$BUCKET/index.html" \
  --content-type "text/html; charset=utf-8" \
  --cache-control "public, max-age=0, must-revalidate"
aws s3 cp "$ROOT/contact.html" "s3://$BUCKET/contact.html" \
  --content-type "text/html; charset=utf-8" \
  --cache-control "public, max-age=0, must-revalidate"

say "Uploading CSS and JavaScript"
aws s3 cp "$ROOT/css/styles.css" "s3://$BUCKET/css/styles.css" \
  --content-type "text/css; charset=utf-8" \
  --cache-control "public, max-age=31536000, immutable"
aws s3 cp "$ROOT/js/main.js" "s3://$BUCKET/js/main.js" \
  --content-type "application/javascript; charset=utf-8" \
  --cache-control "public, max-age=31536000, immutable"

say "Done"
echo "Website URL: http://$BUCKET.s3-website-$REGION.amazonaws.com"
echo
echo "To tear this down: BUCKET=$BUCKET ./destroy.sh"
