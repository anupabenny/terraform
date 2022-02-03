provider "aws" {
  region = "ap-south-1"
}
resource "aws_iam_user" "lb" {
  name = "demo"
  path = "/"
}
