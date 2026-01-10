# Diccionario global que almacenará las funciones de extracción registradas
_registry = {}

def register_extractor(bank_name):
    """
    Decorador con argumentos. 
    Primero recibe el nombre del banco, y luego la función.
    """
    def decorator(extractor_func):
        print (f"Extractor: {bank_name}")
        if bank_name in _registry:
            raise ValueError(f"Extractor '{bank_name}' ya está registrado.")
        _registry[bank_name] = extractor_func
        return extractor_func
    return decorator

def get_extractor(bank_name):
    """Lista todos los extractores disponibles"""
    extractor = _registry.get(bank_name)
    if not extractor:
        raise ValueError(f"Extractor para '{bank_name}' no encontrado.")
    return extractor

def list_extractors():
    """Lista todos los extractores disponibles"""
    return list(_registry.keys())

from . import visa_extractor
from . import amex_extractor