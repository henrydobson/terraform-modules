module "labels" {
  source     = "git::https://github.com/cloudposse/terraform-null-label.git?ref=master"
  namespace  = "common-services"
  stage      = "${var.environment}"
  name       = "gitlab"
  attributes = ["public"]
  delimiter  = "-"
  tags       = "${map("S3", "${data.aws_s3_bucket.selected.id}")}"
}

// Find ami

data "aws_ami" "default" {
  most_recent = true

  filter {
    name   = "name"
    values = ["GitLab EE ${var.gitlab_version}*"]
  }

  filter {
    name   = "description"
    values = ["Official GitLab EE ${var.gitlab_version}*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  owners = ["855262394183"]
}

// This bucket is for GitLab backup

data "aws_s3_bucket" "selected" {
  bucket = "${var.s3_bucket}"
}

data "aws_iam_policy_document" "default" {
  statement {
    sid = "1"

    actions = [
      "s3:ListAllMyBuckets",
      "s3:GetBucketLocation",
    ]

    resources = [
      "arn:aws:s3:::*",
    ]
  }

  statement {
    actions = [
      "s3:ListBucket",
    ]

    resources = [
      "${data.aws_s3_bucket.selected.arn}",
    ]
  }

  statement {
    actions = [
      "s3:*",
    ]

    resources = [
      "${data.aws_s3_bucket.selected.arn}",
      "${data.aws_s3_bucket.selected.arn}/*",
    ]
  }
}

data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "default" {
  name = "${module.labels.id}"
  path = "/system/"

  assume_role_policy = "${data.aws_iam_policy_document.assume.json}"
}

resource "aws_iam_role_policy" "default" {
  name = "${module.labels.id}"
  role = "${aws_iam_role.default.id}"

  policy = "${data.aws_iam_policy_document.default.json}"
}

resource "aws_iam_instance_profile" "default" {
  name = "${module.labels.id}"
  role = "${aws_iam_role.default.name}"
}

data "template_file" "default" {
  template = "${file("${path.module}/data/gitlab_user_data.tpl")}"

  vars {
    gitlab_version  = "${var.gitlab_version}"
    fqdn            = "${var.fqdn}"
    region          = "${data.aws_s3_bucket.selected.region}"
    s3_bucket       = "${data.aws_s3_bucket.selected.id}"
    restore_enabled = "${var.restore_enabled}"
    backup_enabled  = "${var.backup_enabled}"
  }
}

resource "aws_instance" "default" {
  ami                    = "${data.aws_ami.default.id}"
  instance_type          = "${var.instance_type}"
  monitoring             = "${var.monitoring}"
  key_name               = "${var.key_name}"
  subnet_id              = "${var.subnet_id}"
  vpc_security_group_ids = "${var.security_group_ids}"
  iam_instance_profile   = "${aws_iam_instance_profile.default.id}"
  user_data              = "${data.template_file.default.rendered}"

  root_block_device {
    volume_type           = "gp2"
    volume_size           = "${var.volume_size}"
    delete_on_termination = false
  }

  tags {
    Name         = "${module.labels.id}"
    Environement = "${module.labels.stage}"
    Attributes   = "${module.labels.attributes}"
    S3           = "${data.aws_s3_bucket.selected.id}"
  }

  volume_tags {
    Name         = "${module.labels.id}"
    Environement = "${module.labels.stage}"
  }
}

resource "aws_eip" "default" {
  vpc      = true
  instance = "${aws_instance.default.id}"
}

resource "random_id" "default" {
  byte_length = 3
}

resource "aws_s3_bucket" "default" {
  count  = "${var.create_bucket == "true" ? 1 : 0}"
  bucket = "${module.labels.id}-${random_id.default.dec}"
  acl    = "private"

  lifecycle_rule {
    id      = "backups"
    enabled = true
    prefix  = "backups/"

    tags {
      "rule"      = "backups"
      "autoclean" = "true"
    }

    transition {
      days          = 30
      storage_class = "GLACIER"
    }

    expiration {
      days = 60
    }
  }
}
