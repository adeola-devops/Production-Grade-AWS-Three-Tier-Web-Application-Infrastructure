# Route 53
resource "aws_route53_zone" "webapp_route53_zone" { # Route53 hosted zone
  name = var.dns
}

resource "aws_route53_record" "webapp_root" {            # Route53 records
  zone_id = aws_route53_zone.webapp_route53_zone.zone_id # Route53 hosted zone ID (Where the signboard is located)
  name    = ""
  type    = "A"
  alias {                                               # “CNAME records can’t be used at the root domain because DNS standards forbid it.
    name                   = aws_lb.webapp_alb.dns_name # The terraform resource name for alb should be used
    zone_id                = aws_lb.webapp_alb.zone_id  # AWS resource’s zone ID (ALB’s zone) Where the road actually leads
    evaluate_target_health = true
  }
}

# subdomain
resource "aws_route53_record" "webapp_www" {
  zone_id = aws_route53_zone.webapp_route53_zone.zone_id
  name    = "www" # Relative name to the hosted zone
  type    = "A"
  alias {
    name                   = aws_lb.webapp_alb.dns_name
    zone_id                = aws_lb.webapp_alb.zone_id
    evaluate_target_health = true
  }
}

# vpc
resource "aws_vpc" "webapp_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "${var.project_name}-vpc"
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}


# subnets inside the vpc

# public1 subnet
resource "aws_subnet" "webapp_public1_subnet" {
  vpc_id                  = aws_vpc.webapp_vpc.id
  cidr_block              = var.public_subnet_cidrs[0]
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true
  tags = {
    Name = "${var.project_name}-public1-subnet"
  }
}

# public2 subnet
resource "aws_subnet" "webapp_public2_subnet" {
  vpc_id                  = aws_vpc.webapp_vpc.id
  cidr_block              = var.public_subnet_cidrs[1]
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true
  tags = {
    Name = "${var.project_name}-public2-subnet"
  }
}

# private1 subnet
resource "aws_subnet" "webapp_private1_subnet" {
  vpc_id                  = aws_vpc.webapp_vpc.id
  cidr_block              = var.private_subnet_cidrs[0]
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = false
  tags = {
    Name = "${var.project_name}-private1-subnet"
  }
}

# private2 subnet
resource "aws_subnet" "webapp_private2_subnet" {
  vpc_id                  = aws_vpc.webapp_vpc.id
  cidr_block              = var.private_subnet_cidrs[1]
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = false
  tags = {
    Name = "${var.project_name}-private2-subnet"
  }
}

# vpc internet gateway
resource "aws_internet_gateway" "webapp_igw" {
  vpc_id = aws_vpc.webapp_vpc.id
  tags = {
    Name = "${var.project_name}-igw"
  }
}

# elastic IP (public1)
resource "aws_eip" "webapp_eip_public1_subnet" {
  domain = "vpc"
}

# elastic IP (public2)
resource "aws_eip" "webapp_eip_public2_subnet" {
  domain = "vpc"
}

# NAT Gateway (public1)
resource "aws_nat_gateway" "webapp_public1_nat" {
  allocation_id = aws_eip.webapp_eip_public1_subnet.id
  subnet_id     = aws_subnet.webapp_public1_subnet.id
  depends_on    = [aws_internet_gateway.webapp_igw]
  tags = {
    Name = "webapp-public1-nat"
  }
}

# NAT Gateway (public2)
resource "aws_nat_gateway" "webapp_public2_nat" {
  allocation_id = aws_eip.webapp_eip_public2_subnet.id
  subnet_id     = aws_subnet.webapp_public2_subnet.id
  depends_on    = [aws_internet_gateway.webapp_igw]
  tags = {
    Name = "webapp-public2-nat"
  }
}

# route table for public subnets

