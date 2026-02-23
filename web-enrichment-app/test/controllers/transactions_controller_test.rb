require "test_helper"

class TransactionsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  fixtures :users, :transactions, :category_rules

  setup do
    sign_in users(:one)
    @transaction = transactions(:one)
    CategorizerService.clear_cache
  end

  test "should get index" do
    get transactions_url
    assert_response :success
  end

  test "index paginates pending transactions to 50 records" do
    Transaction.where(aprobado: false).update_all(aprobado: true)
    55.times { |i| create_pending_transaction(i, detalles: "Bulk #{i}") }

    get transactions_url
    assert_response :success

    assert_select "#transactions-container .transaction-card", count: 50
    assert_select "#transactions-next-page .transactions-pagination-container", count: 1
    assert_select "button", text: "Cargar más"
  end

  test "index turbo_stream appends next page and preserves filters" do
    Transaction.where(aprobado: false).update_all(aprobado: true)
    120.times { |i| create_pending_transaction(i, detalles: "Alpha #{i}") }

    get transactions_url(format: :turbo_stream), params: { page: 2, q: "Alpha", sort: "monto_desc", monto_min: "10" }
    assert_response :success

    assert_includes @response.body, 'turbo-stream action="append" target="transactions-container"'
    assert_includes @response.body, "q=Alpha"
    assert_includes @response.body, "sort=monto_desc"
    assert_includes @response.body, "monto_min=10"
  end

  test "should update transaction and set manually_edited" do
    @transaction.update!(aprobado: false)
    patch transaction_url(@transaction), params: {
      transaction: { categoria: "Hogar", sub_categoria: "Luz", sentimiento: "Necesario" }
    }, as: :json
    assert_response :success
    @transaction.reload
    assert_equal "Hogar", @transaction.categoria
    assert @transaction.manually_edited?
  end

  test "should not update approved transaction" do
    approved = transactions(:approved)
    patch transaction_url(approved), params: {
      transaction: { categoria: "Otro" }
    }, as: :json
    assert_response :forbidden
  end

  test "should approve transaction" do
    patch approve_transaction_url(@transaction), params: {
      transaction: {
        categoria: @transaction.categoria,
        sub_categoria: @transaction.sub_categoria,
        sentimiento: @transaction.sentimiento
      }
    }
    assert_redirected_to transactions_path
    assert_equal "Aprobado.", flash[:notice]
    @transaction.reload
    assert @transaction.aprobado?
  end

  test "should filter by search query" do
    get transactions_url, params: { q: "Detalle" }
    assert_response :success
  end

  test "should filter by fecha" do
    get transactions_url, params: { fecha: @transaction.fecha.to_date }
    assert_response :success
  end

  test "should filter by monto range" do
    get transactions_url, params: { monto_min: 1, monto_max: 100 }
    assert_response :success
  end

  test "should sort by faciles_primero" do
    get transactions_url, params: { sort: "faciles_primero" }
    assert_response :success
  end

  test "should sort by dificiles_primero" do
    get transactions_url, params: { sort: "dificiles_primero" }
    assert_response :success
  end

  test "should sort by monto_asc" do
    get transactions_url, params: { sort: "monto_asc" }
    assert_response :success
  end

  test "should sort by monto_desc" do
    get transactions_url, params: { sort: "monto_desc" }
    assert_response :success
  end

  test "should filter by categoria" do
    get transactions_url, params: { categoria: "Varios" }
    assert_response :success
  end

  test "approve_similar_preview without params returns empty" do
    get approve_similar_preview_transactions_url
    assert_response :success
  end

  test "approve_similar_preview with params returns matches" do
    get approve_similar_preview_transactions_url, params: {
      categoria: "Categoria",
      sub_categoria: "Sub",
      sentimiento: "Deseo"
    }
    assert_response :success
  end

  test "approve_similar redirects without params" do
    patch approve_similar_transactions_url
    assert_redirected_to transactions_path
  end

  test "approve_similar approves matching transactions" do
    patch approve_similar_transactions_url, params: {
      categoria: "Categoria",
      sentimiento: "Deseo"
    }
    assert_redirected_to transactions_path
  end

  # Reproduce: transacción guardada con regla vieja, se cambia la regla; la sugerencia debe actualizarse.
  test "suggested values reflect updated rules for transaction with stored values from old rule" do
    @transaction.update!(
      aprobado: false,
      detalles: "Compra en COTO",
      categoria: "Supermercado",
      sub_categoria: "Coto",
      sentimiento: "Deseo",
      manually_edited: false
    )
    # Fixtures: regla two matchea COTO → Supermercado/Coto; sentimiento hereda del padre o regla
    get transactions_url
    assert_response :success
    # Verificar que la respuesta incluye la sugerencia actual (Coto)
    doc = Nokogiri::HTML(response.body)
    card = doc.at_css("#transaction_#{@transaction.id}")
    assert card, "Debe existir la card de la transacción"
    assert_includes card.to_html, "Coto", "La card debe mostrar Coto (subcategoría sugerida)"

    # Cambiar la regla: Coto ya no matchea COTO
    CategoryRule.where(id: category_rules(:two).id).update_all(pattern: "DIA|Dia")

    get transactions_url
    assert_response :success
    doc = Nokogiri::HTML(response.body)
    card = doc.at_css("#transaction_#{@transaction.id}")
    assert card, "Debe existir la card"
    # Tras el cambio, one (Supermercado) matchea COTO como raíz → sub_category nil
    assert_includes card.to_html, "Supermercado", "Debe seguir mostrando Supermercado"
    refute_includes card.to_html, "Coto", "No debe mostrar Coto; la regla ya no matchea"
  end

  # Verifica que la paginación turbo_stream incluye las sugerencias correctas.
  test "turbo_stream page 2 includes suggested values for transactions" do
    Transaction.where(aprobado: false).update_all(aprobado: true)
    # Crear transacción en página 2 que matchee la regla
    tx = Transaction.create!(
      event_id: "page2_coto_#{SecureRandom.hex(4)}",
      fecha: Time.zone.parse("2026-01-01"),
      monto: 1,
      moneda: "pesos",
      detalles: "Compra en COTO",
      origen: "definitivo",
      aprobado: false
    )
    51.times { |i| create_pending_transaction(i, detalles: "Filler #{i}") }

    get transactions_url(format: :turbo_stream), params: { page: 2 }
    assert_response :success
    # La transacción COTO debe estar en página 2 con sugerencia Supermercado/Coto
    assert_includes response.body, "Supermercado"
    assert_includes response.body, "Coto"
    assert_includes response.body, dom_id(tx)
  end

  test "approve with turbo_stream format" do
    patch approve_transaction_url(@transaction), params: {
      transaction: {
        categoria: @transaction.categoria,
        sub_categoria: @transaction.sub_categoria,
        sentimiento: @transaction.sentimiento
      }
    }, as: :turbo_stream
    assert_response :success
  end

  private

  def create_pending_transaction(index, detalles:)
    Transaction.create!(
      event_id: "scroll_event_#{index}_#{SecureRandom.hex(4)}",
      fecha: Time.zone.parse("2026-01-01") + index.minutes,
      monto: index + 1,
      moneda: "pesos",
      detalles: detalles,
      categoria: "Categoria",
      sub_categoria: "Sub",
      sentimiento: "Deseo",
      red: "Visa",
      origen: "definitivo",
      aprobado: false
    )
  end
end
