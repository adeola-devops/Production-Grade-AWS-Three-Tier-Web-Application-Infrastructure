variable "aws_region" {
  description = "AWS region"
  default        = "us-east-1"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "webapp"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24"]
  validation {
    condition     = length(var.public_subnet_cidrs) == 2
    error_message = "public_subnet_cidrs must contain exactly 2 CIDR blocks."
  }
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.3.0/24", "10.0.4.0/24"]
  validation {
    condition     = length(var.private_subnet_cidrs) == 2
    error_message = "private_subnet_cidrs must contain exactly 2 CIDR blocks."
  }
}

variable "https_port" {
  type        = number
  description = "HTTPS port"
  default     = 443
}

variable "http_port" {
  type        = number
  description = "HTTP port"
  default     = 80
}

variable "allow_all_cidr" {
  description = "Allowed IP address"
  type        = string
  default     = "0.0.0.0/0"
}

variable "instance_type" {
  type    = string
  default = "t2.micro"
}

variable "acm_certificate_arn" {
  type = string
}

variable "dns" {
  type = string
}

variable "www_dns" {
  type = string
}

variable "ssm" {
  type    = string
  default = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

variable "aws_account_id" {
  description = "AWS account ID"
  type        = string
}

variable "environment" {
  type    = string
  default = "dev"
}