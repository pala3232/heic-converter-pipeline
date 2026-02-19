import boto3
import json
import os

s3 = boto3.client("s3")
SOURCE_BUCKET = os.environ.get("SOURCE_BUCKET")

CORS_HEADERS = {
    "Access-Control-Allow-Origin": os.environ.get("CORS_ORIGIN", "*"),
    "Access-Control-Allow-Methods": "GET,OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type,Authorization"
}

def handler(event, context):
    if event.get("httpMethod") == "OPTIONS":
        return {"statusCode": 200, "headers": CORS_HEADERS, "body": ""}

    try:
        response = s3.list_objects_v2(Bucket=SOURCE_BUCKET)
        files = [
            obj["Key"] for obj in response.get("Contents", [])
            if obj["Key"].lower().endswith(".heic")
        ]
        return {
            "statusCode": 200,
            "headers": CORS_HEADERS,
            "body": json.dumps({"files": files})
        }
    except Exception as e:
        return {
            "statusCode": 500,
            "headers": CORS_HEADERS,
            "body": json.dumps({"error": str(e)})
        }