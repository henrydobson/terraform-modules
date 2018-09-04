output "public_ip" {
  value = "${aws_eip.default.public_ip}"
}

output "key_name" {
  value = "${var.key_name}"
}

output "gitlab_version" {
  value = "${var.gitlab_version}"
}

output "gitlab_id" {
  value = "${aws_instance.default.id}"
}

output "gitlab_name" {
  value = "${module.labels.name}"
}

output "gitlab_role" {
  value = "${aws_iam_role.default.name}"
}

output "gitlab_instance_profile" {
  value = "${aws_iam_instance_profile.default.name}"
}

output "s3_bucket_name" {
  value = "${aws_s3_bucket.default.*.id}"
}

output "environment" {
  value = "${var.environment}"
}
