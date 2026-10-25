#!/bin/bash

export PATH="$PATH:/c/Program Files/Amazon/AWSCLIV2"

if [ "$#" -ne 3 ]; then
  echo "Usage: $0 <bucket-name> <ec2-address> <lambda-address>"
  exit 1
fi

BUCKET="$1"
EC2_ADDR="$2"
LAMBDA_ADDR="$3"
OUT="evidence.txt"
EC2_ROLE="cv-ec2-role-23l-3061"
LAMBDA_ROLE="cv-lambda-role-23l-3061"
SG_NAME="cv-sg-23l-3061"
INSTANCE_ID="i-0a46034ba729cf9e1"
LAMBDA_FUNC="cv-func-23l-3061"

> "$OUT"

echo "== caller ==" >> "$OUT"
aws sts get-caller-identity >> "$OUT" 2>&1
echo "" >> "$OUT"

echo "== public-access ==" >> "$OUT"
aws s3api get-public-access-block --bucket "$BUCKET" >> "$OUT" 2>&1
echo "" >> "$OUT"

echo "== versioning ==" >> "$OUT"
aws s3api get-bucket-versioning --bucket "$BUCKET" >> "$OUT" 2>&1
echo "" >> "$OUT"

echo "== objects ==" >> "$OUT"
aws s3 ls "s3://${BUCKET}/site/" >> "$OUT" 2>&1
echo "" >> "$OUT"

echo "== ec2-policy ==" >> "$OUT"
aws iam get-role-policy --role-name "$EC2_ROLE" --policy-name cv-ec2-s3-access >> "$OUT" 2>&1
echo "" >> "$OUT"

echo "== lambda-policy ==" >> "$OUT"
aws iam list-attached-role-policies --role-name "$LAMBDA_ROLE" >> "$OUT" 2>&1
aws iam get-role-policy --role-name "$LAMBDA_ROLE" --policy-name cv-lambda-s3-access >> "$OUT" 2>&1
echo "" >> "$OUT"

echo "== security-group ==" >> "$OUT"
aws ec2 describe-security-groups --filters "Name=group-name,Values=${SG_NAME}" --query "SecurityGroups[0].IpPermissions" >> "$OUT" 2>&1
echo "" >> "$OUT"

echo "== instance ==" >> "$OUT"
aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --query "Reservations[0].Instances[0].[InstanceType,MetadataOptions.HttpTokens,IamInstanceProfile.Arn]" >> "$OUT" 2>&1
echo "" >> "$OUT"

echo "== endpoints ==" >> "$OUT"
echo "EC2 address:" >> "$OUT"
curl -s -o /dev/null -w "HTTP Status: %{http_code}, Content-Type: %{content_type}\n" "http://${EC2_ADDR}/" >> "$OUT" 2>&1
echo "Lambda address:" >> "$OUT"
curl -s -o /dev/null -w "HTTP Status: %{http_code}, Content-Type: %{content_type}\n" "https://${LAMBDA_ADDR}/" >> "$OUT" 2>&1
echo "Direct S3 address:" >> "$OUT"
curl -s -o /dev/null -w "HTTP Status: %{http_code}, Content-Type: %{content_type}\n" "https://${BUCKET}.s3.ap-southeast-2.amazonaws.com/site/index.html" >> "$OUT" 2>&1
echo "" >> "$OUT"

echo "== lambda-logs ==" >> "$OUT"
aws logs tail "/aws/lambda/${LAMBDA_FUNC}" --since 3h >> "$OUT" 2>&1
echo "" >> "$OUT"

echo "== log-retention ==" >> "$OUT"
aws logs describe-log-groups --log-group-name-prefix "/aws/lambda/${LAMBDA_FUNC}" --query "logGroups[0].retentionInDays" >> "$OUT" 2>&1
echo "" >> "$OUT"

echo "DONE"
