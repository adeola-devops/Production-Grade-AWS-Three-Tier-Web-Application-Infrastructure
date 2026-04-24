terraform {
  backend "s3" {
    bucket  = "webapp-terraform-tfstate-bucket"
    key     = "main/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}