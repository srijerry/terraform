terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "us-east-2"
  access_key = ""
  secret_key = ""
}

resource "aws_key_pair" "tf_key" {
  key_name   = "tf_key"
  public_key = tls_private_key.rsa.public_key_openssh
}

resource "tls_private_key" "rsa" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "tf_key" {
  content  = tls_private_key.rsa.private_key_pem
  filename = "tf_key"
}

# Create EC2 instance
resource "aws_spot_instance_request" "jenkins-master" {
  ami           = "ami-0a695f0d95cefc163"
  spot_price    = "0.0627"                                                                                                                                                                                                                                                                                                                                                                                            
  instance_type = "t3.xlarge"
  wait_for_fulfillment = "true"
  key_name      = aws_key_pair.tf_key.key_name
  vpc_security_group_ids = ["sg-03b90bb7f6b729d9a"]
  associate_public_ip_address = true
}

# resource "aws_ebs_volume" "jenkins_master_vol" {
#   availability_zone = "us-east-2a"
#   size              = 20
#   depends_on = [aws_spot_instance_request.jenkins-master]
# }

# resource "aws_volume_attachment" "ebs_att" {
#   device_name = "/dev/sdh"
#   volume_id   = aws_ebs_volume.jenkins_master_vol.id
#   instance_id = aws_spot_instance_request.jenkins-master.id
#   depends_on = [aws_ebs_volume.jenkins_master_vol]
# }

resource "null_resource" "name" {

  # ssh into the ec2 instance
  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = local_file.tf_key.content
    host        = aws_spot_instance_request.jenkins-master.public_ip
  }

  # copy the install_jenkins.sh file from your computer to the ec2 instance
  provisioner "file" {
    source      = "installjenkins.sh"
    destination = "/tmp/installjenkins.sh"
  }

  # set permissions and run the install_jenkins.sh file
  provisioner "remote-exec" {
    inline = [
      "sudo chmod +x /tmp/installjenkins.sh",
      "sh /tmp/installjenkins.sh",
    ]
  }

  # wait for ec2 to be created
  depends_on = [aws_spot_instance_request.jenkins-master]
}

output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_spot_instance_request.jenkins-master.public_ip
}
