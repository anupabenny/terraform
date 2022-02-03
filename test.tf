provider "aws" {
  region = "ap-south-1"
  access_key = AKIAYNPBFMMF5QV2IEW2
  secret_key = 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
}
resource "aws_iam_user" "lb" {
  name = "demo"
  path = "/system"
}
