"""Configuración centralizada de logging para el ingestion engine."""

import logging
import os
import sys


def setup_logging(name: str = None) -> logging.Logger:
    """
    Configura y retorna un logger.

    Args:
        name: Nombre del módulo. Si es None, configura el root logger.

    Returns:
        Logger configurado.
    """
    log_level = os.getenv("LOG_LEVEL", "INFO").upper()
    logger = logging.getLogger(name)

    if not logger.handlers:
        handler = logging.StreamHandler(sys.stdout)
        formatter = logging.Formatter(
            "%(asctime)s - %(name)s - %(levelname)s - %(message)s",
            datefmt="%Y-%m-%d %H:%M:%S",
        )
        handler.setFormatter(formatter)
        logger.addHandler(handler)

    logger.setLevel(getattr(logging, log_level, logging.INFO))
    return logger


def get_logger(name: str) -> logging.Logger:
    """
    Obtiene un logger para el módulo especificado.

    Args:
        name: Nombre del módulo (usar __name__).

    Returns:
        Logger configurado.
    """
    return setup_logging(name)
