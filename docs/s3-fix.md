# AWS S3 Bucket Policy Fix

## Problem
You're getting "AccessDenied" errors when trying to view images because your AWS IAM user credentials don't have the right S3 permissions.

## Solution
Go to your AWS Console and update your S3 bucket policy:

### Option 1: Make Bucket Publicly Readable (Simplest)
Add this bucket policy to `atlas-media` bucket:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PublicReadGetObject",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::atlas-media/*"
    }
  ]
}
```

### Option 2: Grant IAM User Full Access (More Secure)
Update your IAM user policy to include:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::atlas-media",
        "arn:aws:s3:::atlas-media/*"
      ]
    }
  ]
}
```

## Temporary Fix
I've added error handling so the app shows placeholder images when S3 fails instead of breaking. But you still need to fix the AWS permissions to actually display your images.

## How to Apply
1. Go to AWS Console → S3 → atlas-media bucket
2. Click "Permissions" tab
3. Scroll to "Bucket policy"
4. Paste the JSON above
5. Click "Save changes"

After applying the policy, redeploy your app on Railway and images should work.
