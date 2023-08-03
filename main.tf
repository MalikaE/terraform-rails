terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  
  required_version = ">= 1.2.0"
}

provider "aws" {
  region  = "us-east-1"

}

module "vpc" {
  source = "./modules/VPC"
  vpc_name = "rail-application"
    cidr_range = "10.100.0.0/16"
    azs = ["us-east-1a", "us-east-1b", "us-east-1c"]
    public_subnets = ["10.100.1.0/24","10.100.2.0/24","10.100.3.0/24"]
    private_subnets = ["10.100.10.0/24","10.100.11.0/24","10.100.12.0/24"]
    enable_nat_gateway = true
}


module "security_groups" {
  source = "./modules/security_groups"
  vpc_id = module.vpc.vpc_id

  depends_on = [
    module.vpc
  ]
}


module "autoscaling" {
  source  = "./modules/Autoscaling"

  # insert required variables here
    create_autoscaling = true
    counter = 1

    name_prefix = "rail-"
    min_size = 1
    max_size = 3
    desired_capacity = 1

    image_id = "ami-0149b2da6ceec4bb0"
    instance_type = "t2.nano"
    key_name = "rails.kp"
    private_subnets = module.vpc.private_subnets

    security_groups = ["${module.security_groups.allow_web}"]
    user_data = file("user_data.sh")

    root_block = {
        size = 8
        type = "gp2"
    }

    scaling_alarms = {
        scale_out = {
            enabled = true
            metric_name = "CPUUtilization"
            comparison_operator = "GreaterThanOrEqualToThreshold"
            threshold = 50
            period = 60
            evaluation_periods = 2
            statistic = "Average"
            unit = "Percent"
            alarm_description = "Scale out if CPU > 80%"
            alarm_actions = ["arn:aws:automate:us-east-1:ec2:scale"]
            namespace = "AWS/EC2"
        }

        scale_in = {
            enabled = true
            metric_name = "CPUUtilization"
            comparison_operator = "LessThanOrEqualToThreshold"
            threshold = 40
            period = 60
            evaluation_periods = 2
            statistic = "Average"
            unit = "Percent"
            alarm_description = "Scale in if CPU < 20%"
            alarm_actions = ["arn:aws:automate:us-east-1:ec2:terminate"]
            namespace = "AWS/EC2"
        }
    }

    scaling_policies = {
        scale_out = {
            adjustment_type = "ChangeInCapacity"
            scaling_adjustment = 1
            cooldown = 300
            policy_type = "SimpleScaling"
        }

        scale_in = {
            adjustment_type = "ChangeInCapacity"
            scaling_adjustment = -1
            cooldown = 300
            policy_type = "SimpleScaling"
        }
    }

  depends_on = [
    module.vpc,
    module.security_groups
  ]
}

module "loadbalancer"{
  source = "./modules/LoadBalancer"

  
  vpc_id = module.vpc.vpc_id
  subnets = module.vpc.public_subnets
  security_groups = [module.security_groups.lb_sec_group]
  port = "80"
  protocol = "HTTP"
  autoscaling_group_name = module.autoscaling.autoscaling_group_name

  

  depends_on = [
    module.vpc, module.autoscaling

  ]
}
