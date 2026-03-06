# ─────────────────────────────────────────────────────────────────
# EC2 Cluster: VPC, Subnets, Security Groups, ALB, ASG (3 nodes)
# ─────────────────────────────────────────────────────────────────

# ─── VPC & Networking ────────────────────────────────────────────

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags                 = { Name = "node-app-vpc" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "node-app-igw" }
}

resource "aws_subnet" "subnet_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags                    = { Name = "node-app-subnet-a" }
}

resource "aws_subnet" "subnet_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
  tags                    = { Name = "node-app-subnet-b" }
}

resource "aws_subnet" "subnet_c" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = "us-east-1c"
  map_public_ip_on_launch = true
  tags                    = { Name = "node-app-subnet-c" }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "node-app-public-rt" }
}

resource "aws_route_table_association" "rta_a" {
  subnet_id      = aws_subnet.subnet_a.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "rta_b" {
  subnet_id      = aws_subnet.subnet_b.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "rta_c" {
  subnet_id      = aws_subnet.subnet_c.id
  route_table_id = aws_route_table.public_rt.id
}

# ─── Security Groups ─────────────────────────────────────────────

resource "aws_security_group" "alb_sg" {
  name        = "alb-security-group"
  description = "Security group para o Application Load Balancer"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP da internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "alb-sg" }
}

resource "aws_security_group" "node_sg" {
  name        = "node-server-security-group"
  description = "Security group para os servidores Node.js"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Porta Node.js vinda do ALB"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  ingress {
    description = "SSH de administração"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "node-sg" }
}

# ─── IAM para CodeDeploy nas instâncias ──────────────────────────

resource "aws_iam_role" "ec2_codedeploy_role" {
  name = "ec2_codedeploy_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_codedeploy_attach" {
  role       = aws_iam_role.ec2_codedeploy_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforAWSCodeDeploy"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2_codedeploy_profile"
  role = aws_iam_role.ec2_codedeploy_role.name
}

# ─── Launch Template ─────────────────────────────────────────────

resource "aws_launch_template" "node_lt" {
  name_prefix   = "node-server-"
  image_id      = "ami-0c02fb55956c7d316" # Amazon Linux 2 (us-east-1)
  instance_type = "t2.micro"

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
  }

  vpc_security_group_ids = [aws_security_group.node_sg.id]

  # Bootstrap: instala Node.js, inicia server e instala agente CodeDeploy
  user_data = base64encode(file("scripts/user_data.sh"))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "node-hello-world"
      Environment = "localstack"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ─── Auto Scaling Group (3 instâncias) ───────────────────────────

resource "aws_autoscaling_group" "node_asg" {
  name             = "node-server-asg"
  min_size         = 3
  max_size         = 3
  desired_capacity = 3

  vpc_zone_identifier = [
    aws_subnet.subnet_a.id,
    aws_subnet.subnet_b.id,
    aws_subnet.subnet_c.id,
  ]

  target_group_arns = [aws_lb_target_group.node_tg.arn]

  launch_template {
    id      = aws_launch_template.node_lt.id
    version = "$Latest"
  }

  health_check_type         = "ELB"
  health_check_grace_period = 60

  tag {
    key                 = "Name"
    value               = "node-hello-world"
    propagate_at_launch = true
  }
}

# ─── Application Load Balancer ───────────────────────────────────

resource "aws_lb" "node_alb" {
  name               = "node-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets = [
    aws_subnet.subnet_a.id,
    aws_subnet.subnet_b.id,
    aws_subnet.subnet_c.id,
  ]
  enable_deletion_protection = false
  tags                       = { Name = "node-alb" }
}

resource "aws_lb_target_group" "node_tg" {
  name     = "node-target-group"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    enabled             = true
    path                = "/"
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }

  tags = { Name = "node-tg" }
}

resource "aws_lb_listener" "node_listener" {
  load_balancer_arn = aws_lb.node_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.node_tg.arn
  }
}

# ─── Outputs ─────────────────────────────────────────────────────

output "alb_dns_name" {
  value       = aws_lb.node_alb.dns_name
  description = "DNS do Application Load Balancer"
}
