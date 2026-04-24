output "vpc_id" {
  description = "VPC ID for the deployed environment"
  value       = aws_vpc.webapp_vpc.id
}

output "nat_gateway_eip_az1" {
  description = "Public Elastic IP for NAT Gateway in Availability Zone 1"
  value       = aws_eip.webapp_eip_public1_subnet.public_ip
}

output "nat_gateway_eip_az2" {
  description = "Public Elastic IP for NAT Gateway in Availability Zone 2"
  value       = aws_eip.webapp_eip_public2_subnet.public_ip
}

output "public_subnet_ids" {
  description = "IDs of public subnets used by ALB and NAT Gateways"
  value = [
    aws_subnet.webapp_public1_subnet.id,
    aws_subnet.webapp_public2_subnet.id
  ]
}

output "private_subnet_ids" {
  description = "IDs of private subnets"
  value = [
    aws_subnet.webapp_private1_subnet.id,
    aws_subnet.webapp_private2_subnet.id
  ]
}

output "alb_dns_name" {
  description = "Public DNS name of the Application Load Balancer"
  value       = aws_lb.webapp_alb.dns_name
}

output "alb_target_group_arn" {
  description = "ALB target group ARN"
  value       = aws_lb_target_group.webapp_alb_tg.arn
}

output "asg_name" {
  description = "Auto Scaling Group name"
  value       = aws_autoscaling_group.webapp_asg_instance.name
}

output "launch_template_id" {
  description = "Launch template ID used by ASG"
  value       = aws_launch_template.webapp_instance_lp.id
}

output "asg_subnets" {
  description = "Subnets used by the Auto Scaling Group"
  value       = aws_autoscaling_group.webapp_asg_instance.vpc_zone_identifier
}

output "route53_zone_id" {
  description = "Route 53 Hosted Zone ID"
  value       = aws_route53_zone.webapp_route53_zone.zone_id
}

output "route53_domain_name" {
  description = "Domain name managed by Route 53"
  value       = aws_route53_zone.webapp_route53_zone.name
}

output "route53_record_fqdn" {
  description = "Fully qualified domain name pointing to the ALB"
  value       = aws_route53_record.webapp_root.fqdn
}

output "route53_name_servers" {
  description = "Route 53 authoritative name servers"
  value       = join(", ", aws_route53_zone.webapp_route53_zone.name_servers)
}