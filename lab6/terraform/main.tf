terraform{
    required_version = ">= 1.10.0"
    required_providers {
        aws = {
            source = "hashicorp/aws"
            version ="~>5.60"
        }
    }
}

provider "aws"{
    region = var.aws_region
}

variable "aws_region"{
    type = string 
    default = "us-east-1"
}

variable "instance_count"{
    description ="How many web servers. Two proves the inventory is dynamic"
    type = number
    default = 2
}

data "aws_ssm_parameter" "al2023"{
    name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_security_group" "web"{
    name = "asc730-lab6-sg"
    description = " ACS730 Lab web servers -- port 80 in , nothing else"

    ingress{
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress{
        from_port   = 0
        to_port = 0
        protocol = -1
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = { Name = "asc730-lab6-sg", Project = "asc730", Lab = "lab6"}

}

resource "aws_instance" "web"{
    count = var.instance_count
    ami = data.aws_ssm_parameter.al2023.value
    instance_type = "t3.micro"
    vpc_security_group_ids= [aws_security_group.web.id]

    iam_instance_profile ="LabInstanceProfile"


    tags = {
        Name = "asc730-lab6-web-${count.index}"
        Project = "asc730"
        Lab = "lab6"
        Role = "web"
    }
}

output "web_public_ips"{
    value = aws_instance.web[*].public_ip
}

output "firs_web_public_ips"{
    value = aws_instance.web[0].public_ip
}

output "web_instance_ids"{
    value = aws_instance.web[*].id
}

output "security_group_id"{
    value = aws_security_group.web.id
}