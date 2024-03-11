package test

import (
	"fmt"
	"testing"

	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestInfrastructure(t *testing.T) {
	t.Parallel()

	// Generate a random suffix to avoid naming conflicts
	suffix := random.UniqueId()

	// Define the Terraform directory and variables
	terraformDir := "../"
	variables := map[string]interface{}{
		"bucket_name":            fmt.Sprintf("example-bucket-%s", suffix),
		"lambda_function_name":   fmt.Sprintf("s3eventlambda-%s", suffix),
		"runtime":                "python3.10",
		"filename":               "s3eventlambda.zip",
		"process_pdf_lambda":     "process_pdf_lambda.zip",
		"extract_data_lambda":    "extract_data_lambda.zip",
		"stepfunction_stack_name": fmt.Sprintf("stepfunction-stack-%s", suffix),
		"sqs_publish_role_name":  fmt.Sprintf("sqs-publish-role-%s", suffix),
		"region":                 aws.GetRandomRegion(t, nil, nil),
	}

	// Construct the Terraform options with variables
	terraformOptions := &terraform.Options{
		TerraformDir: terraformDir,
		Vars:         variables,
	}

	// Defer the destroy step to clean up resources
	defer terraform.Destroy(t, terraformOptions)

	// Initialize and apply the Terraform code
	terraform.InitAndApply(t, terraformOptions)

	// Get the outputs
	awsRegion := terraform.Output(t, terraformOptions, "aws_region")
	bucketName := terraform.Output(t, terraformOptions, "bucket_name")
	lambdaFunctionNames := terraform.OutputList(t, terraformOptions, "lambda_function_names")
	stepFunctionName := terraform.Output(t, terraformOptions, "stepfunction_name")
	sqsQueueArn := terraform.Output(t, terraformOptions, "sqs_queue_arn")
	snsTopicArn := terraform.Output(t, terraformOptions, "sns_topic_arn")

	// Test the infrastructure state
	t.Run("TestBucketExists", func(t *testing.T) {
		// Check if the S3 bucket exists
		exists := aws.AssertS3BucketExists(t, awsRegion, bucketName)
		assert.True(t, exists, "S3 bucket does not exist")
	})

	t.Run("TestLambdaFunctionsExist", func(t *testing.T) {
		// Check if the Lambda functions exist
		for _, functionName := range lambdaFunctionNames {
			exists := aws.AssertLambdaFunctionExists(t, awsRegion, functionName)
			assert.True(t, exists, "Lambda function does not exist")
		}
	})

	t.Run("TestStepFunctionExists", func(t *testing.T) {
		// Check if the Step Function exists
		exists := aws.AssertStepFunctionExists(t, awsRegion, stepFunctionName)
		assert.True(t, exists, "Step Function does not exist")
	})

	t.Run("TestSQSQueueExists", func(t *testing.T) {
		// Check if the SQS queue exists
		exists := aws.AssertSQSQueueExists(t, awsRegion, sqsQueueArn)
		assert.True(t, exists, "SQS queue does not exist")
	})

	t.Run("TestSNSTopicExists", func(t *testing.T) {
		// Check if the SNS topic exists
		exists := aws.AssertSNSTopicExists(t, awsRegion, snsTopicArn)
		assert.True(t, exists, "SNS topic does not exist")
	})
}
	
