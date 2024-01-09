# Define the provider and the regions
provider "aws" {
region = "eu-west-1"
}

provider "aws" {
alias  = "eu-central-1"
region = "eu-central-1"
}

# Define the variables for the environments and the availability zones
variable "environments" {
type = list(string)
default = ["dev", "prod"]
}

variable "availability_zones" {
type = map(list(string))
default = {
"eu-west-1" = ["eu-west-1a", "eu-west-1b"]
"eu-central-1" = ["eu-central-1a", "eu-central-1b"]
}
}

# Define the module for creating a VPC
module "vpc" {
source  = "terraform-aws-modules/vpc/aws"
version = "3.4.0"

name = "vpc-${var.environment}"
cidr = "10.0.0.0/16"

azs             = var.availability_zones[var.region]
private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

enable_nat_gateway = true
single_nat_gateway = true
enable_vpn_gateway = false

tags = {
Environment = var.environment
}
}

# Define the module for creating an EC2 instance
module "ec2" {
source  = "terraform-aws-modules/ec2-instance/aws"
version = "3.2.0"

name           = "ec2-${var.environment}"
instance_count = 1

ami                         = "ami-0ce71448843cb18a1" # Ubuntu 20.04 LTS
instance_type               = "t2.micro" # Free tier
key_name                    = "my-key"
vpc_security_group_ids      = [module.vpc.default_security_group_id]
subnet_id                   = module.vpc.public_subnets[0]
associate_public_ip_address = true

tags = {
Environment = var.environment
}

# Define the user data script that creates an ansible, docker container
user_data = <<-EOF
#!/bin/bash
# Install docker
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg-agent software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io
# Install ansible
sudo apt-get install -y ansible
# Pull the ansible docker image
sudo docker pull ansible/ansible:ubuntu2004
# Run the ansible docker container
sudo docker run -d --name ansible -v /etc/ansible:/etc/ansible ansible/ansible:ubuntu2004
EOF
}

# Define the output for the EC2 instance
output "ec2_instance_id" {
value = module.ec2.id
}

# Define the output for the VPC id
output "vpc_id" {
value = module.vpc.vpc_id
}
