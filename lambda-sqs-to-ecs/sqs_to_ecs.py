import boto3
import os
import json

print("Lambda cold start - code loaded")

def handler(event, context):
    print("Handler invoked")
    print("Received event:", json.dumps(event))
    try:
        cluster_arn = os.environ.get('CLUSTER_ARN')
        task_definition = os.environ.get('TASK_DEFINITION')
        subnet_id = os.environ.get('SUBNET_ID')
        security_group_id = os.environ.get('SECURITY_GROUP_ID')
        sqs_queue_url = os.environ.get('SQS_QUEUE_URL')
        print(f"ENV: CLUSTER_ARN={cluster_arn}, TASK_DEFINITION={task_definition}, SUBNET_ID={subnet_id}, SECURITY_GROUP_ID={security_group_id}, SQS_QUEUE_URL={sqs_queue_url}")

        
        sqs = boto3.client('sqs')
        sqs_response = sqs.receive_message(
            QueueUrl=sqs_queue_url,
            MaxNumberOfMessages=1,
            WaitTimeSeconds=1
        )
        messages = sqs_response.get('Messages', [])
        if not messages:
            print("No messages in SQS queue. Skipping ECS task launch.")
            return {"status": "skipped", "reason": "no messages in queue"}

        ecs = boto3.client('ecs')
        response = ecs.run_task(
            cluster=cluster_arn,
            taskDefinition=task_definition,
            launchType='FARGATE',
            networkConfiguration={
                'awsvpcConfiguration': {
                    'subnets': [subnet_id],
                    'securityGroups': [security_group_id],
                    'assignPublicIp': 'ENABLED'
                }
            }
        )
        print("ECS run_task response:", response)
    except Exception as e:
        print(f"Error running ECS task: {e}")