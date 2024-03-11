output "bucket_name" {
  value = aws_s3_bucket.example_bucket.bucket
}

output "bucket_arn" {
  value = aws_s3_bucket.example_bucket.arn
}