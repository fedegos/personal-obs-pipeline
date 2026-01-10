from bank_extractors import get_extractor, list_extractors
from utils.data_standardizer import generate_event_id
import pandas as pd

def test_extraction(bank_name, file_path):
    print(f"--- Probando Extractor: {bank_name} ---")
    try:
        # 1. Obtener extractor
        extractor_func = get_extractor(bank_name)
        
        # 2. Ejecutar extracción
        df = extractor_func(file_path)
        
        # 3. Aplicar lógica de secuencia e ID (Copia de main.py)
        # df['secuencia'] = df.groupby(['fecha_transaccion', 'monto', 'detalles']).cumcount()
        df['event_id'] = df.apply(generate_event_id, axis=1)
        
        # 4. Mostrar resultados
        print("\nPrimeras filas del resultado estandarizado:")
        print(df.head())
        
        print("\nTipos de datos:")
        print(df.dtypes)
        
        print(f"\n✅ Éxito: Se procesaron {len(df)} registros.")

        for _, row in df.iterrows():
            print(f"Evento enviado: ${row.to_dict()}")
            
    except Exception as e:
        print("\n❌ ERROR DETALLADO:")
        # Esto imprimirá la secuencia de comandos que falló
        traceback.print_exc() 

if __name__ == "__main__":
    print(f"Extractores registrados: {list_extractors()}")
    # Ajusta la ruta al archivo que creaste
    test_extraction('visa', '../data/input/Movimientos_bbva.csv')
    test_extraction('visa', '../data/input/Movimientos_bapro.csv')
    test_extraction('amex', 'AMEX')