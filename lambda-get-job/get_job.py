import boto3
import json
from decimal import Decimal
import os

dynamodb_table = os.environ.get('DYNAMODB_TABLE', 'iosglacierbackups-jobs')
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(dynamodb_table)

CORS_HEADERS = {
    "Access-Control-Allow-Origin": os.environ.get("CORS_ORIGIN", "*"),
    "Access-Control-Allow-Headers": "Content-Type,Authorization",
    "Access-Control-Allow-Methods": "GET,OPTIONS"
}

class DecimalEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, Decimal):
            return str(obj)
        return super().default(obj)

def handler(event, context):
    print("Event:", json.dumps(event))

    if event.get('httpMethod') == 'OPTIONS':
        return {"statusCode": 200, "headers": CORS_HEADERS, "body": ""}

    try:
        path_params = event.get('pathParameters') or {}
        job_id = path_params.get('id')  # matches {id} in tf

        if not job_id:
            return {
                "statusCode": 400,
                "headers": CORS_HEADERS,
                "body": json.dumps({"error": "Missing id in path"})
            }

        response = table.get_item(Key={'job_id': job_id})
        item = response.get('Item')

        if not item:
            return {
                "statusCode": 404,
                "headers": CORS_HEADERS,
                "body": json.dumps({"error": f"Job not found: {job_id}"})
            }

        return {
            "statusCode": 200,
            "headers": CORS_HEADERS,
            "body": json.dumps(item, cls=DecimalEncoder)
        }

    except Exception as e:
        print(f"Error: {e}")
        return {
            "statusCode": 500,
            "headers": CORS_HEADERS,
            "body": json.dumps({"error": str(e)})
        }