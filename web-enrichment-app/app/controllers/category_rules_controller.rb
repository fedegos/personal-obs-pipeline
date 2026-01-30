class CategoryRulesController < ApplicationController
  before_action :set_category_rule, only: %i[ show edit update destroy ]

  # GET /category_rules
  def index
    @category_rules = CategoryRule.all
    @category_rules = filter_by_sentimiento(@category_rules)
    @category_rules = @category_rules.order(parent_id: :asc, priority: :desc)

    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  # GET /category_rules/1
  def show
    respond_to do |format|
      format.html
      format.turbo_stream { render turbo_stream: turbo_stream.update("modal-container", "") }
    end
  end

  # GET /category_rules/new (modal via turbo_stream, página completa via html)
  def new
    @category_rule = CategoryRule.new
    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  # GET /category_rules/1/edit (modal via turbo_stream, página completa via html)
  def edit
    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  # POST /category_rules
  def create
    @category_rule = CategoryRule.new(category_rule_params)

    if @category_rule.save
      respond_to do |format|
        format.html { redirect_to @category_rule, notice: "Regla creada." }
        format.turbo_stream
      end
    else
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.turbo_stream { render :new, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /category_rules/1
  def update
    if @category_rule.update(category_rule_params)
      @still_matches_filter = rule_matches_sentimiento_filter?(@category_rule, params[:sentimiento])
      respond_to do |format|
        format.html { redirect_to @category_rule, notice: "Regla actualizada.", status: :see_other }
        format.turbo_stream
      end
    else
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.turbo_stream { render :edit, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /category_rules/1
  def destroy
    @category_rule.destroy!
    respond_to do |format|
      format.html { redirect_to category_rules_path, notice: "Regla eliminada.", status: :see_other }
      format.turbo_stream
    end
  end

  private

  def set_category_rule
    @category_rule = CategoryRule.find(params[:id])
  end

  def filter_by_sentimiento(scope)
    case params[:sentimiento]
    when nil, ""
      scope
    when "_blank"
      scope.where(sentimiento: [ nil, "" ])
    else
      scope.where(sentimiento: params[:sentimiento]) if Transaction::SENTIMIENTOS.key?(params[:sentimiento])
    end || scope
  end

  def rule_matches_sentimiento_filter?(rule, sentimiento_param)
    case sentimiento_param
    when nil, ""
      true
    when "_blank"
      rule.sentimiento.blank?
    else
      rule.sentimiento == sentimiento_param && Transaction::SENTIMIENTOS.key?(sentimiento_param)
    end
  end

  def category_rule_params
    p = params.require(:category_rule).permit(:name, :pattern, :priority, :parent_id, :sentimiento)
    p[:sentimiento] = nil if p[:sentimiento].blank?
    p
  end
end
