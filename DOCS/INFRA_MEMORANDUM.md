# 📕 Proyecto Audit-X: Resumen de Infraestructura y Backups

> **Nota:** Guarda este contenido en un archivo llamado `INFRA_STATE.md` en la raíz de tu proyecto para que siempre tengamos una referencia de lo que se configuró.

---

## 1. Script de Backup Automatizado (`backup.sh`)
Copia este contenido en `~/scripts/backups/backup.sh` en tu servidor:

```bash
#!/bin/bash

# --- CONFIGURACIÓN ---
TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
BACKUP_NAME="backup_audit_x_$TIMESTAMP.sql.gz"
CONTAINER_DB="a0d3b4dd8d3a"
S3_BUCKET="backups-proyecto"

# Credenciales MinIO (¡Cámbialas por las tuyas!)
MINIO_URL="http://localhost:9000"
MINIO_ACCESS_KEY="TU_ACCESS_KEY"
MINIO_SECRET_KEY="TU_SECRET_KEY"

echo "📦 Iniciando dump de base de datos..."
docker exec $CONTAINER_DB pg_dump -U postgres audit_x_prod | gzip > /tmp/$BACKUP_NAME

echo "🚀 Subiendo a MinIO..."
docker run --rm --network host \
  -v /tmp/$BACKUP_NAME:/tmp/$BACKUP_NAME \
  minio/mc:latest /bin/sh -c "
    mc alias set myminio $MINIO_URL $MINIO_ACCESS_KEY $MINIO_SECRET_KEY;
    mc cp /tmp/$BACKUP_NAME myminio/$S3_BUCKET/;
    mc rm --recursive --force --older-than 30d myminio/$S3_BUCKET/
  "

rm /tmp/$BACKUP_NAME
echo "✅ Backup completado: $BACKUP_NAME"
```

Para restaurar desde un backup en producción: mismo flujo que en desarrollo (`pg_restore` o `psql < backup.sql` contra la DB de producción), con ventana de mantenimiento. Ver [DOCS/OPERATIONS.md](OPERATIONS.md) (sección Backup y restauración).

---

## 2. Migración Definitiva (Solid Cable)
Si necesitas regenerar la base de datos o el entorno de desarrollo, este es el código que debe ir en `db/migrate/XXXXXXXX_create_solid_cable_messages.rb`:

```ruby
class CreateSolidCableMessages < ActiveRecord::Migration[8.0]
  def change
    create_table :solid_cable_messages do |t|
      t.binary :channel, null: false, limit: 1024
      t.binary :payload, null: false, limit: 536870912
      t.datetime :created_at, precision: 6, null: false
      t.integer :channel_hash, limit: 8, null: false 

      t.index :channel
      t.index :channel_hash
      t.index :created_at
    end
  end
end
```

---

## 3. Estado de la Red Docker (Producción)
* **Postgres ID:** `a0d3b4dd8d3a` (Puerto 5432)
* **Redis ID:** `6925aace30e6` (Puerto 6379)
* **Karafka Server:** `csg0k4ckwg0w4cw4s0_karafka_server`
* **Status:** Parche de `channel_hash` aplicado manualmente vía SQL el 22/01/2026.