# Public route table
resource "aws_route_table" "webapp_public_rt" {
  vpc_id = aws_vpc.webapp_vpc.id
  route {
    cidr_block = var.allow_all_cidr
    gateway_id = aws_internet_gateway.webapp_igw.id
  }
  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

# Private route table
resource "aws_route_table" "webapp_private1_rt" {
  vpc_id = aws_vpc.webapp_vpc.id
  route {
    cidr_block     = var.allow_all_cidr
    nat_gateway_id = aws_nat_gateway.webapp_public1_nat.id
  }
  tags = {
    Name = "${var.project_name}-private1-rt"
  }
}

resource "aws_route_table" "webapp_private2_rt" {
  vpc_id = aws_vpc.webapp_vpc.id
  route {
    cidr_block     = var.allow_all_cidr
    nat_gateway_id = aws_nat_gateway.webapp_public2_nat.id
  }
  tags = {
    Name = "${var.project_name}-private2-rt"
  }
}

# route table association

# public subnet
resource "aws_route_table_association" "public_subnet_assoc" {
  count = 2
  subnet_id = element(
    [aws_subnet.webapp_public1_subnet.id, aws_subnet.webapp_public2_subnet.id],
  count.index)
  route_table_id = aws_route_table.webapp_public_rt.id
}

# private1 subnet
resource "aws_route_table_association" "private1_subnet_assoc" {
  subnet_id      = aws_subnet.webapp_private1_subnet.id
  route_table_id = aws_route_table.webapp_private1_rt.id
}

resource "aws_route_table_association" "private2_subnet_assoc" {
  subnet_id      = aws_subnet.webapp_private2_subnet.id
  route_table_id = aws_route_table.webapp_private2_rt.id
}

#SECURITY

#Security Group for Application Load Balancer (HTTP/HTTPS access)
resource "aws_security_group" "webapp_alb_sg" {
  name        = "${var.project_name}-alb-sg"
  description = "Allow HTTP and HTTPS" #TLS is Transport layer Security
  vpc_id      = aws_vpc.webapp_vpc.id
  tags = {
    Name = "${var.project_name}-alb-sg"
  }
}

# Defining ALB security rules
# decide the traffic allow

resource "aws_vpc_security_group_ingress_rule" "webapp_alb_sg_inbound_http" {
  security_group_id = aws_security_group.webapp_alb_sg.id
  cidr_ipv4         = var.allow_all_cidr
  from_port         = var.http_port
  ip_protocol       = "tcp"
  to_port           = var.http_port
}

resource "aws_vpc_security_group_ingress_rule" "webapp_alb_sg_inbound_tls" {
  security_group_id = aws_security_group.webapp_alb_sg.id
  cidr_ipv4         = var.allow_all_cidr
  from_port         = var.https_port
  ip_protocol       = "tcp" # tcp (Transmission Control Protocol): It’s a reliable way computers send data
  to_port           = var.https_port
}

resource "aws_vpc_security_group_egress_rule" "webapp_alb_sg_outbound" {
  security_group_id            = aws_security_group.webapp_alb_sg.id
  referenced_security_group_id = aws_security_group.webapp_instance_sg.id
  from_port                    = var.http_port
  ip_protocol                  = "tcp"
  to_port                      = var.http_port
}

# Security Group for Instances
resource "aws_security_group" "webapp_instance_sg" {
  name   = "${var.project_name}-instance-sg"
  vpc_id = aws_vpc.webapp_vpc.id
  tags = {
    Name = "${var.project_name}-instance-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "webapp_alb_sg_outbound_receiver" { # traffic from ALB
  security_group_id            = aws_security_group.webapp_instance_sg.id
  referenced_security_group_id = aws_security_group.webapp_alb_sg.id
  from_port                    = var.http_port
  ip_protocol                  = "tcp"
  to_port                      = var.http_port
}

resource "aws_vpc_security_group_egress_rule" "webapp_instance_https_only" {
  security_group_id = aws_security_group.webapp_instance_sg.id
  from_port         = var.https_port
  ip_protocol       = "tcp"
  to_port           = var.https_port
  cidr_ipv4         = var.allow_all_cidr
}

# Traffic always hits the ALB first. The listener is simply the rule set the ALB uses to handle that traffic.

# Application load balancer
resource "aws_lb" "webapp_alb" {
  name               = "${var.project_name}-alb"
  internal           = false # The ALB is internet-facing (public)
  load_balancer_type = "application"
  security_groups    = [aws_security_group.webapp_alb_sg.id]
  subnets            = [aws_subnet.webapp_public1_subnet.id, aws_subnet.webapp_public2_subnet.id]
  tags = {
    Name = "${var.project_name}-alb"
  }
}

# target group: where traffic goes, it chooses a healthy EC2
resource "aws_lb_target_group" "webapp_alb_tg" {
  name        = "${var.project_name}-alb-tg"
  target_type = "instance"
  port        = var.http_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.webapp_vpc.id
  health_check { # health_check is a configuration define in Terraform
    enabled             = true
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 30
    path                = "/"
    timeout             = 6
    matcher             = "200-399"
  }
  deregistration_delay = 30
  tags = {
    Name = "${var.project_name}-tg"
  }
}

# Note: A listerner is a configuration ON the ALB, not a seperate component from the ALB
# listerner: determine how the ALB knows what to do with traffic that already arrived

# Redirect Action (HTTP)
resource "aws_lb_listener" "webapp_http_listener" {
  load_balancer_arn = aws_lb.webapp_alb.arn
  port              = var.http_port
  protocol          = "HTTP"
  default_action {
    type = "redirect"
    redirect {
      port        = var.https_port
      protocol    = "HTTPS"
      status_code = "HTTP_302"
    }
  }
}

# Redirect www → root                                       # Note: Security groups cannot read HTTP headers but ALB listeners CAN
resource "aws_lb_listener_rule" "www_to_root_redirect" {
  listener_arn = aws_lb_listener.webapp_http_listener.arn # Attach this rule to the HTTP listener of ALB
  priority     = 10                                       # higher number, evaluated later

  condition {
    host_header {
      values = [var.www_dns]
    }
  }

  action {
    type = "redirect"
    redirect {
      host        = var.dns
      protocol    = "HTTPS"
      port        = var.https_port
      status_code = "HTTP_301" # SEO-safe
    }
  }
}

# Forward Action (HTTPS)

resource "aws_lb_listener" "webapp_https_listener" {
  load_balancer_arn = aws_lb.webapp_alb.arn
  port              = var.https_port
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06" # aws elbv2 describe-ssl-policies --query "SslPolicies[].Name" --output table
  certificate_arn   = var.acm_certificate_arn               # Gotten from AWS Certificate Manager (ACM)
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.webapp_alb_tg.arn
  }
}

# Launch Template
resource "aws_launch_template" "webapp_instance_lp" {
  name_prefix   = "${var.project_name}-instance-lp"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type
  user_data     = filebase64("${path.module}/user_data.sh")
  metadata_options {
    http_tokens = "required"
  }

  iam_instance_profile { # role attached to instance
    name = aws_iam_instance_profile.webapp_instance_profile.name
  }

  network_interfaces { # Network configuration
    delete_on_termination       = true
    associate_public_ip_address = false
    security_groups             = [aws_security_group.webapp_instance_sg.id]
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "${var.project_name}-instance"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

#Auto Scaling Group
resource "aws_autoscaling_group" "webapp_asg_instance" {
  name             = "${var.project_name}-webapp-asg-instance"
  min_size         = 2
  max_size         = 4
  desired_capacity = 2
  vpc_zone_identifier = [
    aws_subnet.webapp_private1_subnet.id,
    aws_subnet.webapp_private2_subnet.id
  ]

  target_group_arns         = [aws_lb_target_group.webapp_alb_tg.arn] # register instance to target group
  health_check_type         = "ELB"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.webapp_instance_lp.id
    version = aws_launch_template.webapp_instance_lp.latest_version
  }

  lifecycle {
    create_before_destroy = true
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
      instance_warmup        = 300
    }
  }


  tag {
    key                 = "Name"
    value               = "${var.project_name}-instance"
    propagate_at_launch = true
  }
}

# Autoscaling Policy (SCALE UP POLICY)
resource "aws_autoscaling_policy" "webapp_scale_up" {
  name                   = "${var.project_name}-webapp_scale_up"
  autoscaling_group_name = aws_autoscaling_group.webapp_asg_instance.name
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  scaling_adjustment     = 1
}

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "${var.project_name}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 60

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.webapp_asg_instance.name
  }

  alarm_actions = [aws_autoscaling_policy.webapp_scale_up.arn]
}

