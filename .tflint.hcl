config {
  terraform_version = "0.11.8"
  deep_check = true

  ignore_module = {
    "terraform-aws-modules/sqs/aws" = true
    "terraform-aws-modules/iam/aws//modules/iam-user" = true
  }

}
