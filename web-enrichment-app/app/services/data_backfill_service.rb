# app/services/data_backfill_service.rb
class DataBackfillService
  # Método principal: Reprocesa desde Kafka usando rdkafka (incluido en Karafka)
  def self.backfill_numero_tarjeta
    puts "🔄 Iniciando backfill de numero_tarjeta desde Kafka..."
    puts "⚠️  Este proceso actualizará solo el campo numero_tarjeta"
    puts "📥 Leyendo desde el inicio del tópico transacciones_raw...\n"
    
    require 'rdkafka'
    
    config = {
      "bootstrap.servers" => ENV.fetch('KAFKA_SERVERS', 'redpanda:29092'),
      "group.id" => "backfill_numero_tarjeta_#{Time.now.to_i}",
      "auto.offset.reset" => "earliest",
      "enable.partition.eof" => false
    }
    
    consumer = Rdkafka::Config.new(config).consumer
    consumer.subscribe('transacciones_raw')
    
    updated_count = 0
    skipped_count = 0
    error_count = 0
    processed_count = 0
    
    begin
      consumer.each do |message|
        begin
          processed_count += 1
          data = JSON.parse(message.payload)
          event_id = data['event_id']
          numero_tarjeta = data['numero_tarjeta']
          
          # Buscar la transacción existente
          transaction = Transaction.find_by(event_id: event_id)
          
          if transaction.nil?
            skipped_count += 1
            print "⏭️" if skipped_count % 100 == 0
            next
          end
          
          # Solo actualizar si numero_tarjeta está presente en el mensaje y falta en la DB
          if numero_tarjeta.present? && transaction.numero_tarjeta.blank?
            transaction.update_column(:numero_tarjeta, numero_tarjeta)
            updated_count += 1
            print "." if updated_count % 10 == 0
          elsif transaction.numero_tarjeta.present?
            skipped_count += 1
            print "✓" if skipped_count % 100 == 0
          else
            skipped_count += 1
            print "⏭️" if skipped_count % 100 == 0
          end
          
        rescue JSON::ParserError => e
          error_count += 1
          puts "\n❌ Error parseando JSON (mensaje #{processed_count}): #{e.message}" if error_count <= 5
        rescue => e
          error_count += 1
          puts "\n❌ Error procesando mensaje #{processed_count}: #{e.message}" if error_count <= 5
        end
        
        # Mostrar progreso cada 1000 mensajes
        if processed_count % 1000 == 0
          puts "\n📊 Progreso: #{processed_count} procesados, #{updated_count} actualizados, #{skipped_count} omitidos"
        end
      end
    rescue Interrupt
      puts "\n\n⏹️  Proceso interrumpido por el usuario"
    rescue => e
      puts "\n❌ Error fatal: #{e.message}"
      puts e.backtrace.first(5).join("\n")
    ensure
      consumer.close
    end
    
    puts "\n\n✅ Backfill completado:"
    puts "   📊 Total procesados: #{processed_count}"
    puts "   ✅ Actualizadas: #{updated_count}"
    puts "   ⏭️  Omitidas: #{skipped_count}"
    puts "   ❌ Errores: #{error_count}"
  end
  
  # Método alternativo: Actualizar desde transacciones que tienen red pero no numero_tarjeta
  # Útil si los mensajes de Kafka ya no están disponibles
  def self.backfill_from_source_files
    puts "🔄 Buscando transacciones sin numero_tarjeta..."
    
    transactions_sin_tarjeta = Transaction.where(numero_tarjeta: [nil, '']).where.not(red: [nil, ''])
    total = transactions_sin_tarjeta.count
    
    puts "📋 Encontradas #{total} transacciones sin numero_tarjeta"
    puts "⚠️  Esta opción requiere re-procesar los archivos originales desde S3"
    puts "   O usar la opción de rebobinar Kafka (método 1)"
    
    total
  end
end
