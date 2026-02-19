import boto3
import json
import os
from botocore.config import Config

DESTINATION_BUCKET = os.environ.get('DESTINATION_BUCKET')
REGION = os.environ.get('AWS_REGION', 'ap-southeast-2')
s3 = boto3.client('s3', region_name=REGION,
    endpoint_url=f"https://s3.{REGION}.amazonaws.com",
    config=Config(signature_version='s3v4'))

CORS_HEADERS = {
    "Access-Control-Allow-Origin": os.environ.get("CORS_ORIGIN", "*"),
    "Access-Control-Allow-Headers": "Content-Type,Authorization",
    "Access-Control-Allow-Methods": "GET,OPTIONS"
}

def handler(event, context):
    if event.get('httpMethod') == 'OPTIONS':
        return {"statusCode": 200, "headers": CORS_HEADERS, "body": ""}
    key = (event.get('queryStringParameters') or {}).get('key')
    if not key:
        return {"statusCode": 400, "headers": CORS_HEADERS, "body": json.dumps({"error": "key required"})}
    url = s3.generate_presigned_url('get_object',
        Params={'Bucket': DESTINATION_BUCKET, 'Key': key},
        ExpiresIn=3600)
    return {"statusCode": 200, "headers": CORS_HEADERS, "body": json.dumps({"url": url})}