# lib/tasks/data.rake
namespace :data do
  desc "Replay total: Limpia y sincroniza InfluxDB desde Postgres"
  task replay_clean: :environment do
    # Solo enviamos las aprobadas, que son las que tienen datos enriquecidos
    scope = Transaction.where(aprobado: true)
    total = scope.count
    
    puts "🚀 Iniciando Replay de #{total} transacciones..."
    
    scope.find_each.with_index do |t, i|
      payload = {
        event_id:      t.event_id,
        fecha:         t.fecha.iso8601,
        monto:         t.monto.to_f,
        moneda:        t.moneda,
        red:           t.red,
        # Estos son los mutables (Fields en Telegraf)
        detalles:      t.detalles,
        categoria:     t.categoria,
        sub_categoria: t.sub_categoria,
        sentimiento:   t.sentimiento,
        processed_at:  Time.current.iso8601
      }

      Karafka.producer.produce_async(
        topic: 'transacciones_clean',
        payload: payload.to_json,
        key: t.event_id
      )

      # Progreso visual en consola
      print "." if (i % 10).zero?
    end

    puts "\n✅ Replay completado con éxito."
  end
end