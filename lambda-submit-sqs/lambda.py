import boto3
import json
import os
import uuid

sqs = boto3.client('sqs')
dynamodb = boto3.resource('dynamodb')
table = os.environ.get('DYNAMODB_TABLE')
QUEUE_URL = os.environ.get('QUEUE_URL')
print(f"Lambda started. QUEUE_URL: {QUEUE_URL}")

def handler(event, context):
    print("Received event:", json.dumps(event))
    for record in event.get('Records', []):
        bucket = record.get('s3', {}).get('bucket', {}).get('name')
        key = record.get('s3', {}).get('object', {}).get('key')
        print(f"Processing record: bucket={bucket}, key={key}")

        if key and key.lower().endswith('.heic'):
            job_id = str(uuid.uuid4())

            # write PENDING to DynamoDB
            table.put_item(Item={
                'job_id': job_id,
                'status': 'PENDING',
                'key': key,
                'bucket': bucket
            })

            message = {
                'job_id': job_id,
                'bucket': bucket,
                'key': key
            }
            print(f"Sending message to SQS: {message}")
            response = sqs.send_message(
                QueueUrl=QUEUE_URL,
                MessageBody=json.dumps(message)
            )
            print(f"Queued job {job_id}: {key}, SQS response: {response}")
        else:
            print(f"Skipped file: {key}")