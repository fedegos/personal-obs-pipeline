# lib/tasks/data.rake
namespace :data do
  desc "Replay total: Sincroniza InfluxDB desde Postgres (Idempotente)"
  task replay_clean: :environment do
    scope = Transaction.where(aprobado: true)
    total = scope.count

    puts "🚀 Iniciando Replay idempotente de #{total} transacciones..."

    scope.find_each.with_index do |t, i|
      # Usamos el método unificado del Concern Publishable
      t.publish_clean_event

      print "." if (i % 10).zero?
    end

    puts "\n✅ Replay completado. InfluxDB debería estar actualizando los registros existentes."
  end
end
