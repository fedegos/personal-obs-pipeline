# frozen_string_literal: true

# Recuperación desde transacciones_clean y regeneración desde transacciones_raw.
# Ver: DOCS/OPERATIONS.md — Recuperación y regeneración de transacciones.
namespace :data do
  desc "Recuperar transactions desde el tópico transacciones_clean (recovery desde eventos)"
  task recover_from_clean: :environment do
    RecoveryFromCleanService.run
  end

  desc "Borrar solo la tabla transactions (sin tocar SourceFile). Útil antes de regenerate-from-raw."
  task clean_transactions: :environment do
    count = Transaction.count
    Transaction.delete_all
    puts "🧹 Transacciones borradas: #{count}"
  end
end
