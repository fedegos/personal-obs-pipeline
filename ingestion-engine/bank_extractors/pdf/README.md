# Extractores PDF - Fecha de vencimiento

## Patrones de extracción por banco

Los extractores pueden implementar `_extract_fecha_vencimiento(text, **kwargs)` para extraer la fecha de cierre o vencimiento del resumen.

| Banco | Patrón | Ejemplo |
|-------|--------|---------|
| **AMEX** | `Vencimiento : DD/MM/YY` | Vencimiento : 27/11/25 |
| **BBVA** | `Vto./Vencimiento/Cierre` + `DD/MM/YY` | Vto. 15/02/26 |
| **BAPRO** | `Prox.Vto. DD/MM` o `DD/MM/YY` | Prox.Vto. 15/02/26 |

## Uso

- La fecha se añade a todas las filas del DataFrame cuando se extrae correctamente.
- Si el PDF no contiene el patrón, `fecha_vencimiento` no se incluye (opcional).
- Para cargas Excel/CSV, `fecha_vencimiento` puede venir desde la UI (`params`) en el evento `file_uploaded`.
