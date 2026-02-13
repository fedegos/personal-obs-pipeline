# frozen_string_literal: true

# Recuperación de la base de datos desde el tópico transacciones_clean.
# Rails no consume este tópico en tiempo real; este servicio permite repoblar
# la tabla transactions desde los eventos (event sourcing / recovery).
# Ver: DOCS/OPERATIONS.md — Recuperación y regeneración de transacciones.
class RecoveryFromCleanService
  class << self
    # Lee desde el inicio del tópico transacciones_clean y hace upsert por event_id.
    # Cada mensaje se aplica con apply_clean_message (idempotente).
    def run
      puts "🔄 Recuperación desde transacciones_clean..."
      puts "⚠️  Se crearán o actualizarán registros en transactions (aprobado: true)."
      puts "📥 Leyendo desde el inicio del tópico...\n"

      require "rdkafka"

      config = {
        "bootstrap.servers" => ENV.fetch("KAFKA_SERVERS", "redpanda:29092"),
        "group.id" => "recovery_from_clean_#{Time.now.to_i}",
        "auto.offset.reset" => "earliest",
        "enable.partition.eof" => false
      }

      consumer = Rdkafka::Config.new(config).consumer
      consumer.subscribe("transacciones_clean")

      created = 0
      updated = 0
      errors = 0
      processed = 0

      begin
        consumer.each do |message|
          processed += 1
          payload = JSON.parse(message.payload)
          transaction = apply_clean_message(payload)
          if transaction.previously_new_record?
            created += 1
            print "." if (created % 10).zero?
          else
            updated += 1
            print "+" if (updated % 50).zero?
          end
        rescue JSON::ParserError => e
          errors += 1
          puts "\n❌ JSON inválido (mensaje #{processed}): #{e.message}" if errors <= 5
        rescue => e
          errors += 1
          puts "\n❌ Error (mensaje #{processed}): #{e.message}" if errors <= 5
        end
        puts "\n📊 Progreso: #{processed} mensajes" if (processed % 500).zero? && processed.positive?
      rescue Interrupt
        puts "\n\n⏹️  Interrumpido por el usuario"
      rescue => e
        puts "\n❌ Error fatal: #{e.message}"
        puts e.backtrace.first(5).join("\n")
      ensure
        consumer.close
      end

      puts "\n\n✅ Recuperación completada:"
      puts "   📊 Procesados: #{processed}"
      puts "   ➕ Creados: #{created}"
      puts "   🔄 Actualizados: #{updated}"
      puts "   ❌ Errores: #{errors}"
    end

    # Aplica un mensaje TransaccionClean (payload hash) a un Transaction existente o nuevo.
    # No guarda; solo asigna atributos. Útil para tests y para run (que hace save después).
    def apply_clean_message(payload)
      transaction = Transaction.find_or_initialize_by(event_id: payload["event_id"].to_s)
      apply_clean_message_to(transaction, payload)
      transaction.save!
      transaction
    end

    # Asigna atributos de un payload TransaccionClean a un objeto Transaction (sin guardar).
    def apply_clean_message_to(transaction, payload)
      origen_val = payload["origen"].presence || "definitivo"
      origen_val = "definitivo" unless Transaction::ORIGEN_VALIDOS.include?(origen_val)

      transaction.assign_attributes(
        event_id: payload["event_id"].to_s,
        fecha: parse_fecha(payload["fecha"]),
        monto: payload["monto"].to_d,
        moneda: payload["moneda"],
        detalles: payload["detalles"],
        categoria: payload["categoria"],
        sub_categoria: payload["sub_categoria"],
        sentimiento: payload["sentimiento"],
        red: payload["red"],
        numero_tarjeta: payload["numero_tarjeta"],
        en_cuotas: payload["en_cuotas"].present? ? payload["en_cuotas"] : false,
        descripcion_cuota: payload["descripcion_cuota"],
        fecha_vencimiento: parse_fecha_vencimiento(payload["fecha_vencimiento"]),
        origen: origen_val,
        aprobado: true
      )
    end

    private

    def parse_fecha(value)
      return value if value.is_a?(ActiveSupport::TimeWithZone) || value.is_a?(Time)
      return nil if value.blank?

      Time.zone.parse(value.to_s)
    end

    def parse_fecha_vencimiento(value)
      return nil if value.blank?

      Date.parse(value.to_s)
    rescue ArgumentError
      nil
    end
  end
end
