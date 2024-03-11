import boto3
import re
import logging

# Configure logging
LOG = logging.getLogger()
LOG.setLevel(logging.INFO)


def lambda_handler(event, context):
    # Extract S3 bucket, key, and file name from the incoming event
    bucket_name = event['bucket']
    object_key = event['key']

    LOG.info(f"File name is {object_key}")

    # Call Amazon Textract
    textract_client = boto3.client('textract')

    response = None  # Initialize response with a default value

    try:
        response = textract_client.detect_document_text(
            Document={"S3Object": {"Bucket": bucket_name, "Name": object_key}}
        )
    except textract_client.exceptions.UnsupportedDocumentException as e:
        LOG.error(f"Unsupported document format: {str(e)}")

    LOG.info("Response from Textract is %s", response)
    print("Response from Textract is ", response)

    if response is not None:
        # Extract text blocks from Textract response
        blocks = response["Blocks"]
        text_blocks = [block for block in blocks if block["BlockType"] == "LINE"]

        # Extract text from text blocks
        text = [block["Text"] for block in text_blocks]

        LOG.info("Text is %s", text)
        print("Text is ", text)

        # Find Aadhaar number with 3 groups of digits separated by spaces
        aadhaar_number = None

        for block in text:
            # Aadhaar number pattern: 3 groups of digits separated by spaces
            aadhaar_pattern = r'\b\d{4} \d{4} \d{4}\b'
            aadhaar_match = re.search(aadhaar_pattern, block)
            if aadhaar_match:
                aadhaar_number = aadhaar_match.group()
                break
            else:
                LOG.info("Aadhaar number not found %s", aadhaar_number)

        LOG.info("Found Aadhaar number - %s", aadhaar_number)
        print("Found Aadhaar number - ", aadhaar_number)

        # Send a message if Aadhaar number is not found
        if aadhaar_number is None:
            LOG.info("Not a valid Aadhaar card.")
            error_message = "Not a valid Aadhaar card."
            LOG.info("Step Function execution stopped")
            return {
                "aadhaar_number": None,
                "error_message": error_message
            }

        # Return the extracted Aadhaar number
        return {
            "aadhaar_number": aadhaar_number
        }
    else:
        LOG.info("Response is None. Unable to process document.")
        return {
            "aadhaar_number": None,
            "error_message": "Unable to process document"
        }