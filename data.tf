data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name" # Note: case sensitive
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# IAM policy (Referencing existing bucket)
data "aws_iam_policy_document" "s3_policy" { # Permission rules (JSON)
  # description = "Allow EC2 to read artifacts from S3"
  statement {
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["arn:aws:s3:::webapp-s3-bucket-artifacts/*"]
  }
}