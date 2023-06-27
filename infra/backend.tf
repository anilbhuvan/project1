terraform {
  backend "s3" {
    bucket = "BUCKET_NAME_PLACEHOLDER"
    key = "main"
    region = "us-east-1"
    dynamodb_table = "lock-id-table" 
  }
}