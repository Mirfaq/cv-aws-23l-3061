import boto3
import json
import time
import os
import base64

s3 = boto3.client('s3')
BUCKET = os.environ['BUCKET']
PREFIX = os.environ['PREFIX']

def lambda_handler(event, context):
    start = time.time()
    path = event.get('rawPath', '/')
    function_name = context.function_name

    try:
        if path in ('/', '/index.html'):
            obj = s3.get_object(Bucket=BUCKET, Key=f"{PREFIX}index.html")
            body = obj['Body'].read().decode('utf-8')
            body = body.replace('{{HOSTED_ON}}', f'Lambda {function_name}')
            response = {
                'statusCode': 200,
                'headers': {
                    'Content-Type': 'text/html',
                    'Cache-Control': 'max-age=60'
                },
                'body': body
            }

        elif path == '/style.css':
            obj = s3.get_object(Bucket=BUCKET, Key=f"{PREFIX}style.css")
            body = obj['Body'].read().decode('utf-8')
            response = {
                'statusCode': 200,
                'headers': {'Content-Type': 'text/css'},
                'body': body
            }

        elif path == '/cv.pdf':
            obj = s3.get_object(Bucket=BUCKET, Key=f"{PREFIX}cv.pdf")
            body = base64.b64encode(obj['Body'].read()).decode('utf-8')
            response = {
                'statusCode': 200,
                'headers': {'Content-Type': 'application/pdf'},
                'body': body,
                'isBase64Encoded': True
            }

        else:
            response = {
                'statusCode': 404,
                'headers': {'Content-Type': 'text/html'},
                'body': '<html><body><h1>404 Not Found</h1></body></html>'
            }

    except Exception as e:
        response = {
            'statusCode': 404,
            'headers': {'Content-Type': 'text/html'},
            'body': '<html><body><h1>404 Not Found</h1></body></html>'
        }

    ms = int((time.time() - start) * 1000)
    log_entry = {
        'fn': function_name,
        'path': path,
        'status': response['statusCode'],
        'ms': ms
    }
    print(json.dumps(log_entry))

    return response
