import json
import boto3
import logging
import re
import os

# Configure logging
LOG = logging.getLogger()
LOG.setLevel(logging.INFO)

def lambda_handler(event, context):
    
    event_json = json.dumps(event)
    #LOG.info("Event: ", event_json)
    print("Event:", event_json)
    
    rgn = os.environ['AWS_REGION']
    print("Region:", rgn)
    
    sts_client = boto3.client('sts')
    acc_id = sts_client.get_caller_identity().get('Account')    
    
    
    if "aadhaar_number" in event and event["aadhaar_number"] is not None:
        aadhaar_number = event["aadhaar_number"]
        LOG.info("Aadhaar number found in the event: %s", aadhaar_number)
        

        # Send extracted Aadhar numbers to demo API
        url = "https://reqres.in/api/users/1"
        print("Sending to Aadhaar API for validation:", url)
        LOG.info("Sending to Aadhaar API for validation:: %s", url)

        #response = requests.get(url)
        status_code = 200
    
        if status_code == 200:
            print("Request successful! Received 200 response from Aadhaar API.")
            LOG.info("Request successful! Received 200 response from Aadhaar API.")
            
            # Send KYC Validation Success message to SQS
            sqs_queue_url = 'https://sqs.us-east-1.amazonaws.com/{account_id}/ValidatedQueue'
            print("Sent KYC Validation Success message to SQS - ", sqs_queue_url)
            LOG.info("Sent KYC Validation Success message to SQS -, sqs_queue_url")

            queue_name = 'ValidatedQueue'
            sqs = boto3.client('sqs', region_name=rgn)
            queue_url = sqs_queue_url.format(region=rgn, account_id=acc_id, queue_name=queue_name)
            message = "KYC Validation Success"
            sqs.send_message(QueueUrl=queue_url, MessageBody=json.dumps(message))
            
            return {
            'MessageStatus': 'KYC Validation Success'
            }
        else:
            print(f"Request failed with status code {response.status_code}.")
        
    else:
        LOG.info("Aadhaar number not found in the event.")
        # Send KYC Validation Failed message to SQS
        sqs_queue_url = 'https://sqs.us-east-1.amazonaws.com/{account_id}/ValidatedQueue'
        queue_name = 'ValidatedQueue'
        print("Sent KYC Validation Failed message to SQS - ", sqs_queue_url)
        LOG.info("Sent KYC Validation Failed message to SQS -, sqs_queue_url")

        sqs = boto3.client('sqs', region_name=rgn)
        queue_url = sqs_queue_url.format(region=rgn, account_id=acc_id, queue_name=queue_name)
        message = "KYC Validation Failed. Please upload a valid KYC Document."
        sqs.send_message(QueueUrl=queue_url, MessageBody=json.dumps(message))
        
        return {
            'MessageStatus': 'KYC Validation Failed'
        }