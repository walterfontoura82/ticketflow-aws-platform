terraform {
  backend "s3" {
    bucket       = "ticketflow-tfstate-414691912724-us-east-1"
    key          = "environments/dev/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
