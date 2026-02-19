import boto3
import json
import os

DESTINATION_BUCKET = os.environ.get('DESTINATION_BUCKET')
REGION = os.environ.get('AWS_REGION', 'ap-southeast-2')
s3 = boto3.client('s3', region_name=REGION)

CORS_HEADERS = {
    "Access-Control-Allow-Origin": os.environ.get("CORS_ORIGIN", "*"),
    "Access-Control-Allow-Headers": "Content-Type,Authorization",
    "Access-Control-Allow-Methods": "GET,OPTIONS"
}

def handler(event, context):
    if event.get('httpMethod') == 'OPTIONS':
        return {"statusCode": 200, "headers": CORS_HEADERS, "body": ""}
    resp = s3.list_objects_v2(Bucket=DESTINATION_BUCKET)
    files = [obj['Key'] for obj in resp.get('Contents', []) if obj['Key'].lower().endswith('.jpg')]
    return {"statusCode": 200, "headers": CORS_HEADERS, "body": json.dumps({"files": files, "count": len(files)})}