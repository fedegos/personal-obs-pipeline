require "test_helper"

class SentimentServiceTest < ActiveSupport::TestCase
  test "analyze returns Deseo for blank text" do
    assert_equal "Deseo", SentimentService.analyze("")
    assert_equal "Deseo", SentimentService.analyze(nil)
  end

  test "analyze returns sentimiento from categorizer when valid" do
    # Stub CategorizerService.guess para devolver un sentimiento válido
    original_guess = CategorizerService.method(:guess)
    CategorizerService.define_singleton_method(:guess) { |_text| { sentimiento: "Necesario" } }
    begin
      assert_equal "Necesario", SentimentService.analyze("cualquier texto")
    ensure
      CategorizerService.define_singleton_method(:guess) { |*args| original_guess.call(*args) }
    end
  end

  test "analyze returns Deseo when categorizer sentimiento not in SENTIMIENTOS" do
    original_guess = CategorizerService.method(:guess)
    CategorizerService.define_singleton_method(:guess) { |_text| { sentimiento: "Invalido" } }
    begin
      # "Invalido" no está en Transaction::SENTIMIENTOS, debe fallback a Deseo
      assert_equal "Deseo", SentimentService.analyze("texto")
    ensure
      CategorizerService.define_singleton_method(:guess) { |*args| original_guess.call(*args) }
    end
  end

  test "analyze returns Deseo when categorizer returns nil sentimiento" do
    original_guess = CategorizerService.method(:guess)
    CategorizerService.define_singleton_method(:guess) { |_text| { sentimiento: nil } }
    begin
      assert_equal "Deseo", SentimentService.analyze("texto")
    ensure
      CategorizerService.define_singleton_method(:guess) { |*args| original_guess.call(*args) }
    end
  end
end
