/*
El backend se mantiene separado para que el proceso de cambio de sandbox
pueda desactivarlo temporalmente, crear el bucket nuevo con state local y
migrar después ese state a S3.
*/
terraform {
  backend "s3" {
    bucket       = "ticketflow-tfstate-145400476932-us-east-1"
    key          = "bootstrap/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
