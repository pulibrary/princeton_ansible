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
