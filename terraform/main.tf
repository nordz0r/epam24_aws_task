# AWS Task
# 20220220 by NorD
# It is necessary to set the accounting data in the variables
# export AWS_ACCESS_KEY_ID="ACCESS_KEY"
# export AWS_SECRET_ACCESS_KEY="ACCESS_KEY_PASSWORD"


# Region settings
provider "aws" {
  region = "eu-west-2"
}

# Get my IP
module "myip" {
  source  = "4ops/myip/http"
  version = "1.0.0"
}

# AZ
data "aws_availability_zones" "available" { }
resource "aws_default_subnet" "default_az1" {
  availability_zone = data.aws_availability_zones.available.names[0]
}

resource "aws_default_subnet" "default_az2" {
  availability_zone = data.aws_availability_zones.available.names[1]
}

# Last ami
data "aws_ami" "last_amazon"{
  owners = ["137112412989"]
  most_recent = true
  filter{
    name = "name"
    values = ["amzn2-ami-kernel-5.10-hvm-*-x86_64-gp2"]
  }
}


# Create VPC
resource "aws_vpc" "wp_vcp" {
  cidr_block = "192.168.0.0/16"
  enable_dns_hostnames = true
  tags = {
    Name    = "WP_VPC"
    Owner   = "Andrei Shcheglov"
    Project = "AWS_Task"
  }
}

# Create Subnets
resource "aws_subnet" "subnet-1" {
  vpc_id            = aws_vpc.wp_vcp.id
  cidr_block        = "192.168.100.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name    = "Subnet in ${data.aws_availability_zones.available.names[0]}"
    Owner   = "Andrei Shcheglov"
    Project = "AWS_Task"
  }
}

resource "aws_subnet" "subnet-2" {
  vpc_id            = aws_vpc.wp_vcp.id
  cidr_block        = "192.168.200.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name    = "Subnet in ${data.aws_availability_zones.available.names[1]}"
    Owner   = "Andrei Shcheglov"
    Project = "AWS_Task"
  }
}

# Create Internet Gateway for WP_VPC
resource "aws_internet_gateway" "wp_gateway" {
  vpc_id = aws_vpc.wp_vcp.id
  tags = {
    Name    = "WP_IG"
    Owner   = "Andrei Shcheglov"
    Project = "AWS_Task"
  }
  depends_on = [aws_vpc.wp_vcp]
}

# Route to Internet Gateway
resource "aws_route" "route_to_wp_gateway" {
  route_table_id         = aws_vpc.wp_vcp.main_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.wp_gateway.id
  depends_on             = [aws_internet_gateway.wp_gateway, aws_vpc.wp_vcp]
}

# Create route association
resource "aws_route_table_association" "subnet-1" {
  subnet_id      = aws_subnet.subnet-1.id
  route_table_id = aws_vpc.wp_vcp.main_route_table_id
}

resource "aws_route_table_association" "subnet-2" {
  subnet_id      = aws_subnet.subnet-2.id
  route_table_id = aws_vpc.wp_vcp.main_route_table_id
}

# Create EFS
resource "aws_efs_file_system" "wp_efs" {
  encrypted = true
  tags = {
    Name    = "WP_EFS"
    Owner   = "Andrei Shcheglov"
    Project = "AWS_Task"
  }
}

# Targets for EFS
resource "aws_efs_mount_target" "subnet-1" {
  file_system_id  = aws_efs_file_system.wp_efs.id
  subnet_id       = aws_subnet.subnet-1.id
  security_groups = [aws_security_group.sg_efs.id]
  depends_on      = [aws_efs_file_system.wp_efs, aws_security_group.sg_efs]
}

resource "aws_efs_mount_target" "subnet-2" {
  file_system_id  = aws_efs_file_system.wp_efs.id
  subnet_id       = aws_subnet.subnet-2.id
  security_groups = [aws_security_group.sg_efs.id]
  depends_on      = [aws_efs_file_system.wp_efs, aws_security_group.sg_efs]
}


# Create Security Groups
## For EC2 Instances 80
resource "aws_security_group" "sg_ec2" {
  name        = "SG_for_EC2"
  description = "Allow HTTP inbound traffic"
  vpc_id      = aws_vpc.wp_vcp.id

  ingress {
    description = "Allow all inbound traffic on the 80 port"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH from my IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${module.myip.address}/32"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "SG for EC2"
    Owner = "Andrei Shcheglov"
    Project = "AWS_Task"
  }
}

# For EFS
resource "aws_security_group" "sg_efs" {
  name        = "SG_for_EFS"
  description = "Allow NFS inbound traffic"
  vpc_id      = aws_vpc.wp_vcp.id

  ingress {
    description     = "NFS from EC2"
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.sg_ec2.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "SG for EFS"
    Owner = "Andrei Shcheglov"
    Project = "AWS_Task"
  }

  depends_on = [aws_security_group.sg_ec2]
}

# For RDS MySQL
resource "aws_security_group" "sg_rds" {
  name        = "SG_for_RDS"
  description = "Allow MySQL inbound traffic"
  vpc_id      = aws_vpc.wp_vcp.id

  ingress {
    description     = "RDS from EC2"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.sg_ec2.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "RDS from EC2"
    Owner = "Andrei Shcheglov"
    Project = "AWS_Task"
  }

  depends_on = [aws_security_group.sg_ec2]
}

