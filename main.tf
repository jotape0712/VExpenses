provider "aws" {
  region = "us-east-1"  # Define a região AWS onde os recursos serão criados
}

variable "projeto" {
  description = "Nome do projeto"
  type        = string
  default     = "VExpenses"  # Nome do projeto padrão
}

variable "candidato" {
  description = "Nome do candidato"
  type        = string
  default     = "SeuNome"  # Nome do candidato padrão
}

# Gera uma chave privada TLS (utilizada para SSH na EC2)
resource "tls_private_key" "ec2_key" {
  algorithm = "RSA"   # Tipo de algoritmo usado para gerar a chave
  rsa_bits  = 2048    # Tamanho da chave, 2048 bits
}

# Cria um par de chaves para ser usado pela EC2
resource "aws_key_pair" "ec2_key_pair" {
  key_name   = "${var.projeto}-${var.candidato}-key"  # Nome da chave gerada com base nas variáveis
  public_key = tls_private_key.ec2_key.public_key_openssh  # Usa a chave pública gerada anteriormente
}

# Cria uma VPC (Virtual Private Cloud) para isolar a rede
resource "aws_vpc" "main_vpc" {
  cidr_block           = "10.0.0.0/16"  # Bloco de IPs que define o tamanho da rede
  enable_dns_support   = true  # Habilita suporte DNS
  enable_dns_hostnames = true  # Habilita nomes DNS para os hosts

  tags = {
    Name = "${var.projeto}-${var.candidato}-vpc"  # Nome da VPC, usando as variáveis
  }
}

# Cria uma Subnet dentro da VPC
resource "aws_subnet" "main_subnet" {
  vpc_id            = aws_vpc.main_vpc.id  # ID da VPC criada anteriormente
  cidr_block        = "10.0.1.0/24"  # Bloco de IPs para a subnet
  availability_zone = "us-east-1a"   # Zona de disponibilidade onde a subnet será criada

  tags = {
    Name = "${var.projeto}-${var.candidato}-subnet"  # Nome da subnet
  }
}

# Cria um Internet Gateway para permitir tráfego da Internet
resource "aws_internet_gateway" "main_igw" {
  vpc_id = aws_vpc.main_vpc.id  # ID da VPC onde o gateway será associado

  tags = {
    Name = "${var.projeto}-${var.candidato}-igw"  # Nome do internet gateway
  }
}

# Cria uma tabela de roteamento para gerenciar o tráfego de rede
resource "aws_route_table" "main_route_table" {
  vpc_id = aws_vpc.main_vpc.id  # ID da VPC

  route {
    cidr_block = "0.0.0.0/0"  # Rota padrão, direciona todo o tráfego para o Internet Gateway
    gateway_id = aws_internet_gateway.main_igw.id  # Gateway de internet criado anteriormente
  }

  tags = {
    Name = "${var.projeto}-${var.candidato}-route_table"  # Nome da tabela de roteamento
  }
}

# Associa a subnet com a tabela de roteamento
resource "aws_route_table_association" "main_association" {
  subnet_id      = aws_subnet.main_subnet.id  # ID da subnet
  route_table_id = aws_route_table.main_route_table.id  # ID da tabela de rotas
}

# Cria um Security Group para controlar o tráfego de rede
resource "aws_security_group" "main_sg" {
  name        = "${var.projeto}-${var.candidato}-sg"  # Nome do security group
  description = "Allow SSH access and all outbound traffic"  # Descrição simplificada
  vpc_id      = aws_vpc.main_vpc.id  # ID da VPC

  # Regras de entrada
  ingress {
    description      = "Allow SSH from specific IP"  # Descrição da regra de SSH
    from_port        = 22  # Porta SSH
    to_port          = 22
    protocol         = "tcp"  # Protocolo TCP
    cidr_blocks      = ["26.64.12.12/32"]  # Aqui restringimos o SSH ao seu IP
    ipv6_cidr_blocks = []  # Não há regras de IPv6 aqui
  }

  # Regras de saída
  egress {
    description      = "Allow all outbound traffic"  # Descrição da regra de saída
    from_port        = 0
    to_port          = 0
    protocol         = "-1"  # Permite todo o tráfego de saída
    cidr_blocks      = ["0.0.0.0/0"]  # Para qualquer destino na Internet
    ipv6_cidr_blocks = ["::/0"]  # Para qualquer destino IPv6
  }

  
}

# Seleciona a AMI mais recente do Debian 12
data "aws_ami" "debian12" {
  most_recent = true  # Garante que sempre pegue a mais recente

  filter {
    name   = "name"
    values = ["debian-12-amd64-*"]  # Filtra por nome da AMI Debian 12
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]  # Utiliza a virtualização HVM
  }

  owners = ["679593333241"]  # ID do dono da AMI (Debian)
}

# Cria uma instância EC2 baseada na AMI Debian 12
resource "aws_instance" "debian_ec2" {
  ami             = data.aws_ami.debian12.id  # Utiliza a AMI identificada anteriormente
  instance_type   = "t2.micro"  # Tipo de instância (grátis no nível free tier)
  subnet_id       = aws_subnet.main_subnet.id  # ID da subnet onde a EC2 será executada
  key_name        = aws_key_pair.ec2_key_pair.key_name  # Nome do par de chaves gerado
  security_groups = [aws_security_group.main_sg.name]  # Associa o security group criado

  associate_public_ip_address = true  # Atribui um IP público para acessar a EC2

  # Configuração do disco da EC2
  root_block_device {
    volume_size           = 20  # Tamanho do disco de 20GB
    volume_type           = "gp2"  # Tipo de volume (gp2)
    delete_on_termination = true  # Exclui o volume quando a instância for destruída
  }

  # Script para rodar quando a EC2 for iniciada
  user_data = <<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get upgrade -y
              apt-get install nginx -y
              systemctl start nginx
              systemctl enable nginx
              EOF

  tags = {
    Name = "${var.projeto}-${var.candidato}-ec2"  # Nome da instância EC2
  }

  depends_on = [aws_security_group.main_sg]  # Garante que o Security Group seja criado antes
}

# Output que exibe a chave privada gerada para a EC2
output "private_key" {
  description = "Chave privada para acessar a instância EC2"
  value       = tls_private_key.ec2_key.private_key_pem  # Exibe a chave privada
  sensitive   = true  # Marca como sensível para esconder a chave
}

# Output que exibe o IP público da EC2
output "ec2_public_ip" {
  description = "Endereço IP público da instância EC2"
  value       = aws_instance.debian_ec2.public_ip  # Exibe o IP público da instância
}
