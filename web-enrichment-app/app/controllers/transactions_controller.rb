# app/controllers/transactions_controller.rb
class TransactionsController < ApplicationController
  include CategoriesDataConcern

  def index
    @filter_params = params.permit(:q, :fecha, :monto_min, :monto_max, :categoria, :tarjeta, :red, :sort).to_h.compact_blank
    service = TransactionFilterService.new(params).call

    @pending = service.transactions
    @pending_count = service.total_count
    @page = service.page
    @next_page = service.next_page
    @suggested = service.suggested

    @approved_count = Transaction.where(aprobado: true).count
    @approved_this_week = Transaction.where(aprobado: true).where("updated_at >= ?", 1.week.ago).count
    @total_count = @pending_count + @approved_count

    prepare_categories_data
    @tarjetas_for_filter = Transaction.where(aprobado: false).where.not(numero_tarjeta: [ nil, "" ]).distinct.pluck(:numero_tarjeta).sort
    @redes_for_filter = Transaction.where(aprobado: false).where.not(red: [ nil, "" ]).distinct.pluck(:red).sort
    @first_time_empty = @pending_count == 0 && Transaction.count.zero?

    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  def update
    @transaction = Transaction.find(params[:id])
    return head :forbidden if @transaction.aprobado?

    attrs = transaction_params.merge(manually_edited: true)
    attrs[:manually_edited] = false if params[:use_suggestion].present?

    if @transaction.update(attrs)
      respond_to do |format|
        format.json { render json: { ok: true, saved_at: Time.current.iso8601 } }
        format.turbo_stream
        format.html { redirect_to transactions_path, notice: "Cambios guardados." }
      end
    else
      respond_to do |format|
        format.json { render json: { ok: false, errors: @transaction.errors.full_messages }, status: :unprocessable_entity }
        format.html { redirect_to transactions_path, alert: "No se pudo guardar." }
      end
    end
  end

  def approve_similar_preview
    cat = params[:categoria].presence
    sub = params[:sub_categoria].presence
    sent = params[:sentimiento].presence

    if cat.blank? || sent.blank?
      render html: "", layout: false
      return
    end

    @matches = matching_transactions_for_batch(cat, sub, sent)
    @transactions = @matches.to_a
    @categoria = cat
    @sub_categoria = sub.to_s
    @sentimiento = sent
    @sentimiento_display = Transaction::SENTIMIENTOS[sent] || sent

    render "approve_similar_preview", layout: false
  end

  def approve_similar
    cat = params[:categoria].presence
    sub = params[:sub_categoria].presence
    sent = params[:sentimiento].presence
    return redirect_to transactions_path, alert: "Faltan parámetros" if cat.blank? || sent.blank?

    approved_ids = []
    matching_transactions_for_batch(cat, sub, sent).find_each do |t|
      r = CategorizerService.guess(t.detalles)
      sub_val = r[:sub_category]

      if t.update(categoria: cat, sub_categoria: sub_val, sentimiento: sent, aprobado: true, manually_edited: false)
        t.publish_clean_event
        approved_ids << t.id
      end
    end

    redirect_to transactions_path, notice: "#{approved_ids.size} transacciones aprobadas."
  end

  def approve
    @transaction = Transaction.find(params[:id])

    if @transaction.update(transaction_params.merge(aprobado: true, manually_edited: false))

      # 1. Publicar el evento enriquecido en Kafka Clean (hacia Telegraf -> InfluxDB)
      @transaction.publish_clean_event

      # 2. Responder al navegador
      respond_to do |format|
        format.turbo_stream # Busca approve.turbo_stream.erb
        format.html { redirect_to transactions_path, notice: "Aprobado." }
      end
    else
      respond_to do |format|
        format.json { render json: { ok: false, errors: @transaction.errors.full_messages }, status: :unprocessable_entity }
        format.html { redirect_to transactions_path, alert: "No se pudo procesar la aprobación." }
      end
    end
  end

  private

  def matching_transactions_for_batch(cat, sub, sent)
    base = Transaction.where(aprobado: false)
    guess_cache = {}
    ids = []
    base.find_each do |t|
      r = guess_cache[t.detalles] ||= CategorizerService.guess(t.detalles)
      next unless r[:category] == cat && r[:sentimiento] == sent
      next if sub.present? && r[:sub_category] != sub

      ids << t.id
    end
    Transaction.where(id: ids)
  end

  def transaction_params
    params.require(:transaction).permit(:categoria, :sub_categoria, :sentimiento)
  end
end
