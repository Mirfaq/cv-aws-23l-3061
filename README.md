<div align="center">

# 📄 CV Hosting on AWS

**Serving a personal CV page from two independent compute paths — EC2 and Lambda — backed by a single private S3 bucket.**

**Mirfaq Javaid** · Roll Number **23L-3061** · Region **ap-southeast-2**

[![EC2 Site](https://img.shields.io/badge/EC2-Live-blue)](http://3.25.144.199/)
[![Lambda Site](https://img.shields.io/badge/Lambda-Live-orange)](https://ifvctoasoo3q6wcu6p3rzdnfia0drxjq.lambda-url.ap-southeast-2.on.aws/)

</div>

---

## 🔗 Live Addresses

| Path | Address |
|---|---|
| **EC2** | http://3.25.144.199/ |
| **Lambda** | https://ifvctoasoo3q6wcu6p3rzdnfia0drxjq.lambda-url.ap-southeast-2.on.aws/ |

---

## 🏗️ Architecture

```
                         ┌──────────────────────────────┐
                         │      S3 Bucket (private)       │
                         │      cv-23l-3061                │
                         │                                  │
                         │  site/index.html  (<100 KB)      │
                         │  site/style.css                  │
                         │  site/cv.pdf      (<1 MB)         │
                         │                                  │
                         │  Versioning: ON                  │
                         │  Block Public Access: all 4 ON   │
                         │  No bucket policy, no public ACL │
                         └───────────────┬──────────────────┘
                                          │
                   ┌──────────────────────┴───────────────────────┐
                   │                                                │
         s3:GetObject, s3:ListBucket                      s3:GetObject only
         (prefix site/ only)                               (no ListBucket)
         via cv-ec2-role-23l-3061                          via cv-lambda-role-23l-3061
                   │                                                │
     ┌─────────────▼─────────────┐                  ┌───────────────▼────────────────┐
     │   EC2 Instance              │                  │   Lambda Function                │
     │   cv-ec2-23l-3061           │                  │   cv-func-23l-3061                │
     │   Amazon Linux 2023         │                  │   Python 3.13                     │
     │   httpd (Apache)            │                  │   128 MB, 10s timeout              │
     │                              │                  │                                    │
     │   user-data.sh installs      │                  │   Reads BUCKET + PREFIX from        │
     │   httpd + runs sync once     │                  │   environment variables              │
     │                              │                  │                                    │
     │   sync-cv.sh (systemd timer, │                  │   On every request: fetches the      │
     │   every 5 min):               │                  │   object straight from S3, replaces  │
     │   - aws s3 sync site/ → webroot│                 │   {{HOSTED_ON}} for index.html,       │
     │   - replaces {{HOSTED_ON}}    │                  │   sets correct Content-Type,          │
     │     with "EC2 <instance-id>"  │                  │   base64-encodes the PDF              │
     │   - logs to                   │                  │                                    │
     │     /var/log/cv-sync.log      │                  │   Public Function URL (AuthType NONE) │
     └─────────────┬───────────────┘                  └───────────────┬────────────────┘
                   │                                                    │
            Public IPv4 : 80                                   HTTPS Function URL
         (SG: 80 open to all,                                  (resource policy grants
          22 restricted to one /32)                        lambda:InvokeFunctionUrl +
                   │                                        lambda:InvokeFunction)
               ┌───▼───┐                                            │
               │Browser│                                        ┌───▼───┐
               └───────┘                                        │Browser│
                                                                  └───────┘
```

**EC2 path** — A browser requests the public IP on port 80. Apache httpd (installed and started by `user-data.sh`) serves files from `/var/www/html`, kept in sync from the S3 `site/` prefix every 5 minutes by a systemd timer running `sync-cv.sh`, which replaces `{{HOSTED_ON}}` with `EC2 <instance-id>` after each sync.

**Lambda path** — A browser requests the public Function URL over HTTPS. The function reads the requested object straight from S3 on every invocation, replaces `{{HOSTED_ON}}` with `Lambda <function-name>` for the HTML page, and returns the right content type — base64-encoding the PDF for binary-safe delivery.

---

## 📦 Resources

| Resource | Name |
|---|---|
| S3 bucket | `cv-23l-3061` |
| EC2 instance | `cv-ec2-23l-3061` |
| EC2 role | `cv-ec2-role-23l-3061` |
| Lambda function | `cv-func-23l-3061` |
| Lambda role | `cv-lambda-role-23l-3061` |
| Security group | `cv-sg-23l-3061` |
| Region | `ap-southeast-2` |

All resources are tagged `Owner=23l-3061` and `Course=cloud`.

---

## 🔒 Access Denied Proof

From a shell on the EC2 instance (EC2 Instance Connect / SSH), attempting to delete an object using the EC2 role — which only has `GetObject` and `ListBucket` — fails as expected:

```
[ec2-user@ip-172-31-33-171 ~]$ aws s3 rm s3://cv-23l-3061/site/index.html
delete failed: s3://cv-23l-3061/site/index.html An error occurred (AccessDenied) when
calling the DeleteObject operation: User: arn:aws:sts::369086592042:assumed-role/
cv-ec2-role-23l-3061/i-0a46034ba729cf9e1 is not authorized to perform: s3:DeleteObject
on resource: "arn:aws:s3:::cv-23l-3061/site/index.html" because no identity-based
policy allows the s3:DeleteObject action
```

---

## 🪵 Sync Log (last 10 lines)

```
2026-10-24 14:28:22 - sync OK
2026-10-24 14:28:51 - sync OK
2026-10-24 14:33:51 - sync OK
2026-10-24 14:38:52 - sync OK
2026-10-24 14:43:52 - sync OK
2026-10-24 14:48:52 - sync OK
2026-10-24 14:53:53 - sync OK
```

---

## ✍️ Written Answers

**1. Why do the instance and the function use roles instead of access keys? What could go wrong if the keys were in the user data?**

Roles provide temporary, automatically-rotated credentials that AWS manages internally, so no secret ever has to be stored, copied, or protected on disk. If long-lived access keys were placed in the user data instead, they would be readable by anyone who could view the instance's user data from the console/CLI or reach the instance metadata service, and they would never expire on their own — a single leak would grant standing access to the account until someone noticed and manually revoked the key.

**2. Someone pastes the S3 address of index.html into a browser. What do they see, and which setting causes that?**

They see an "Access Denied" XML error instead of the page. This is caused by the bucket's Block Public Access settings (all four enabled) combined with having no public bucket policy or ACL — so S3 refuses any unauthenticated request straight to the object, regardless of the object's existence.

**3. Explain in your own words the permission on the function URL that lets anyone call it. Why is that acceptable for the function but not for the bucket?**

The function's resource-based policy grants `lambda:InvokeFunctionUrl` (and, per AWS's current requirement, `lambda:InvokeFunction` scoped to invocations via the function URL) to principal `*`. This only lets a visitor trigger the function's own code through its URL — it does not expose the function's source, environment variables, or IAM role. It is acceptable here because invoking the function only ever runs the intended, controlled behaviour (serve a public CV page); it would not be acceptable for the bucket because making the bucket itself public would expose every object and its raw contents directly, with no logic or access control in between.

**4. Compare the two paths. What do you pay for when nobody visits the site? What happens if the traffic grows a hundred times?**

With EC2, you pay for the running instance (compute + EBS storage) every hour regardless of traffic, since the server sits up and idle waiting for requests. With Lambda, you pay nothing when idle, because billing is per-invocation and per-millisecond of execution. If traffic grows a hundred times, the EC2 instance will eventually saturate its CPU/network and need to be resized or placed behind an Auto Scaling Group and load balancer, whereas Lambda scales automatically by running more concurrent invocations up to the account's concurrency limit, with no manual intervention needed.

**5. You delete the EC2 instance. What do you lose and what do you still have?**

You lose the running server itself, its local disk (the synced web root, the sync script, and `/var/log/cv-sync.log`), its public IP address, and the instance profile attachment. You still have the S3 bucket and all three CV files untouched (EC2 only ever reads from it), the IAM roles and policies themselves (they are not deleted with the instance), the Lambda function and its Function URL (completely independent of EC2), and the security group definition (until it is separately deleted).

---

## 🐞 Troubleshooting Notes

The Lambda Function URL initially returned `403 Forbidden` even though `AuthType` was `NONE` and the resource policy granted `lambda:InvokeFunctionUrl` to `*`. Root cause: AWS now requires Function URLs to also carry an explicit `lambda:InvokeFunction` permission scoped with the `lambda:InvokedViaFunctionUrl` condition, granted separately:

```bash
aws lambda add-permission --function-name cv-func-23l-3061 \
  --statement-id UrlPolicyInvokeFunction --action lambda:InvokeFunction \
  --principal "*" --invoked-via-function-url
```

After adding this second permission, the URL returned `200 OK` as expected.

---

## 💰 Cost and Hygiene

- Single `t3.micro` instance (free-tier eligible) — no Elastic IP, no NAT gateway, no load balancer.
- Zero-spend budget configured with an email alert before any resources were created.
- Billing page checked before submission.

---

## 📁 Repository Layout

```
README.md
collect-evidence.sh
evidence.txt
site/      index.html, style.css, cv.pdf
ec2/       user-data.sh, sync-cv.sh
lambda/    lambda_function.py
iam/       ec2-trust-policy.json, ec2-permission-policy.json,
           lambda-trust-policy.json, lambda-permission-policy.json
```
