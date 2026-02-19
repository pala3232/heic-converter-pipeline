import boto3
import tempfile
import os
import logging
import requests
import pillow_heif
from PIL import Image
from botocore.exceptions import ClientError
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime
import json

dynamodb_table = os.environ.get('DYNAMODB_TABLE', 'iosglacierbackups-jobs')
pillow_heif.register_heif_opener()
source_bucket = os.environ.get('SOURCE_BUCKET')
destination_bucket = os.environ.get('DESTINATION_BUCKET')
sqs_queue_url = os.environ.get('SQS_QUEUE_URL')
sns_topic_arn = os.environ.get('SNS_TOPIC_ARN')
s3_client = boto3.client('s3')
sqs_client = boto3.client('sqs')
dynamodb = boto3.resource('dynamodb')
sns_client = boto3.client('sns')
table = dynamodb.Table(dynamodb_table)


def create_presigned_url(bucket_name, object_name, expiration=3600):
    try:
        response = s3_client.generate_presigned_url(
            'get_object',
            Params={'Bucket': bucket_name, 'Key': object_name},
            ExpiresIn=expiration,
        )
    except ClientError as e:
        logging.error(e)
        return None
    return response


def convert_heic_to_jpg(heic_path, jpg_path):
    try:
        image = Image.open(heic_path)
        image.save(jpg_path, 'JPEG', quality=95)
        print(f"Successfully converted {heic_path} to {jpg_path}")
        print()
    except Exception as e:
        print(f"Conversion failed: {e}")


def already_processed(jpg_key):
    try:
        s3_client.head_object(Bucket=destination_bucket, Key=jpg_key)
        return True
    except ClientError as e:
        if e.response['Error']['Code'] == '404':
            return False
        raise


def update_job_status(job_id, status, key=None, error=None):
    item = {
        'job_id': job_id,
        'status': status,
        'timestamp': datetime.utcnow().isoformat()
    }
    if key:
        item['key'] = key
    if error:
        item['error'] = error
    table.put_item(Item=item)



def notify_batch_completion(total, succeeded, failed, succeeded_files, failed_files):
    subject = f"Batch Job Completed: {succeeded} succeeded, {failed} failed"
    message = (
        f"Batch processing complete.\n"
        f"Total: {total}\n"
        f"Succeeded: {succeeded}\n"
        f"Failed: {failed}\n\n"
        f"Succeeded files:\n" + ("\n".join(succeeded_files) if succeeded_files else "None") + "\n\n"
        f"Failed files:\n" + ("\n".join(failed_files) if failed_files else "None")
    )
    sns_client.publish(
        TopicArn=sns_topic_arn,
        Subject=subject,
        Message=message
    )


def process_and_upload(job_id, key, receipt_handle):
    jpg_key = os.path.splitext(key)[0] + '.jpg'

    if already_processed(jpg_key):
        print(f"Already processed, skipping: {key}")
        print()
        sqs_client.delete_message(QueueUrl=sqs_queue_url, ReceiptHandle=receipt_handle)
        return

    update_job_status(job_id, 'PROCESSING', key=key)

    url = create_presigned_url(source_bucket, key)
    if not url:
        print(f"Failed to generate presigned URL for {key}, skipping.")
        update_job_status(job_id, 'FAILED', key=key, error='Failed to generate presigned URL')
        return False, key

    with tempfile.NamedTemporaryFile(suffix='.heic', delete=False) as heic_tmp, \
         tempfile.NamedTemporaryFile(suffix='.jpg', delete=False) as jpg_tmp:
        heic_path = heic_tmp.name
        jpg_path = jpg_tmp.name

    try:
        # download HEIC
        response = requests.get(url)
        with open(heic_path, 'wb') as f:
            f.write(response.content)

        # convert
        convert_heic_to_jpg(heic_path, jpg_path)

        # upload JPG to destination bucket
        print(f"Uploading {jpg_key} to {destination_bucket}...")
        print()
        with open(jpg_path, 'rb') as f:
            s3_client.put_object(Bucket=destination_bucket, Key=jpg_key, Body=f, ContentType='image/jpeg')
        print(f"Done: {key} -> {jpg_key}\n")

        update_job_status(job_id, 'COMPLETED', key=key)

        # delete message after successful processing
        sqs_client.delete_message(QueueUrl=sqs_queue_url, ReceiptHandle=receipt_handle)
        print(f"Deleted message from queue: {key}")
        print()
        return True, key

    except Exception as e:
        update_job_status(job_id, 'FAILED', key=key, error=str(e))
        return False, key

    finally:
        if os.path.exists(heic_path):
            os.remove(heic_path)
        if os.path.exists(jpg_path):
            os.remove(jpg_path)


def main():
    print(f"================================================================")
    print(f"Polling SQS queue for messages...")
    print()


    total = 0
    succeeded = 0
    failed = 0
    succeeded_files = []
    failed_files = []

    while True:
        response = sqs_client.receive_message(
            QueueUrl=sqs_queue_url,
            MaxNumberOfMessages=10,
            WaitTimeSeconds=20
        )

        messages = response.get('Messages', [])
        if not messages:
            print("No more messages in queue, exiting.")
            break

        with ThreadPoolExecutor(max_workers=4) as executor:
            futures = []
            for message in messages:
                body = json.loads(message['Body'])
                key = body['key']
                job_id = body['job_id']
                print(f"Queuing for processing: {key} (job: {job_id})")
                futures.append(executor.submit(process_and_upload, job_id, key, message['ReceiptHandle']))
            for future in futures:
                result, key = future.result()
                total += 1
                if result:
                    succeeded += 1
                    succeeded_files.append(key)
                else:
                    failed += 1
                    failed_files.append(key)

    print(f"================================================================")
    notify_batch_completion(total, succeeded, failed, succeeded_files, failed_files)


if __name__ == '__main__':
    main()