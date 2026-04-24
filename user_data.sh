#!/bin/bash 

echo "starting instance bootstrap process" 

# Update OS package
sudo yum update -y

# Install required packages
sudo yum install -y httpd awscli amazon-ssm-agent tar

# Start and enable apache
systemctl enable httpd
systemctl start httpd

# Ensure SSM agent is running
systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent

echo "EC2 bootstrap completed successfully."