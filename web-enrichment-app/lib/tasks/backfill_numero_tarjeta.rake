# lib/tasks/backfill_numero_tarjeta.rake
namespace :data do
  desc "Backfill numero_tarjeta: Reprocesa transacciones_raw para completar numero_tarjeta en registros existentes"
  task backfill_numero_tarjeta: :environment do
    puts "🔄 Ejecutando backfill de numero_tarjeta..."
    DataBackfillService.backfill_numero_tarjeta
  end
  
  desc "Verificar estado de numero_tarjeta en transacciones"
  task check_numero_tarjeta: :environment do
    total = Transaction.count
    con_tarjeta = Transaction.where.not(numero_tarjeta: [nil, '']).count
    sin_tarjeta = Transaction.where(numero_tarjeta: [nil, '']).count
    
    puts "\n📊 Estado de numero_tarjeta:"
    puts "   Total transacciones: #{total}"
    puts "   ✅ Con numero_tarjeta: #{con_tarjeta} (#{(con_tarjeta.to_f / total * 100).round(1)}%)"
    puts "   ⚠️  Sin numero_tarjeta: #{sin_tarjeta} (#{(sin_tarjeta.to_f / total * 100).round(1)}%)"
  end
end
