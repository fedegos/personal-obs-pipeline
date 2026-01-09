import hashlib
import pandas as pd

def generate_event_id(row):
    """Genera un hash determinista para identificar eventos únicos."""
    # Del proyecto de JupyterLab:
    # semilla = f"{row['Fecha Origen']}{row['Importe']}{row['Establecimiento']}{row['Numero Comprobante']}"

    string_base = f"{row['fecha_transaccion']}{row['monto']}{row['detalles']}{row['numero_operacion']}"
    return hashlib.sha256(string_base.encode()).hexdigest()

def apply_standard_format(df: pd.DataFrame) -> pd.DataFrame:
    """Asegura que todas las columnas tengan el nombre y tipo correcto."""
    df['fecha_transaccion'] = pd.to_datetime(df['fecha_transaccion'])
    df['monto'] = pd.to_numeric(df['monto'])
    df['detalles'] = df['detalles'].astype(str).str.strip()

    return df