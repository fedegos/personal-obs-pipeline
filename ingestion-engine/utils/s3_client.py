import os

import boto3
from dotenv import load_dotenv

load_dotenv() # Esto carga las variables del archivo .env al entorno

def get_s3_client():
       return boto3.client(
        's3',
        endpoint_url=os.getenv('AWS_ENDPOINT', 'http://s3-server:9000'),
        aws_access_key_id=os.getenv('AWS_ACCESS_KEY_ID'),
        aws_secret_access_key=os.getenv('AWS_SECRET_ACCESS_KEY'),
        region_name=os.getenv('AWS_REGION', 'us-east-1')
    )
