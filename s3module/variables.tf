variable "bucket_name" {
  type        = string
  description = "The name of the S3 bucket"
  default     = "mykycdemotf"
}

variable "lambda_function_name" {
  type        = string
  description = "The name of the Lambda function"
  default     = "s3eventlambda"
}