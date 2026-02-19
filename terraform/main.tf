provider "aws" {
  region = "ap-southeast-2"
}

terraform {
  backend "s3" {
    bucket = "tfstate-pala3105"  # replace this bucket before running
    key    = "converter/terraform.tfstate"
    region = "ap-southeast-2"
  }
}

module "frontend" {
  source = "../frontend"
}

data "terraform_remote_state" "source" {
  backend = "s3"
  config = {
    bucket = "tfstate-pala3105" # replace this bucket before running
    key    = "iosglacierbackups/terraform.tfstate"
    region = "ap-southeast-2"
  }
}

import {
  to = aws_ecr_repository.iosglacierbackupsconversion
  id = "iosglacierbackupsconversion"
}
