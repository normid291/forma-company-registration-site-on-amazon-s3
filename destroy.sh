#!/usr/bin/env bash
#
# Tear down the bucket created by deploy.sh.
#
#   BUCKET=forma-static-1234 ./destroy.sh
#
# This deletes every object in the bucket and then the bucket itself.
# S3 refuses to delete a bucket that still holds objects, so the empty step
# has to run first. There is no undo.
#
set -euo pipefail

BUCKET="${BUCKET:?set BUCKET to the bucket you want to remove}"

case "$BUCKET" in
  forma-static-*|regpro-static-*) ;;
  *)
    echo "Refusing to run: $BUCKET does not look like a bucket this repo created." >&2
    echo "Override by editing the guard at the top of destroy.sh if you are sure." >&2
    exit 1
    ;;
esac

echo "This will permanently delete:"
echo "  bucket:  $BUCKET"
echo "  objects: $(aws s3 ls "s3://$BUCKET" --recursive | wc -l)"
echo
read -r -p "Type the bucket name to confirm: " ANSWER
[ "$ANSWER" = "$BUCKET" ] || { echo "Aborted."; exit 1; }

echo "Emptying bucket"
aws s3 rm "s3://$BUCKET" --recursive

echo "Deleting bucket"
aws s3api delete-bucket --bucket "$BUCKET"

echo "Deleted $BUCKET"
