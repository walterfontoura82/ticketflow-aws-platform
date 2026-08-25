terraform {
  backend "s3" {
    bucket       = "ticketflow-tfstate-966299413569-us-east-1"
    key          = "environments/dev/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
