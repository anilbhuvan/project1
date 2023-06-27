terraform {
  backend "s3" {
    bucket = var.bucket_name
    key = "main"
    region = "us-east-1"
    dynamodb_table = "lock-id-table" 
  }
}