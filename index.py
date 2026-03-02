import boto3
import os

endpoint_url = os.environ.get('AWS_ENDPOINT_URL', "http://localhost:4566")
dynamodb = boto3.resource('dynamodb', endpoint_url=endpoint_url)

def handler(event, context):
    table = dynamodb.Table('LogsArquivos')

    for record in event['Records']:
        bucket = record['s3']['bucket']['name']
        key = record['s3']['object']['key']
        size = record['s3']['object']['size']

        print(f"Processando arquivo: {key}")

        # Gravando no DynamoDB
        table.put_item(
            Item={
                'ArquivoID': key,
                'Bucket': bucket,
                'Tamanho': size,
                'Status': 'Processado'
            }
        )

    return {'statusCode': 200}