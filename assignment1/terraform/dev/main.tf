module "web_stack" {
  source = "../modules/web-stack"

  environment   = "dev"
  owner         = "mkaur910"
  vpc_cidr      = "10.10.0.0/16"
  instance_type = "t3.micro"

  public_subnets = {
    a = { cidr_block = "10.10.1.0/24", az_index = 0 }
    b = { cidr_block = "10.10.2.0/24", az_index = 1 }
  }

  create_artifact_bucket = false
}

output "vpc_id" {
  value = module.web_stack.vpc_id
}

output "web_instance_id" {
  value = module.web_stack.web_instance_id
}

output "web_url" {
  value = module.web_stack.web_url
}