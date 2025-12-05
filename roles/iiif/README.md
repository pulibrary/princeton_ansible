# Role Name: iiif

Deploys [Samvera Labs serverless-iiif](https://github.com/samvera-labs/serverless-iiif) - a IIIF Image API 2.1/3.0 server running on AWS Lambda.

## Requirements

- AWS account with permissions to create/manage:
  - S3 buckets
  - Lambda functions
  - CloudFront distributions
  - IAM roles
  - API Gateway
  - ACM certificates
- AWS CLI configured with appropriate profile in `~/.aws/credentials`
- Docker (for SAM container builds)
- AWS SAM CLI

## Role Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `aws_profile` | AWS CLI profile name | `libimages` |
| `aws_region` | AWS region for Lambda deployment | `us-east-1` |
| `source_bucket_region` | AWS region where source S3 bucket lives | `us-east-2` |
| `source_bucket` | S3 bucket containing source TIFF images | `libimages2` |
| `serverless_path` | Local directory for serverless-iiif clone | `~/serverless` |
| `lambda_dir` | Path to cloned serverless-iiif repo | `{{ serverless_path }}/serverless-iiif` |
| `serverless_iiif_branch` | Git branch to deploy | `main` |
| `iiif_domain` | Domain prefix (results in `<iiif_domain>.princeton.edu`) | `iiif-cloud` |
| `runtime_env` | Environment name for stack naming | `production` |

## Dependencies

None.

## Example Playbook

```yaml
---
- name: Deploy libimages IIIF server
  hosts: localhost
  gather_facts: false
  vars_files:
    - ../group_vars/libimages/main.yml
    - ../group_vars/libimages/vault.yml
  roles:
    - role: roles/iiif
```

## Usage

```bash
# Deploy
ansible-playbook playbooks/libimages.yml

## DNS Configuration

The Lambda deployment creates an ACM certificate that requires DNS validation. During deployment, CloudFormation will generate a CNAME record that must be added to DNS before the stack can complete.

**Steps:**

1. Run the playbook - it will pause waiting for certificate validation
2. In the AWS Console, navigate to **Certificate Manager** in us-east-1
3. Find the pending certificate for `<iiif_domain>.princeton.edu`
4. Copy the CNAME name and value for DNS validation
5. Submit a request to the **OIT DNS group** to add this CNAME record
6. Once DNS propagates, CloudFormation will complete the certificate validation and finish the deployment

**Note:** The deployment will timeout if the DNS record is not added within the CloudFormation timeout period. If this happens, re-run the playbook after DNS is configured.



## AWS Profile Setup

Ensure your `~/.aws/credentials` file has the required profile:
```

```ini
[libimages]
aws_access_key_id = YOUR_ACCESS_KEY
aws_secret_access_key = YOUR_SECRET_KEY
```

## License

MIT
