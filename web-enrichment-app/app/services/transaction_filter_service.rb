# frozen_string_literal: true

class TransactionFilterService
  ITEMS_PER_PAGE = 50

  attr_reader :params, :page, :transactions, :total_count, :suggested, :next_page

  def initialize(params)
    @params = params
    @page = [ params[:page].to_i, 1 ].max
    @guess_cache = {}
  end

  def call
    base = build_base_scope
    sorted = sort_transactions(base)
    filtered = apply_category_filter(sorted)

    @total_count = filtered.size
    offset = (@page - 1) * ITEMS_PER_PAGE
    @transactions = filtered.slice(offset, ITEMS_PER_PAGE) || []
    @next_page = (offset + @transactions.length) < @total_count ? @page + 1 : nil

    build_suggestions
    self
  end

  private

  def build_base_scope
    base = Transaction.where(aprobado: false)

    if params[:q].present?
      escaped = params[:q].to_s.gsub(/[%_\\]/) { |c| "\\#{c}" }
      base = base.where("detalles ILIKE ?", "%#{escaped}%")
    end

    base = base.where(fecha: params[:fecha]) if params[:fecha].present?
    base = base.where("monto >= ?", params[:monto_min]) if params[:monto_min].present?
    base = base.where("monto <= ?", params[:monto_max]) if params[:monto_max].present?
    base = base.where(numero_tarjeta: params[:tarjeta]) if params[:tarjeta].present?
    base = base.where(red: params[:red]) if params[:red].present?

    base
  end

  def sort_transactions(base_scope)
    case params[:sort]
    when "faciles_primero"
      base_scope.to_a.sort_by { |t| ease_score(t) }
    when "dificiles_primero"
      base_scope.to_a.sort_by { |t| -ease_score(t) }
    when "monto_asc"
      base_scope.order(monto: :asc).to_a
    when "monto_desc"
      base_scope.order(monto: :desc).to_a
    else
      base_scope.order(fecha: :desc).to_a
    end
  end

  def ease_score(transaction)
    r = guess_for(transaction)
    if r[:category].present? && r[:category] != "Varios" && r[:sentimiento].present?
      r[:sub_category].present? ? 0 : 1
    else
      2
    end
  end

  def apply_category_filter(sorted)
    return sorted unless params[:categoria].present?

    sorted.select do |t|
      r = guess_for(t)
      r[:category] == params[:categoria] || r[:sub_category] == params[:categoria]
    end
  end

  def build_suggestions
    @suggested = @transactions.each_with_object({}) do |t, h|
      result = guess_for(t)
      sent = result[:sentimiento].presence
      sent = "Deseo" unless sent.present? && Transaction::SENTIMIENTOS.key?(sent)
      h[t.id] = {
        category: result[:category],
        sub_category: result[:sub_category],
        sentimiento: sent
      }
    end
  end

  def guess_for(transaction)
    @guess_cache[transaction.detalles] ||= CategorizerService.guess(transaction.detalles)
  end
end
