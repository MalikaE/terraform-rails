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
  region = "us-east-1"
}

resource "aws_instance" "foo" {
  ami           = "ami-053b0d53c279acc90" 
  instance_type = "t2.micro"
}
  network_interface {
    network_interface_id = aws_network_interface.foo.id
    device_index         = 0
  }
