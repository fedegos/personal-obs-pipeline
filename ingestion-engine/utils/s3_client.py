import os
from dotenv import load_dotenv
import boto3

load_dotenv() # Esto carga las variables del archivo .env al entorno

def get_s3_client():
    if os.getenv("ENV") == "local":
        return boto3.client(
            "s3",
            endpoint_url="http://localhost:4566",
            aws_access_key_id=os.getenv("AWS_ACCESS_KEY_ID"),
            aws_secret_access_key=os.getenv("AWS_SECRET_ACCESS_KEY"),
            region_name="us-east-1"
        )
    return boto3.client("s3")