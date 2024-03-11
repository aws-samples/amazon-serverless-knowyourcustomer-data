resource "aws_s3_bucket" "example_bucket" {
  bucket = var.bucket_name  # Update with your desired bucket name
  acl    = "private"
}

