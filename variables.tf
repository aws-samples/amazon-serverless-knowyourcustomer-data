variable "bucket_name" {
  type        = string
  description = "The name of the S3 bucket"
  default     = "mykycdemotf"
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "aws_region" {
  description = "AWS region for the resources"
  type        = string
  default     = "us-east-1"  # Default region if not specified
}

variable "lambda_function_name" {
  type        = string
  description = "The name of the Lambda function"
  default     = "s3eventlambda"
}

variable "runtime" {
  type        = string
  description = "The Lambda function runtime"
  default     = "python3.10"
}

variable "filename" {
  type        = string
  description = "The filename of the Lambda function code"
  default     = "s3eventlambda.zip"
}

variable "example_env_var" {
  type        = string
  description = "Example environment variable"
  default     = "example_value"
}

variable "process_pdf_lambda" {
  type        = string
  description = "The filename of the ProcessPDFLambda function code"
  default     = "process_pdf_lambda.zip"
}

variable "extract_data_lambda" {
  type        = string
  description = "The name of the ExtractDataLambda function"
  default     = "extract_data_lambda.zip"
}

variable "stepfunction_execution_role_name" {
  type        = string
  description = "The name of the Step Function execution role"
  default     = "stepfunction-execution-role"
}

variable "stepfunction_stack_name" {
  type        = string
  description = "The name of the Step Function stack"
  default     = "stepfunction-stack"
}

variable "sqs_publish_role_name" {
  type        = string
  description = "The name of the SQS role"
  default     = "sqs-publish-role"
}

variable "sqs_queue_name" {
  description = "Name of the SQS queue"
  type        = string
  default     = "ValidatedQueue"
}
