terraform {
  backend "s3" {
    bucket       = "cookies101"
    key          = "eks-project/terraform.tfstate"
    region       = "us-east-2"
    encrypt      = true
    use_lockfile = true
  }
}