provider "aws" {
  access_key = "${var.aws_access_key}"
  secret_key = "${var.aws_secret_key}"
  region     = "${var.aws_region}"
}

module "ssh_key_pair" {
  source                = "git::https://github.com/cloudposse/terraform-aws-key-pair.git?ref=master"
  namespace             = "utility"
  stage                 = "testing"
  name                  = "key"
  ssh_public_key_path   = "secrets"
  generate_ssh_key      = "true"
  private_key_extension = ".pem"
  public_key_extension  = ".pub"
  chmod_command         = "chmod 600 %v"
}

module "gitlab" {
  source = "../../"

  environment     = "test"
  gitlab_version  = "10.7.1"
  subnet_id       = "subnet-xxxxxx"
  volume_size     = "80"
  key_name        = "${module.ssh_key_pair.key_name}"
  backup_enabled  = "true"
  restore_enabled = "true"
  s3_bucket       = "example-backup-bucket"
  create_bucket   = "false"

  security_group_ids = ["sg-xxxxxxx"]
}