# Autoscaling Policy (SCALE DOWN POLICY)
resource "aws_autoscaling_policy" "webapp_scale_down" {
  name                   = "${var.project_name}-webapp_scale-down"
  autoscaling_group_name = aws_autoscaling_group.webapp_asg_instance.name
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  scaling_adjustment     = -1
}

resource "aws_cloudwatch_metric_alarm" "cpu_low" {
  alarm_name          = "${var.project_name}-cpu-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 25

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.webapp_asg_instance.name
  }

  alarm_actions = [aws_autoscaling_policy.webapp_scale_down.arn]
}

# IAM role for instance
resource "aws_iam_role" "webapp_role" {
  name = "${var.project_name}-instance-readonl"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      },
    ]
  })

  tags = {
    tag-key = "webapp-instance-iam-readonly-access"
  }
}

# Attach AWS managed policies for SSM + S3 (private1)
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.webapp_role.name
  policy_arn = var.ssm
}

# IAM s3 policy  attached to instance
resource "aws_iam_policy" "webapp_s3_policy" { # A reusable policy object
  name   = "webapp-s3-policy"
  policy = data.aws_iam_policy_document.s3_policy.json
}

# Attach policy to role (Give the role permission to read s3)
resource "aws_iam_role_policy_attachment" "s3_access_policy" {
  role       = aws_iam_role.webapp_role.name
  policy_arn = aws_iam_policy.webapp_s3_policy.arn
}

resource "aws_iam_instance_profile" "webapp_instance_profile" {
  name = "${var.project_name}-instance-profile"
  role = aws_iam_role.webapp_role.name
}

# to get instance information
#  aws ssm describe-instance-information --region us-east-1

# to start session via ssm
#aws ssm start-session --target $INSTANCE-ID