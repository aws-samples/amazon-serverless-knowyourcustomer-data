provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

module "s3module" {
  source      = "./s3module"
  bucket_name = var.bucket_name
}

resource "aws_s3_bucket_notification" "example_bucket_notification" {
  bucket = module.s3module.bucket_name

  lambda_function {
    lambda_function_arn = aws_lambda_function.s3eventlambda.arn
    events              = ["s3:ObjectCreated:*"]
    filter_suffix       = ".pdf"  # Update with the desired suffix
  }
}

resource "aws_iam_role" "lambda_exec" {
  name = "lambda-exec-role"
  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "Service": "lambda.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
      }
    ]
  })
}


resource "aws_iam_policy" "lambda_basic_execution_policy" {
  name        = "lambda-basic-execution-policy"
  description = "Allows basic Lambda execution permissions"
  policy      = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*"
    },
    {
      "Effect": "Allow",
      "Action": "cloudformation:DescribeStacks",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "logs:CreateLogGroup",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource":"arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/s3eventlambda:*"            
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:*",
        "s3-object-lambda:*"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "states:*",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "lambda_exec_basic_policy_attachment" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.lambda_basic_execution_policy.arn
}

resource "aws_iam_policy" "lambda_s3_policy" {
  name   = "lambda-s3-policy"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "s3:*",           
      "Resource": "${module.s3module.bucket_arn}/*"
    },
    {
      "Effect": "Allow",
      "Action": "states:*",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "textract:*",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "sqs:*",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_policy_attachment" "lambda_s3_policy_attachment" {
  name       = "lambda-s3-policy-attachment"
  roles      = [aws_iam_role.lambda_exec.name]
  policy_arn = aws_iam_policy.lambda_s3_policy.arn
}

resource "aws_lambda_function" "s3eventlambda" {
  function_name = var.lambda_function_name  # Update with your desired Lambda function name
  role          = aws_iam_role.lambda_exec.arn
  runtime       = var.runtime  # Update with your desired runtime
  handler       = "s3eventlambda.lambda_handler"
  filename      = var.filename # Update with the filename of your Lambda function code  
  timeout       = 600  # Set the timeout to 10 minutes (600 seconds)
  memory_size   = 2048  # Set the memory size to 2048 MB
}
  
resource "aws_lambda_function" "process_pdf_lambda" {
  function_name = "ProcessPDFLambda"  # Update with your desired Lambda function name
  role          = aws_iam_role.lambda_exec.arn
  runtime       = var.runtime  # Update with your desired runtime
  handler       = "process_pdf_lambda.lambda_handler"
  filename      = var.process_pdf_lambda  # Update with the filename of your ProcessPDFLambda function code  
  timeout       = 600  # Set the timeout to 10 minutes (600 seconds)
  memory_size   = 2048  # Set the memory size to 2048 MB
}  

resource "aws_lambda_function" "extract_data_lambda" {
  function_name = "ExtractDataLambda"  # Update with your desired Lambda function name
  role          = aws_iam_role.lambda_exec.arn
  runtime       = var.runtime  # Update with your desired runtime
  handler       = "extract_data_lambda.lambda_handler"
  filename      = var.extract_data_lambda  # Update with the filename of your ExtractDataLambda function code  
  timeout       = 600  # Set the timeout to 10 minutes (600 seconds)
  memory_size   = 2048  # Set the memory size to 2048 MB    
}

resource "aws_iam_policy_attachment" "process_pdf_lambda_policy_attachment" {
  name       = "process-pdf-lambda-policy-attachment"
  roles      = [aws_iam_role.lambda_exec.name]
  policy_arn = aws_iam_policy.lambda_s3_policy.arn
}

resource "aws_iam_policy_attachment" "extract_data_lambda_policy_attachment" {
  name       = "extract-data-lambda-policy-attachment"
  roles      = [aws_iam_role.lambda_exec.name]
  policy_arn = aws_iam_policy.lambda_s3_policy.arn
}

resource "aws_lambda_permission" "s3_bucket_permission" {
  statement_id  = "AllowS3Invocation"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.s3eventlambda.function_name
  principal     = "s3.amazonaws.com"
  source_arn = module.s3module.bucket_arn
}

resource "aws_cloudwatch_event_rule" "s3_event_rule" {
  name        = "s3_event_rule"
  description = "Trigger Lambda function on S3 event"
  event_pattern = <<EOF
{
  "source": ["aws.s3"],
  "detail-type": ["AWS API Call via CloudTrail"],
  "detail": {
    "eventSource": ["s3.amazonaws.com"],
    "eventName": ["PutObject"],
    "requestParameters": {
      "bucketName": ["${module.s3module.bucket_name}"],
      "key": [
        {
          "prefix": "pdf/"
        }
      ]
    }
  }
}
EOF
}

