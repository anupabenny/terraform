provider "aws" {
  region = "ap-south-1"
  access_key = data.aws_ssm.parameter.access_key
  secret_key = data.aws_ssm.parameter.access_key
}
data "aws_ssm_paramater" "access_key" {
  name = "access_key"
}
data "aws_ssm_paramater" "secret_key" {
  name = "secret_key"
}
resource "aws_iam_user" "lb" {
  name = "demo"
  path = "/"
}
