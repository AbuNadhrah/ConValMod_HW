terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "eu-west-1"
  #access_key = "value"
  #secret_key = "value" - create on security tab for the aws user on the portal. make sure to store. also worth noting that this is not the optimal way to use the keys
}

# 1. Create the VPC
resource "aws_vpc" "Main" {
  cidr_block       = "10.0.0.0/16"

  tags = {
    Name = "Main"
  }
}

# 2. Create the internet gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.Main.id

  tags = {
    Name = "Main Internet Gateway"
  }
}

# 3. Configure the routing table
resource "aws_route_table" "route-table" {
  vpc_id = aws_vpc.Main.id

  route {
    cidr_block = "0.0.0.0/0"      #this is the route to the internet since we want the server to be able to reach the internet
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "route to the web"
  }
}

# 4. Create the subnets - 3 different subnets in 3 different zones
  #PFirst Subnet
resource "aws_subnet" "subnet-1" {
  vpc_id     = aws_vpc.Main.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "eu-west-1a"

  tags = {
    Name = "First Subnet"
  }
}
  #Second Subnet
resource "aws_subnet" "subnet-2" {
  vpc_id     = aws_vpc.Main.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "eu-west-1b"

  tags = {
    Name = "Second Subnet"
  }
}
  #Third Subnet
resource "aws_subnet" "subnet-3" {
  vpc_id     = aws_vpc.Main.id
  cidr_block = "10.0.3.0/24"
  availability_zone = "eu-west-1c"

  tags = {
    Name = "Third Subnet"
  }
}

# 5. Associate the subnets to the route table
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet-1.id
  route_table_id = aws_route_table.route-table.id
}

resource "aws_route_table_association" "b" {
    subnet_id = aws_subnet.subnet-2.id
    route_table_id = aws_route_table.route-table.id
}

resource "aws_route_table_association" "c" {
    subnet_id = aws_subnet.subnet-3.id
    route_table_id = aws_route_table.route-table.id
}

# 6. Create the security group to allow ssh, http and https
resource "aws_security_group" "allow_web" {
  name        = "allow_web"
  description = "Allow web inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.Main.id

  tags = {
    Name = "allow_web"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_https_ipv4" {
  security_group_id = aws_security_group.allow_web.id
  description = "HTTPS"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
}

resource "aws_vpc_security_group_ingress_rule" "allow_http_ipv4" {
  security_group_id = aws_security_group.allow_web.id
  description = "HTTP"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_ingress_rule" "allow_ssh_ipv4" {
  security_group_id = aws_security_group.allow_web.id
  description = "ssh"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.allow_web.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv6" {
  security_group_id = aws_security_group.allow_web.id
  cidr_ipv6         = "::/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

# 7. Create network interface (kind of for the instance to have)
resource "aws_network_interface" "server-1-nic" {
  subnet_id       = aws_subnet.subnet-1.id
  private_ips     = ["10.0.1.10"]
  security_groups = [aws_security_group.allow_web.id]
}

# a second network interface for the 2nd server
resource "aws_network_interface" "server-2-nic" {
  subnet_id       = aws_subnet.subnet-2.id
  private_ips     = ["10.0.2.10"]
  security_groups = [aws_security_group.allow_web.id]
}

# a third network interface for the 3rd server
resource "aws_network_interface" "server-3-nic" {
  subnet_id       = aws_subnet.subnet-3.id
  private_ips     = ["10.0.3.10"]
  security_groups = [aws_security_group.allow_web.id]
}

# 8. Assign an elastic ip to the network interface created in 7
resource "aws_eip" "one" {
  domain                    = "vpc"
  network_interface         = aws_network_interface.server-1-nic.id
  associate_with_private_ip = aws_network_interface.server-1-nic.private_ip
  depends_on                = [ aws_internet_gateway.gw,aws_instance.server-1 ]
}

resource "aws_eip" "two" {
  domain                    = "vpc"
  network_interface         = aws_network_interface.server-2-nic.id
  associate_with_private_ip = aws_network_interface.server-2-nic.private_ip
  depends_on                = [ aws_internet_gateway.gw, aws_instance.server-2 ]
}

resource "aws_eip" "three" {
  domain                    = "vpc"
  network_interface         = aws_network_interface.server-3-nic.id
  associate_with_private_ip = aws_network_interface.server-3-nic.private_ip
  depends_on                = [ aws_internet_gateway.gw, aws_instance.server-3]
}

# 9. Create the 3 instances - one after the other

resource "aws_instance" "server-1" {
  ami           = "ami-0a0aadde3561fdc1e"
  instance_type = "t2.micro"
  availability_zone = "eu-west-1a"
  key_name = "main-key"

  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.server-1-nic.id
  }

 

  user_data = <<-EOF
              #!bin/bash
              sudo apt update -y
              sudo apt install apache2 -y
              sudo systemctl start apache2
              sudo bash -c 'echo your very first web server > /var/www/html/index.html'
              EOF

  tags = {
    Name = "first server"
  }
 }

resource "aws_instance" "server-2" {
  ami           = "ami-0a0aadde3561fdc1e"
  instance_type = "t2.micro"
  availability_zone = "eu-west-1b"
  key_name = "main-key"

  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.server-2-nic.id
  }

 

  user_data = <<-EOF
              #!bin/bash
              sudo apt update -y
              sudo apt install apache2 -y
              sudo systemctl start apache2
              sudo bash -c 'echo your very first web server > /var/www/html/index.html'
              EOF

  tags = {
    Name = "second server"
  }
 }

 resource "aws_instance" "server-3" {
  ami           = "ami-0a0aadde3561fdc1e"
  instance_type = "t2.micro"
  availability_zone = "eu-west-1c"
  key_name = "main-key"

  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.server-3-nic.id
  }

 

  user_data = <<-EOF
              #!bin/bash
              sudo apt update -y
              sudo apt install apache2 -y
              sudo systemctl start apache2
              sudo bash -c 'echo your very first web server > /var/www/html/index.html'
              EOF

  tags = {
    Name = "third server"
  }
 }

 # Create a new load balancer

 resource "aws_lb" "main-LB" {
  name               = "main-lb-tf"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.allow_web.id]
  subnets            = [aws_subnet.subnet-1.id, aws_subnet.subnet-2.id, aws_subnet.subnet-3.id]

  enable_deletion_protection = true

  tags = {
    Environment = "main one"
  }
}

