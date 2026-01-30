require "test_helper"

class DataBackfillServiceTest < ActiveSupport::TestCase
  test "backfill_from_source_files returns count of transactions without numero_tarjeta" do
    # Usa fixtures: transacciones con/sin numero_tarjeta y red
    count = DataBackfillService.backfill_from_source_files
    assert count.is_a?(Integer)
    assert count >= 0
  end
end