# For ELB port 80
resource "aws_security_group" "sg_elb" {
  name        = "SG_for_ELB"
  description = "Allow traffic for ELB"
  vpc_id      = aws_vpc.wp_vcp.id

  ingress {
    description = "Allow all inbound traffic on the 80 port"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.sg_ec2.id]
  }

  tags = {
    Name = "SG for ELB"
    Owner = "Andrei Shcheglov"
    Project = "AWS_Task"
  }

  depends_on = [aws_security_group.sg_ec2]
}

# Crete subnet for RDS
resource "aws_db_subnet_group" "default" {
  name       = "main"
  subnet_ids = [aws_subnet.subnet-1.id, aws_subnet.subnet-2.id]
}

resource "aws_db_instance" "mysql" {
  identifier                      = "mysql"
  engine                          = "mysql"
  engine_version                  = "5.7.33"
  instance_class                  = "db.t2.micro"
  db_subnet_group_name            = aws_db_subnet_group.default.name
  enabled_cloudwatch_logs_exports = ["general", "error"]
  db_name                         = var.rds_credentials.dbname
  username                        = var.rds_credentials.username
  password                        = var.rds_credentials.password
  allocated_storage               = 20
  max_allocated_storage           = 0
  storage_type                    = "gp2"
  vpc_security_group_ids          = [aws_security_group.sg_rds.id]
  skip_final_snapshot             = true
  depends_on                      = [aws_security_group.sg_rds, aws_db_subnet_group.default]
  tags = {
    Name = "RDS mysql"
    Owner = "Andrei Shcheglov"
    Project = "AWS_Task"
  }
}


# Load Balancer
## Create ALB (Couse ELB deprecated @ 2022)
resource "aws_lb" "wp_lb" {
  name                       = "LoadBalancer"
  internal                   = false
  load_balancer_type         = "application"
  subnets                    = [aws_subnet.subnet-1.id, aws_subnet.subnet-2.id]
  security_groups            = [aws_security_group.sg_elb.id]
  enable_deletion_protection = false
  tags = {
    Name = "LoadBalancer"
    Owner = "Andrei Shcheglov"
    Project = "AWS_Task"
  }
}

## Create Target Groups
resource "aws_lb_target_group" "wp_tg" {
  name     = "TargetGroup"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.wp_vcp.id
  tags = {
    Name = "TG_for_ELB"
    Owner = "Andrei Shcheglov"
    Project = "AWS_Task"
  }
}

## Create Listener 80 port
resource "aws_lb_listener" "wp_lb" {
  load_balancer_arn = aws_lb.wp_lb.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.wp_tg.arn
  }
}

## Register Web1 in TG
resource "aws_lb_target_group_attachment" "tg_attach_wp1" {
  target_group_arn = aws_lb_target_group.wp_tg.arn
  target_id        = aws_instance.web1.id
  port             = 80
}

## Register Web2 in TG
resource "aws_lb_target_group_attachment" "tg_attach_wp2" {
  target_group_arn = aws_lb_target_group.wp_tg.arn
  target_id        = aws_instance.web2.id
  port             = 80
}

## UserData
data "template_file" "user_data" {
  template           = file ("./user_data.tpl")
  vars = {
    db_user          = var.rds_credentials.username
    db_password      = var.rds_credentials.password
    db_name          = var.rds_credentials.dbname
    db_host          = aws_db_instance.mysql.endpoint
    efs              = aws_efs_file_system.wp_efs.id
    url              = aws_lb.wp_lb.dns_name
  }
  depends_on = [aws_db_instance.mysql, aws_efs_file_system.wp_efs, aws_lb.wp_lb]
}


# Instances
## Create Control Instance (Install WP)
resource "aws_instance" "web1" {
  ami = data.aws_ami.last_amazon.id
  instance_type   = var.instance_type
  security_groups = [aws_security_group.sg_ec2.id]
  subnet_id       = aws_subnet.subnet-1.id
  associate_public_ip_address = true
  user_data       = data.template_file.user_data.rendered
  depends_on      = [aws_db_instance.mysql, aws_lb.wp_lb]
  lifecycle {
    create_before_destroy = true
  }
  tags = {
    Name    = "WebServer1"
    Owner   = "Andrei Shcheglov"
    Project = "AWS_Task"
  }
}

## Create second instance
resource "aws_instance" "web2" {
  ami = data.aws_ami.last_amazon.id
  instance_type   = var.instance_type
  security_groups = [aws_security_group.sg_ec2.id]
  subnet_id       = aws_subnet.subnet-2.id
  associate_public_ip_address = true
  user_data       = data.template_file.user_data.rendered
  depends_on      = [aws_db_instance.mysql, aws_lb.wp_lb, aws_instance.web1]
  lifecycle {
    create_before_destroy = true
  }
  tags = {
    Name = "WebServer2"
    Owner = "Andrei Shcheglov"
    Project = "AWS_Task"
  }
}


# Output LoadBalancer DNS Name
output "Balancer-Wordpress" {
  value = "http://${aws_lb.wp_lb.dns_name}"
}
