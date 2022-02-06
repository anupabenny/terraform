provider "aws" {
    region = "us-east-1"
}
data "aws_ami" "gold" {
  most_recent = true
  owners      = ["self"]

  filter {
    name   = "name"
    values = ["amitest*"]
  }
}

resource "aws_key_pair" "my_instance_key_pair" {
    key_name = "terraform_learning_key_1"
    public_key = file("/var/lib/jenkins/.ssh/id_rsa.pub")
}

#Creating VPC
resource "aws_vpc" "my_vpc" {
    cidr_block = "10.0.0.0/16"
    enable_dns_hostnames = true
}

#Creating internet gateway and Routing table for above VPC
resource "aws_internet_gateway" "my_vpc_igw" {
    vpc_id = aws_vpc.my_vpc.id
}

resource "aws_route_table" "my_public_route_table" {
    vpc_id = aws_vpc.my_vpc.id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.my_vpc_igw.id
    }
}

#Creating subnet1 in above VPC
resource "aws_subnet" "my_subnet_public_east_1b" {
    vpc_id = aws_vpc.my_vpc.id
    cidr_block = "10.0.0.0/24"
    availability_zone = "us-east-1b"
}

#Associating above routing table to above subnet1
resource "aws_route_table_association" "my_public_route_association_for_east_1b" {
    subnet_id = aws_subnet.my_subnet_public_east_1b.id
    route_table_id = aws_route_table.my_public_route_table.id
}

#creating subnet2 in above VPC
resource "aws_subnet" "my_subnet_public_east_1c" {
    vpc_id = aws_vpc.my_vpc.id
    cidr_block = "10.0.1.0/24"
    availability_zone = "us-east-1c"
}

#Associating above routing table to above subnet2
resource "aws_route_table_association" "my_public_route_association_for_east_1c" {
    subnet_id = aws_subnet.my_subnet_public_east_1c.id
    route_table_id = aws_route_table.my_public_route_table.id
}

# Create a public application load balancer
resource "aws_lb" "my_alb" {
    name = "my-alb"
    internal = false
    load_balancer_type = "application"
    security_groups = [aws_security_group.my_alb_security_group.id]
    subnets = [ aws_subnet.my_subnet_public_east_1b.id,
        aws_subnet.my_subnet_public_east_1c.id ]
}

#Create security Group for above LB
resource "aws_security_group" "my_alb_security_group" {
    vpc_id = aws_vpc.my_vpc.id
    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

#Create LB listener to forward traffic from 80 to 8888
resource "aws_lb_listener" "my_alb_listener" {
    load_balancer_arn = aws_lb.my_alb.arn
    port = 80
    protocol = "HTTP"
    default_action {
        target_group_arn = aws_lb_target_group.my_alb_target_group.arn
        type = "forward"
    }
}

resource "aws_lb_target_group" "my_alb_target_group" {
    port = 8888
    protocol = "HTTP"
    vpc_id = aws_vpc.my_vpc.id
}


resource "aws_launch_configuration" "my_launch_configuration" {

    image_id = data.aws_ami.gold.id

    instance_type = "t2.micro"
    key_name = aws_key_pair.my_instance_key_pair.key_name
    security_groups = [aws_security_group.my_launch_config_security_group.id]

    associate_public_ip_address = true
    lifecycle {
        create_before_destroy = true
    }
}

resource "aws_security_group" "my_launch_config_security_group" {
    vpc_id = aws_vpc.my_vpc.id
    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
        from_port = 8888
        to_port = 8888
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}


resource "aws_autoscaling_attachment" "my_aws_autoscaling_attachment" {
    alb_target_group_arn = aws_lb_target_group.my_alb_target_group.arn
    autoscaling_group_name = aws_autoscaling_group.my_autoscaling_group.id
}

resource "aws_autoscaling_group" "my_autoscaling_group" {
    name = "my-autoscaling-group"
    desired_capacity = 2
    min_size = 2
    max_size = 5
    enabled_metrics = ["GroupMinSize", "GroupMaxSize", "GroupDesiredCapacity", "GroupInServiceInstances", "GroupTotalInstances"]
    metrics_granularity = "1Minute"
    health_check_type = "ELB"

    force_delete = true

    launch_configuration = aws_launch_configuration.my_launch_configuration.id
    vpc_zone_identifier = [
        aws_subnet.my_subnet_public_east_1b.id,
        aws_subnet.my_subnet_public_east_1c.id
    ]
    timeouts {
        delete = "15m"
    }
    lifecycle {
        # ensure the new instance is only created before the other one is destroyed.
        create_before_destroy = true
    }
tag {
      key                 = "Name"
      value               = "Application-Server"
      propagate_at_launch  = true
}
}

resource "aws_autoscaling_policy" "autopolicy" {
name = "terraform-autopolicy"
scaling_adjustment = 1
adjustment_type = "ChangeInCapacity"
cooldown = 300
autoscaling_group_name = aws_autoscaling_group.my_autoscaling_group.name
}

resource "aws_cloudwatch_metric_alarm" "cpualarm" {
alarm_name = "terraform-alarm"
comparison_operator = "GreaterThanOrEqualToThreshold"
evaluation_periods = "2"
metric_name = "CPUUtilization"
namespace = "AWS/EC2"
period = "120"
statistic = "Average"
threshold = "75"

dimensions = {
AutoScalingGroupName = aws_autoscaling_group.my_autoscaling_group.name
}

alarm_description = "This metric monitor EC2 instance cpu utilization"
alarm_actions = aws_autoscaling_policy.autopolicy.arn
}

resource "aws_autoscaling_policy" "autopolicy-down" {
name = "terraform-autopolicy-down"
scaling_adjustment = -1
adjustment_type = "ChangeInCapacity"
cooldown = 300
autoscaling_group_name = aws_autoscaling_group.my_autoscaling_group.name
}

resource "aws_cloudwatch_metric_alarm" "cpualarm-down" {
alarm_name = "terraform-alarm-down"
comparison_operator = "LessThanOrEqualToThreshold"
evaluation_periods = "2"
metric_name = "CPUUtilization"
namespace = "AWS/EC2"
period = "120"
statistic = "Average"
threshold = "10"

dimensions = {
AutoScalingGroupName = aws_autoscaling_group.my_autoscaling_group.name
}

alarm_description = "This metric monitor EC2 instance cpu utilization"
alarm_actions = aws_autoscaling_policy.autopolicy-down.arn
}

output "alb-url" {
    value = aws_lb.my_alb.dns_name
}

