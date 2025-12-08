# Role Name: iiif

Deploys [Samvera Labs serverless-iiif](https://github.com/samvera-labs/serverless-iiif) - a IIIF Image API 2.1/3.0 server running on AWS Lambda. serverless-iiif is an AWS Serverless Application that functions as a IIIF Image API 2.1 & 3.0 compliant server. It has the following 3 components.

  * A simple [lambda funtion](https://aws.amazon.com/lambda/)
  * A [Lambda Function URL](https://docs.aws.amazon.com/lambda/latest/dg/lambda-urls.html) that is used to invoke the IIIF API via HTTPS.
  * A [Lambda Layer](https://docs.aws.amazon.com/lambda/latest/dg/configuration-layers.html) containing all the dependencies for the Lambda Function.

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
```


## Application URL

After successful deployment, the IIIF endpoint will be available at:

**`https://{{ iiif_domain }}.princeton.edu/iiif/2/`**

in the example above:  **`https://libimages-cloud.princeton.edu/iiif/2/`**

To find the endpoint URL and other deployment details in AWS:

1. **CloudFormation Console** → Stacks → `iiif-serverless-production` → Outputs tab
   - `EndpointV2`: IIIF 2.1 API endpoint
   - `EndpointV3`: IIIF 3.0 API endpoint
   - `DistributionId`: CloudFront distribution ID
   - `FunctionUrl`: Direct Lambda function URL (bypasses CloudFront)

2. **CloudFront Console** → Distributions
   - Find distribution with alias `iiif-cloud.princeton.edu`
   - The distribution domain (e.g., `d1234abcd.cloudfront.net`) can be used before DNS is configured

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
