data "terraform_remote_state" "subzone" {
  backend = "s3"

  config = {
    bucket = "shopxpress-pro-tfstate-527055790396-apse1"
    key    = "15-r53-subzone/terraform.tfstate"
    region = "ap-southeast-1"
  }
}
