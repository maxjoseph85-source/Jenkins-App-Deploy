############################################
# Jenkins Server (EC2) — us-east-2 via existing provider
############################################

variable "my_ip" {
  description = "Your public IP in CIDR form, e.g. 1.2.3.4/32"
  type        = string
}

# --- Latest Amazon Linux 2023 AMI (auto-resolves for the provider's region) ---
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023*-x86_64"]
  }
}

# --- SSH key pair ---
resource "tls_private_key" "jenkins" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "jenkins" {
  key_name   = "jenkins-key"
  public_key = tls_private_key.jenkins.public_key_openssh
}

resource "local_file" "jenkins_pem" {
  content         = tls_private_key.jenkins.private_key_pem
  filename        = "${path.module}/jenkins-key.pem"
  file_permission = "0400"
}

# --- Security group ---
resource "aws_security_group" "jenkins" {
  name        = "jenkins-sg"
  description = "Jenkins security group"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  ingress {
    description = "Jenkins UI"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "jenkins-sg" }
}

# --- IAM role: lets Jenkins push to ECR and talk to EKS without access keys ---
resource "aws_iam_role" "jenkins" {
  name = "jenkins-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "jenkins_ecr" {
  role       = aws_iam_role.jenkins.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
}

resource "aws_iam_role_policy" "jenkins_eks" {
  name = "jenkins-eks-describe"
  role = aws_iam_role.jenkins.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["eks:DescribeCluster", "eks:ListClusters"]
      Resource = "*"
    }]
  })
}

resource "aws_iam_instance_profile" "jenkins" {
  name = "jenkins-instance-profile"
  role = aws_iam_role.jenkins.name
}

# --- EC2 instance ---
resource "aws_instance" "jenkins" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = "t3.medium"
  key_name                    = aws_key_pair.jenkins.key_name
  subnet_id                   = module.vpc.public_subnets[0]
  vpc_security_group_ids      = [aws_security_group.jenkins.id]
  iam_instance_profile        = aws_iam_instance_profile.jenkins.name
  associate_public_ip_address = true

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  tags = { Name = "jenkins-server" }
}

# --- Outputs ---
output "jenkins_public_ip" {
  value = aws_instance.jenkins.public_ip
}

output "jenkins_ssh" {
  value = "ssh -i jenkins-key.pem ec2-user@${aws_instance.jenkins.public_ip}"
}

output "jenkins_url" {
  value = "http://${aws_instance.jenkins.public_ip}:8080"
}

output "jenkins_role_arn" {
  value = aws_iam_role.jenkins.arn
}