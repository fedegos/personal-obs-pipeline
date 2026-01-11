from utils.s3_client import get_s3_client

def upload_test_file():
    s3 = get_s3_client()
    # Crear el bucket si no existe
    s3.create_bucket(Bucket='bank-ingestion')
    # Subir un archivo local para simular el origen
    s3.upload_file('../data/input/Movimientos_bbva.csv', 'bank-ingestion', 'raw/Movimientos_bbva.csv')
    s3.upload_file('../data/input/Movimientos_bapro.csv', 'bank-ingestion', 'raw/Movimientos_bapro.csv')

if __name__ == "__main__":
    upload_test_file()
