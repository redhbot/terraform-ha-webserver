provider "aws" {
  region = var.region
}

resource "aws_vpc" "odoo_vpc" {
  cidr_block = var.vpc_cidr
  tags = {
    Project = "odoo_project"
    Name    = "odoo_vpc"
  }
}

# Public subnet 1
resource "aws_subnet" "pub_sub1" {
  vpc_id                  = aws_vpc.odoo_vpc.id
  cidr_block              = var.pub_sub1_cidr_block
  availability_zone       = "eu-west-1a"
  map_public_ip_on_launch = true
  tags = {
    Project = "odoo"
    Name    = "pub_sub1"
  }
}

# Public subnet 2 
resource "aws_subnet" "pub_sub2" {
  vpc_id                  = aws_vpc.odoo_vpc.id
  cidr_block              = var.pub_sub2_cidr_block
  availability_zone       = "eu-west-1b"
  map_public_ip_on_launch = true
  tags = {
    Project = "odoo"
    Name    = "pub_sub2"
  }
}

# Private subnet 1
resource "aws_subnet" "prv_sub1" {
  vpc_id                  = aws_vpc.odoo_vpc.id
  cidr_block              = var.prv_sub1_cidr_block
  availability_zone       = "eu-west-1a"
  map_public_ip_on_launch = false
  tags = {
    Project = "odoo"
    Name    = "private_subnet1"
  }
}

# Private subnet 2
resource "aws_subnet" "prv_sub2" {
  vpc_id                  = aws_vpc.odoo_vpc.id
  cidr_block              = var.prv_sub2_cidr_block
  availability_zone       = "eu-west-1b"
  map_public_ip_on_launch = false
  tags = {
    Project = "odoo"
    Name    = "private_subnet2"
  }
}

# Public route table
resource "aws_route_table" "pub_sub_rt" {
  vpc_id = aws_vpc.odoo_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Project = "odoo"
    Name    = "pub_sub_rt"
  }
}

# Route table association of public subnet1
resource "aws_route_table_association" "internet_for_pub_sub1" {
  route_table_id = aws_route_table.pub_sub_rt.id
  subnet_id      = aws_subnet.pub_sub1.id
}

# Route table association of public subnet2
resource "aws_route_table_association" "internet_for_pub_sub2" {
  route_table_id = aws_route_table.pub_sub_rt.id
  subnet_id      = aws_subnet.pub_sub2.id
}

# Internet gateway 
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.odoo_vpc.id
  tags = {
    Project = "odoo"
    Name    = "igw"
  }
}

# EIP for NAT GW1  
resource "aws_eip" "eip_natgw1" {
  count = "1"
}

# NAT gateway1
resource "aws_nat_gateway" "natgateway_1" {
  count         = "1"
  allocation_id = aws_eip.eip_natgw1[count.index].id
  subnet_id     = aws_subnet.pub_sub1.id
}

# EIP for NAT GW2
resource "aws_eip" "eip_natgw2" {
  count = "1"
}

# NAT gateway2
resource "aws_nat_gateway" "natgateway_2" {
  count         = "1"
  allocation_id = aws_eip.eip_natgw2[count.index].id
  subnet_id     = aws_subnet.pub_sub2.id
}

# Private route table for prv sub1
resource "aws_route_table" "prv_sub1_rt" {
  count  = "1"
  vpc_id = aws_vpc.odoo_vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.natgateway_1[count.index].id
  }
  tags = {
    Project = "odoo"
    Name    = "prv_sub1_rt"
  }
}

# Route table association between prv sub1 & NAT GW1
resource "aws_route_table_association" "pri_sub1_to_natgw1" {
  count          = "1"
  route_table_id = aws_route_table.prv_sub1_rt[count.index].id
  subnet_id      = aws_subnet.prv_sub1.id
}

# Private route table for prv sub2
resource "aws_route_table" "prv_sub2_rt" {
  count  = "1"
  vpc_id = aws_vpc.odoo_vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.natgateway_2[count.index].id
  }
  tags = {
    Project = "odoo"
    Name    = "prv_sub2_rt"
  }
}

# Route table association between prv sub2 & NAT GW2
resource "aws_route_table_association" "pri_sub2_to_natgw1" {
  count          = "1"
  route_table_id = aws_route_table.prv_sub2_rt[count.index].id
  subnet_id      = aws_subnet.prv_sub2.id
}

# Security group for load balancer
resource "aws_security_group" "elb_sg" {
  name        = var.sg_name
  description = var.sg_description
  vpc_id      = aws_vpc.odoo_vpc.id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    description = "HTTP"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name    = var.sg_tagname
    Project = "odoo"
  }
}

# Security group for webserver
resource "aws_security_group" "webserver_sg" {
  name        = var.sg_ws_name
  description = var.sg_ws_description
  vpc_id      = aws_vpc.odoo_vpc.id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    description = "HTTP"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    description = "HTTP"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  tags = {
    Name    = var.sg_ws_tagname
    Project = "odoo"
  }
}

# Launch config
resource "aws_launch_configuration" "webserver_launch_config" {
  name_prefix     = "webserver_launch_config"
  image_id        = var.ami
  instance_type   = "t2.micro"
  key_name        = var.keyname
  security_groups = ["${aws_security_group.webserver_sg.id}"]

  root_block_device {
    volume_type = "gp2"
    volume_size = 10
    encrypted   = true
  }
  ebs_block_device {
    device_name = "/dev/sdf"
    volume_type = "gp2"
    volume_size = 5
    encrypted   = true
  }
  lifecycle {
    create_before_destroy = true
  }
  user_data = filebase64("${path.module}/${var.user_data_script}")
}

# Auto scaling group
resource "aws_autoscaling_group" "odoo_asg" {
  name                 = "odoo_asg"
  desired_capacity     = 1
  max_size             = 3
  min_size             = 1
  force_delete         = true
  depends_on           = [aws_lb.odoo_alb]
  target_group_arns    = ["${aws_lb_target_group.odoo_tg.arn}"]
  health_check_type    = "EC2"
  launch_configuration = aws_launch_configuration.webserver_launch_config.name
  vpc_zone_identifier  = ["${aws_subnet.prv_sub1.id}", "${aws_subnet.prv_sub2.id}"]

  tag {
    key                 = "Name"
    value               = "odoo_asg"
    propagate_at_launch = true
  }
}

# Target group
resource "aws_lb_target_group" "odoo_tg" {
  name       = "odoo-tg"
  depends_on = [aws_vpc.odoo_vpc]
  port       = 80
  protocol   = "HTTP"
  vpc_id     = aws_vpc.odoo_vpc.id
  health_check {
    interval            = 70
    path                = "/index.html"
    port                = 80
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 60
    protocol            = "HTTP"
    matcher             = "200,202"
  }
}

# ALB
resource "aws_lb" "odoo_alb" {
  name               = "odoo-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.elb_sg.id]
  subnets            = [aws_subnet.pub_sub1.id, aws_subnet.pub_sub2.id]
  tags = {
    Name    = "odoo-alb"
    Project = "odoo"
  }
}

# ALB listener
resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.odoo_alb.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.odoo_tg.arn
  }
}
