class AuditCorrectionsController < ApplicationController
  def index
    @transactions = Transaction.aprobadas

    # Buscador multi-campo
    if params[:query].present?
      q = "%#{params[:query]}%"
      @transactions = @transactions.where(
        "event_id ILIKE ? OR detalles ILIKE ? OR categoria ILIKE ? OR sub_categoria ILIKE ? OR sentimiento ILIKE ?",
        q, q, q, q, q
      )
    end

    # Filtro por fecha
    @transactions = @transactions.where(fecha: params[:fecha]) if params[:fecha].present?

    # Paginación
    @pagy, @records = pagy(@transactions.order(fecha: :desc), items: 20)

    # Variables para los datalists (necesarias si el modal está en el index o se carga vía turbo)
    prepare_categories_data

    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  def edit
    @transaction = Transaction.find(params[:id])
    prepare_categories_data

    respond_to do |format|
      format.turbo_stream # Renderiza edit.turbo_stream.erb (el modal)
    end
  end

  def prev
    redirect_to_neighbor(-1)
  end

  def next
    redirect_to_neighbor(1)
  end

  def show
    @transaction = Transaction.find(params[:id])
    respond_to do |format|
      format.turbo_stream # Para cancelar la edición y limpiar el modal
      format.html { render partial: "transaction", locals: { transaction: @transaction } }
    end
  end

  def update
    @transaction = Transaction.find(params[:id])

    if @transaction.update(transaction_params)
      # 🚀 PUBLICACIÓN EN KAFKA
      # El método publish_clean_event ya debería manejar el payload correcto
      @transaction.publish_clean_event

      respond_to do |format|
        format.turbo_stream # Renderiza update.turbo_stream.erb
        format.html { redirect_to audit_corrections_path, notice: "Registro actualizado." }
      end
    else
      # Si falla la validación, re-renderizamos el modal con errores
      prepare_categories_data
      render turbo_stream: turbo_stream.update("modal-container", partial: "form_modal") # Opcional: manejar errores
    end
  end

  private

  def redirect_to_neighbor(offset)
    @transaction = Transaction.find(params[:id])
    scope = build_index_scope
    ids = scope.pluck(:id)
    idx = ids.index(@transaction.id)
    return redirect_to audit_corrections_path, alert: "No encontrado" unless idx

    neighbor_idx = idx + offset
    if neighbor_idx < 0 || neighbor_idx >= ids.size
      redirect_to audit_corrections_path
    else
      redirect_to edit_audit_correction_path(ids[neighbor_idx], query: params[:query], fecha: params[:fecha])
    end
  end

  def build_index_scope
    scope = Transaction.aprobadas
    if params[:query].present?
      q = "%#{params[:query]}%"
      scope = scope.where(
        "event_id ILIKE ? OR detalles ILIKE ? OR categoria ILIKE ? OR sub_categoria ILIKE ? OR sentimiento ILIKE ?",
        q, q, q, q, q
      )
    end
    scope = scope.where(fecha: params[:fecha]) if params[:fecha].present?
    scope.order(fecha: :desc).limit(500)
  end

  # Centralizamos la lógica de categorías para no repetir código
  def prepare_categories_data
    # Replicamos la lógica exacta de TransactionsController
    @categories_map = CategoryRule.roots.includes(:children).each_with_object({}) do |root, hash|
      hash[root.name] = root.children.pluck(:name)
    end
    @categories_list = @categories_map.keys
  end

  def transaction_params
    # ⚠️ IMPORTANTE: Agregamos :sub_categoria
    params.require(:transaction).permit(:monto, :categoria, :sub_categoria, :sentimiento, :detalles, :fecha)
  end
end
