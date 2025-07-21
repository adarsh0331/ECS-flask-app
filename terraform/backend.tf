terraform {
  backend "s3" {
    bucket         = "terraform-state-python1"
    key            = "greeting-app/terraform.tfstate"
    region         = "ca-central-1"
    encrypt        = true

    # Optional: state locking with DynamoDB
    #dynamodb_table = "terraform-locks"
  }
}
