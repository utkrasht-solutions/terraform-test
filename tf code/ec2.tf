
resource "tls_private_key" "falcon_keypair" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "falcon_keypair" {
  key_name   = "falcon-ec2"
  public_key = tls_private_key.falcon_keypair.public_key_openssh
  tags = local.tags
}

resource "aws_ssm_parameter" "falcon_keypair" {
  name          = "falcon-keypair"
  type          = "SecureString"
  value         = tls_private_key.falcon_keypair.private_key_pem
  tags = local.tags
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-*-20*-amd64-server-*"]
  }

  owners = ["099720109477"]
}

resource "aws_instance" "falcon_web" {
  ami = data.aws_ami.ubuntu.id
  associate_public_ip_address = true
  security_groups = [aws_security_group.falcon_ec2_sg.id]
  subnet_id = aws_subnet.falcon_sn_1.id
  key_name = "falcon-ec2"
  instance_type = "t2.micro"
#  user_data = file("docs/userdata.sh")
  tags = merge(
  { "Name" = "falcon-web"},
  local.tags)

  provisioner "remote-exec" {
    inline = [
      "export PATH=$PATH:/usr/bin",
      "sudo apt-get update",
      "sudo apt-get -y install nginx",
      "sudo systemctl enable nginx",
      "sudo systemctl start nginx",
      "sudo chown -R ubuntu: /var/www/html/"
    ]
  }

  provisioner "file" {
    source      = "../index.html"
    destination = "/var/www/html/index.html"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = tls_private_key.falcon_keypair.private_key_pem
      host        = aws_instance.falcon_web.public_ip
    }
  }

}