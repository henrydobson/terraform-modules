variable "subnet_id" {
  type = "string"

  description = "Target subnet id"
}

variable "key_name" {
  type = "string"

  description = "SSH key pair name"
}

variable "fqdn" {
  type = "string"

  default     = "gitlab.example.com"
  description = "The intended FQDN for the GitLab instance"
}

variable "create_bucket" {
  type = "string"

  default     = "true"
  description = "Boolean: Create S3 bucket"
}

variable "s3_bucket" {
  type = "string"

  default     = "gitlab.example.com"
  description = "The S3 bucket containing GitLab backups"
}

variable "restore_enabled" {
  type = "string"

  default     = "true"
  description = "Boolean: Restore GitLab from S3 backup"
}

variable "backup_enabled" {
  type = "string"

  default     = "true"
  description = "Boolean: Enable GitLab backups to S3"
}

variable "environment" {
  type = "string"

  default     = "development"
  description = "GitLab environment"
}

variable "volume_size" {
  type = "string"

  default     = "80"
  description = "The volume size of the root disk device"
}

variable "gitlab_version" {
  type = "string"

  default     = "10.7.1"
  description = "GitLab CE version"
}

variable "instance_type" {
  type = "string"

  default     = "c4.large"
  description = "AWS instance type"
}

variable "monitoring" {
  type = "string"

  default     = "true"
  description = "Boolean: Enable CloudWatch instance monitoring"
}

variable "security_group_ids" {
  type = "list"

  description = "List of security group ids to attach to the instance"
}
