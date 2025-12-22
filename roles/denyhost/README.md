# Role Name

Creates or refreshes our firewall deny list.

To add one or more IPs, ranges, etc. to the deny list:

- edit vars/main.yml
- within the banned_ranges variable, add a new entry like this:

banned_ranges:

- name: tencent cloud
  ip_range:
  - 1.12.0.0/15
  - 1.14.0.0/16
- name: other problematic actor
  ip_range:
  - x.xx.x.x/xx
  - y.yy.y.y/yy

## Requirements

  - PanOS configured to Read from an [External DynamicList](https://docs.paloaltonetworks.com/network-security/security-policy/administration/objects/external-dynamic-lists/configure-the-firewall-to-access-an-external-dynamic-list). In our instance the URI is an S3 Bucket [https://nginx-deny-list.s3.us-east-1.amazonaws.com/denylist.txt](https://nginx-deny-list.s3.us-east-1.amazonaws.com/denylist.txt)
  - The S3 Bucket Allows Public Access (see [the AWS docs](https://docs.aws.amazon.com/AmazonS3/latest/userguide/managing-acls.html)) with the following policy:
      ```yaml
        {
        "Version": "2012-10-17",
        "Statement": [
            {
              "Sid": "PublicReadGetObject",
              "Effect": "Allow",
              "Principal": "*",
              "Action": "s3:GetObject",
              "Resource": "arn:aws:s3:::nginx-deny-list/*"
            }
          ]
        }
        ```

  - The vaulted credentials are allowed to modify the denylist

## Example Playbook

Including an example of how to use your role (for instance, with variables passed in as parameters) is always nice for users too:

    - hosts: servers
      roles:
         - { role: username.rolename, x: 42 }

## License

BSD

## Author Information

An optional section for the role authors to include contact information, or a website (HTML is not allowed).
