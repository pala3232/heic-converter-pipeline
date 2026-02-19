import boto3
import json
import os
import uuid

dynamodb_table = os.environ.get('DYNAMODB_TABLE', 'iosglacierbackups-jobs')
sqs = boto3.client('sqs')
s3 = boto3.client('s3')
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(dynamodb_table)

QUEUE_URL          = os.environ.get('QUEUE_URL')
SOURCE_BUCKET      = os.environ.get('SOURCE_BUCKET')
DESTINATION_BUCKET = os.environ.get('DESTINATION_BUCKET')
ALLOWED_ORIGIN     = os.environ.get("CORS_ORIGIN", "*")

CORS_HEADERS = {
    "Access-Control-Allow-Origin":  ALLOWED_ORIGIN,
    "Access-Control-Allow-Headers": "Content-Type,Authorization",
    "Access-Control-Allow-Methods": "POST,OPTIONS"
}

def handler(event, context):
    if event.get("httpMethod") == "OPTIONS":
        return {"statusCode": 200, "headers": CORS_HEADERS, "body": ""}

    try:
        body   = json.loads(event['body'])
        key    = body['key']
        bucket = body.get('bucket', SOURCE_BUCKET)

        # Block conversion if output bucket still has files
        dest_check = s3.list_objects_v2(Bucket=DESTINATION_BUCKET)
        if dest_check.get('KeyCount', 0) > 0:
            return {
                'statusCode': 409,
                'headers': CORS_HEADERS,
                'body': json.dumps({'error': 'Output bucket is not empty. Download your converted files before starting a new batch.'})
            }

        job_id = str(uuid.uuid4())

        table.put_item(Item={
            'job_id': job_id,
            'status': 'PENDING',
            'key':    key,
            'bucket': bucket
        })

        sqs.send_message(
            QueueUrl=QUEUE_URL,
            MessageBody=json.dumps({
                'job_id': job_id,
                'bucket': bucket,
                'key':    key
            })
        )

        return {
            'statusCode': 200,
            'headers': CORS_HEADERS,
            'body': json.dumps({'job_id': job_id, 'status': 'PENDING'})
        }

    except Exception as e:
        return {
            'statusCode': 500,
            'headers': CORS_HEADERS,
            'body': json.dumps({'error': str(e)})
        }