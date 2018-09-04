# GitLab Terraform Module for AWS

## Description

Terraform module which creates GitLab instances on AWS, optionally enable restore from GitLab backup, optionally enabled backups on the GitLab instance and optionally create a S3 bucket for object storage.

These types of data are supported:

* [Template File](https://www.terraform.io/docs/providers/aws/d/template_file.html)
* [AWS AMI](https://www.terraform.io/docs/providers/aws/d/ami.html)
* [S3 Bucket](https://www.terraform.io/docs/providers/aws/d/s3_bucket.html)
* [IAM Policy Document](https://www.terraform.io/docs/providers/aws/d/iam_policy_document.html)

These types of resources are supported:

* [IAM Role](https://www.terraform.io/docs/providers/aws/r/iam_role.html)
* [IAM Role Policy](https://www.terraform.io/docs/providers/aws/r/iam_policy.html)
* [IAM Instance Profile](https://www.terraform.io/docs/providers/aws/r/iam_instance_profile.html)
* [Instance](https://www.terraform.io/docs/providers/aws/r/instance.html)
* [Elastic IP](https://www.terraform.io/docs/providers/aws/r/eip.html) 
* [S3 Bucket](https://www.terraform.io/docs/providers/aws/r/s3_bucket.html)

These types of modules are supported:

* [null-label](https://www.terraform.io/docs/providers/aws/r/iam_instance_profile.html)

## Usage

```
module "gitlab" {
  source = "../../modules/terraform-aws-gitlab"

  environment        = "production"
  gitlab_version     = "10.7.1"
  subnet_id          = "subnet-xxxxxx"
  volume_size        = "200"
  key_name           = "my-key"
  backup_enabled     = "true"
  restore_enabled    = "true"
  s3_bucket          = "backup-bucket"
  create_bucket      = "false"
  security_group_ids = [ "sg-xxxxxxx" ]
}
```

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-----:|:-----:|
| backup_enabled | Boolean: Enable GitLab backups to S3 | string | `true` | no |
| create_bucket | Boolean: Create S3 bucket | string | `true` | no |
| environment | GitLab environment | string | `development` | no |
| fqdn | The intended FQDN for the GitLab instance | string | `gitlab.example.com` | no |
| gitlab_version | GitLab CE version | string | `10.7.1` | no |
| instance_type | AWS instance type | string | `c4.large` | no |
| key_name | SSH key pair name | string | - | yes |
| monitoring | Boolean: Enable CloudWatch instance monitoring | string | `true` | no |
| restore_enabled | Boolean: Restore GitLab from S3 backup | string | `true` | no |
| s3_bucket | The S3 bucket containing GitLab backups | string | `gitlab.example.com` | no |
| security_group_ids | List of security group ids to attach to the instance | list | - | yes |
| subnet_id | Target subnet id | string | - | yes |
| volume_size | The volume size of the root disk device | string | `80` | no |

## Outputs

| Name | Description |
|------|-------------|
| environment |  |
| gitlab_id |  |
| gitlab_instance_profile |  |
| gitlab_name |  |
| gitlab_role |  |
| gitlab_version |  |
| key_name |  |
| public_ip |  |
| s3_bucket_name |  |

<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->

## Conditional Creation

Sometimes you may not want to perform one of these actions:

* Restore for lastest GitLab backup.
* Enable GitLab backups to S3.
* Create a new S3 bucket for the GitLab instance.

```
module "gitlab" {
  # ... omitted

  backup_enabled     = "false"
  restore_enabled    = "false"
  create_bucket      = "true"
  
  # ... omitted

}

```

This example would create a new GitLab CE instance and S3 bucket.

## Downgrade

GitLab only build EE amis so we consume that and downgrade.

* [Downgrade](https://docs.gitlab.com/ce/raketasks/backup_restore.html#restore-for-omnibus-installations)

## Backups

S3 backups must be configured in `/etc/gitlab/gitlab.rb`.

* [Backups](https://docs.gitlab.com/omnibus/settings/backups.html)
* [S3](https://docs.gitlab.com/ce/raketasks/backup_restore.html#using-amazon-s3)

`/etc/gitlab/gitlab.rb`
```
gitlab_rails['backup_upload_connection'] = {
  'provider' => 'AWS',
  'region' => 'eu-west-2',
  'use_iam_profile' => true
}
gitlab_rails['backup_upload_remote_directory'] = '<FQDN>'
```

`/etc/systemd/system/backup_gitlab.service`
```
[Unit]
Description=Backup Gitlab

[Service]
Type=simple
User=root
ExecStart=/usr/bin/gitlab-rake --trace gitlab:backup:create SKIP=artifacts,registry
ExecStartPost=/opt/concrete/gitlab_configuration_backup.sh
```

`/etc/systemd/system/backup_gitlab.timer`
```
[Unit]
Description=Backup Gitlab

[Timer]
Unit=backup_gitlab.service
OnUnitActiveSec=1d
OnBootSec=10min

[Install]
WantedBy=timers.target
```

`/opt/concrete/gitlab_configuration_backup.sh`
```
#!/bin/bash
gitlab_tag=$$(date "+etc-gitlab-%s.tar")
ssh_tag=$$(date "+etc-ssh-%s.tar")
umask 0077; tar -cf /var/backups/gitlab/configuration/$${gitlab_tag} -C / etc/gitlab
umask 0077; tar -cf /var/backups/gitlab/configuration/$${ssh_tag} -C / etc/ssh
aws s3 sync --quiet --region ${region} --storage-class STANDARD_IA /var/opt/gitlab/backups/configuration/ s3://${s3_bucket}/${fqdn}
if [[ $? == 0 ]]; then
  find /var/opt/gitlab/backups/configuration/* -type f -delete
fi
```

### S3 Object Structure

Configuration backups location `s3://${bucket_name}/${fqdn}/`<br>
GitLab backups `s3://${bucket_name}/`

## Restore from Backup

* [Restore from Backup](https://docs.gitlab.com/ce/raketasks/backup_restore.html#restore-for-omnibus-installations)

```
# Retrieve latest /etc/ssh
etcssh=$$(aws s3api list-objects --bucket ${s3_bucket} --prefix ${fqdn}/etc-ssh --query 'reverse(sort_by(Contents,&LastModified))[0].Key' --output text)

aws s3api get-object --bucket ${s3_bucket} --key $${etcssh} $${etcssh/${fqdn}\//}
tar -xf $${etcssh/${fqdn}\//}

# Retrieve latest /etc/gitlab
etcgitlab=$$(aws s3api list-objects --bucket ${s3_bucket} --prefix ${fqdn}/etc-gitlab --query 'reverse(sort_by(Contents,&LastModified))[0].Key' --output text)

aws s3api get-object --bucket ${s3_bucket} --key $${etcgitlab} $${etcgitlab/${fqdn}\//}
tar -xf $${etcgitlab/${fqdn}\//}

# Retrieve latest backup
backup=$$(aws s3api list-objects --bucket ${s3_bucket} --query 'reverse(sort_by(Contents,&LastModified))[0].Key' --output text)

aws s3api get-object --bucket ${s3_bucket} --key $${backup} /var/opt/gitlab/backups/$${backup}

gitlab-ctl stop unicorn
gitlab-ctl stop sidekiq

gitlab-rake gitlab:backup:restore force=yes
cp -R etc/gitlab /etc/
cp -R etc/ssh /etc/

gitlab-ctl restart
gitlab-rake gitlab:check SANITIZE=true
gitlab-ctl reconfigure
```

## Terraform Version

Terraform v0.11.7 or higher required.

## Examples

* [GitLab CE with restore from backup and backups enabled](https://gitlab.retailcloud.net/infrastructure/terraform-aws-concrete/tree/master/modules/terraform-aws-gitlab/examples/restore-and-backups-enabled)

## Terraform usage

```
brew install terraform
terraform init
terraform workspace new my-gitlab-workspace-production
terraform plan out.tfplan
terraform apply out.tfplan
```

## Authors

Henry Dobson

## License

Apache 2 Licensed. See LICENSE for full details.
