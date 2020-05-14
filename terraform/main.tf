provider "aws" {
  version = "~> 2.0"
  region  = "asia-southeast-1"
}

resource "aws_vpc" "main" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "dedicated"

  tags = {
    Name = "main"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = "${aws_vpc.main.id}"
}

resource "aws_subnet" "public" {
  vpc_id     = "${aws_vpc.main.id}"
  cidr_block = "20.10.0.0/16"
  public_subnets = ["20.10.1.0/24"]
  private_subnets = ["20.10.11.0/24"]
  map_public_ip_on_launch = true

  tags = {
    Name = "Main"
  }
  
  depends_on = ["aws_internet_gateway.gw"]

}

resource "aws_nat_gateway" "gw" {
  allocation_id = "${aws_eip.nat.id}"
  subnet_id     = "${aws_subnet.public_subnets.id}"

  tags = {
    Name = "gw NAT"
  }
}

resource "aws_eip" "nat" {
  vpc = true

  instance                  = "${aws_instance.foo.id}"
  associate_with_private_ip = "10.0.0.12"
  depends_on                = ["aws_internet_gateway.gw"]
}

resource "aws_launch_template" "ec2type" {
  name_prefix   = "ec2type"
  image_id      = "ami-1a2b3c"
  instance_type = "t2.medium"
}

resource "aws_placement_group" "apg1" {
  name     = "apg1"
  strategy = "cluster"
}

resource "aws_autoscaling_policy" "ap1" {
  name                   = "terraform-ap1"
  scaling_adjustment     = 5
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = "${aws_autoscaling_group.ag1.name}"
}

resource "aws_autoscaling_group" "ag1" {
  name                      = "terraform-ag1"
  max_size                  = 5
  min_size                  = 2
  health_check_grace_period = 300
  health_check_type         = "ELB"
  desired_capacity          = 4
  force_delete              = true
  placement_group           = "${aws_placement_group.apg1.id}"
  launch_configuration      = "${aws_launch_configuration.ec2type.name}"
  vpc_zone_identifier       = "${aws_subnet.private_subnets.id}"
}

resource "aws_cloudwatch_metric_alarm" "cma1" {
  alarm_name          = "terraform-cma1"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "45"

  dimensions = {
    AutoScalingGroupName = "${aws_autoscaling_group.ag1.name}"
  }

  alarm_description = "This metric monitors ec2 cpu utilization"
  alarm_actions     = ["${aws_autoscaling_policy.ap1.arn}"]
}