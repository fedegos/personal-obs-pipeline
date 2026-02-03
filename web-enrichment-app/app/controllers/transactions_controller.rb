# app/controllers/transactions_controller.rb
class TransactionsController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [ :approve, :update ]

  def index
    @pending = Transaction.where(aprobado: false).order(fecha: :desc)

    # Replicar motor de reglas en memoria (categoría, subcategoría, sentimiento) sin persistir
    @suggested = @pending.each_with_object({}) do |t, h|
      result = CategorizerService.guess(t.detalles)
      sent = result[:sentimiento].present? && Transaction::SENTIMIENTOS.key?(result[:sentimiento]) ? result[:sentimiento] : SentimentService.analyze(t.detalles)
      h[t.id] = {
        category: result[:category],
        sub_category: result[:sub_category],
        sentimiento: sent
      }
    end

    # Creamos un hash: { "Supermercado" => ["Coto", "Dia"], "Hogar" => ["Luz", "Agua"] }
    @categories_map = CategoryRule.roots.includes(:children).each_with_object({}) do |root, hash|
      hash[root.name] = root.children.pluck(:name)
    end

    @categories_list = @categories_map.keys
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
      # En caso de error de validación
      respond_to do |format|
        format.html { redirect_to transactions_path, alert: "No se pudo procesar la aprobación." }
      end
    end
  end

  private

  def transaction_params
    params.require(:transaction).permit(:categoria, :sub_categoria, :sentimiento)
  end
end