resource "aws_lb_target_group" "alb-tg" {
  name     = "main-lb-tg-tf"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.Main.id
}

resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.main-LB.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb-tg.arn
  }
}



# resource "aws_elb" "bar" {
#   name               = "dudu-elb"
#   #availability_zones = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
#   subnets = [aws_subnet.subnet-1.id, aws_subnet.subnet-2.id, aws_subnet.subnet-3.id ]


#   listener {
#     instance_port     = 8000
#     instance_protocol = "http"
#     lb_port           = 80
#     lb_protocol       = "http"
#   }

#   # listener {
#   #   instance_port      = 8000
#   #   instance_protocol  = "http"
#   #   lb_port            = 443
#   #   lb_protocol        = "https"
#   # }

#   health_check {
#     healthy_threshold   = 2
#     unhealthy_threshold = 2
#     timeout             = 3
#     target              = "HTTP:8000/"
#     interval            = 30
#   }

#   instances                   = [aws_instance.server-1.id, aws_instance.server-2.id, aws_instance.server-3.id]
#   cross_zone_load_balancing   = true
#   idle_timeout                = 400
#   connection_draining         = true
#   connection_draining_timeout = 400

#   tags = {
#     Name = "dudu-elb"
#   }
# }

resource "local_file" "for-ansible" {
  content = join("\n", [aws_instance.server-1.public_ip, aws_instance.server-2.public_ip, aws_instance.server-3.public_ip])
  filename = "host-inventory"
}

#Configure the Route53 resource
# aws record hosted zone

resource "aws_route53_zone" "hosted-zone" {
  name = "ariyo-olaniyan.xyz"
}

#Create record set in route 53
resource "aws_route53_record" "site-domain" {
  zone_id = aws_route53_zone.hosted-zone.zone_id
  name    = "terraform-test.ariyo-olaniyan.xyz"
  type    = "A"

  alias {
    name                   = aws_lb.main-LB.dns_name
    zone_id                = aws_lb.main-LB.zone_id
    evaluate_target_health = true
  }
}