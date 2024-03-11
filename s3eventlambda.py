import boto3
import logging
import json

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)


def lambda_handler(event, context):
    # Get the S3 bucket name and object key from the event
    bucket_name = event['Records'][0]['s3']['bucket']['name']
    object_key = event['Records'][0]['s3']['object']['key']

    # Log the received event information
    logger.info(f'Received S3 event: Bucket={bucket_name}, Object={object_key}')

    # Create a Step Functions client
    sf_client = boto3.client('stepfunctions')

    # Start the Step Function execution and pass the S3 bucket name and object key as input
    execution_input = {
        'bucket': bucket_name,
        'key': object_key
    }

    try:
        state_machine_arn = boto3.client('cloudformation').describe_stacks(
            StackName='stepfunction-stack'
        )['Stacks'][0]['Outputs'][0]['OutputValue']  # Replace 'YOUR_CLOUDFORMATION_STACK_NAME' with the actual stack name

        response = sf_client.start_execution(
            stateMachineArn=state_machine_arn,
             # Optional: Provide a unique name for the execution
            input=json.dumps(execution_input)
        )
        logger.info(f'Step Function execution started: ExecutionArn={response["executionArn"]}')
    except Exception as e:
        logger.error(f'Failed to start Step Function execution: {str(e)}')
        raise

    return {
        'statusCode': 200,
        'body': json.dumps('Step Function execution started')
    }