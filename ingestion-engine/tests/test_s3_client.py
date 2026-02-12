"""Tests para utils/s3_client.py"""
from unittest.mock import patch


def test_get_s3_client_returns_boto_client():
    """Verifica que get_s3_client retorna un cliente boto3"""
    with patch.dict(
        "os.environ",
        {
            "AWS_ENDPOINT": "http://test:9000",
            "AWS_ACCESS_KEY_ID": "test_key",
            "AWS_SECRET_ACCESS_KEY": "test_secret",
            "AWS_REGION": "us-west-2",
        },
    ):
        from utils.s3_client import get_s3_client

        client = get_s3_client()
        assert client is not None
        # Verificar que es un cliente S3
        assert hasattr(client, "list_buckets")
        assert hasattr(client, "get_object")
        assert hasattr(client, "put_object")