resource "aws_cloudwatch_event_target" "s3_event_target" {
  rule      = aws_cloudwatch_event_rule.s3_event_rule.name
  target_id = "s3_event_target"
  arn       = aws_lambda_function.s3eventlambda.arn
}

resource "aws_iam_role" "stepfunction_execution_role" {
  name = var.stepfunction_execution_role_name

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "states.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_policy" "stepfunction_execution_policy" {
  name        = "stepfunction-execution-policy"
  policy      = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "states:*",
        "sqs:*",
        "s3:*",
        "textract:*",
        "lambda:*",
        "logs:*"        
      ],
      "Resource": [
        "*",
        "arn:aws:lambda:${var.region}:${data.aws_caller_identity.current.account_id}:function:${var.extract_data_lambda}:*",
        "arn:aws:lambda:${var.region}:${data.aws_caller_identity.current.account_id}:function:${var.process_pdf_lambda}:*"
      ]
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "stepfunction_execution_policy_attachment" {
  role       = aws_iam_role.stepfunction_execution_role.name
  policy_arn = aws_iam_policy.stepfunction_execution_policy.arn
}

locals {
  execution_id = uuid()
}
resource "aws_cloudformation_stack" "stepfunction_stack" {
  name          = var.stepfunction_stack_name
  template_body = <<-EOF
    Resources:
      StepFunctionExample:
        Type: AWS::StepFunctions::StateMachine
        Properties:
          StateMachineName: "ExtractAadharPhoneStep-${local.execution_id}"
          StateMachineType: "EXPRESS"
          RoleArn: ${aws_iam_role.stepfunction_execution_role.arn}                    
          DefinitionString: |
            ${jsonencode({
              "Comment": "Extract Aadhar and Phone Number from PDF",
              "StartAt": "ProcessPDF",
              "States": {
                "ProcessPDF": {
                  "Resource": "arn:aws:states:::lambda:invoke",
                  "Type": "Task",                                                      
                  "OutputPath": "$.Payload",
                  "Parameters": {
                    "Payload.$": "$",
                    "FunctionName": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:ProcessPDFLambda:$LATEST"                    
                  },                 
                  "Next": "ExtractData"                                    
                },                    
                "ExtractData": {                  
                  "Type": "Task",
                  "Resource": "arn:aws:states:::lambda:invoke",                                    
                  "OutputPath": "$.Payload",
                  "Parameters": {
                    "Payload.$": "$",                  
                    "FunctionName": "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:ExtractDataLambda:$LATEST"                                        
                  },                  
                  "End": true
                }
              }
            })}    
    Outputs:
      StepFunctionArn:
        Value: !Ref StepFunctionExample
        Export:
          Name: ExtractAadharPhoneStepArn
  EOF

  capabilities = ["CAPABILITY_NAMED_IAM"]  
}

resource "aws_sqs_queue" "validated_queue" {
  name   = "ValidatedQueue"
  visibility_timeout_seconds = 600
}

resource "aws_iam_role" "sqs_publish_role" {
  name = var.sqs_publish_role_name

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_policy" "sqs_publish_policy" {
  name   = "sqs-publish-policy"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "sqs:SendMessage",
      "Resource": "${aws_sqs_queue.validated_queue.arn}"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "sqs_publish_policy_attachment" {
  role       = aws_iam_role.sqs_publish_role.name
  policy_arn = aws_iam_policy.sqs_publish_policy.arn
}

resource "aws_lambda_permission" "extract_data_lambda_sqs_permission" {
  statement_id  = "AllowSQSInvocation"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.extract_data_lambda.function_name
  principal     = "sqs.amazonaws.com"

  source_arn = aws_sqs_queue.validated_queue.arn
}

resource "aws_sns_topic" "notifyusers" {
  name = "notifyusers"
}

resource "aws_sns_topic_subscription" "sqs_subscription" {
  topic_arn = aws_sns_topic.notifyusers.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.validated_queue.arn
}

#Outputs
output "aws_region" {
  value = data.aws_region.current.name
}

output "bucket_name" {
  value = module.s3module.bucket_name
}

output "lambda_function_names" {
  value = [
    aws_lambda_function.s3eventlambda.function_name,
    aws_lambda_function.process_pdf_lambda.function_name,
    aws_lambda_function.extract_data_lambda.function_name
  ]
}
output "stepfunction_name" {
  value = aws_cloudformation_stack.stepfunction_stack.name
}

output "sqs_queue_arn" {
  value = aws_sqs_queue.validated_queue.arn
}

output "sns_topic_arn" {
  value = aws_sns_topic.notifyusers.arn
}
