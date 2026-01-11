class CategoryRulesController < ApplicationController
  before_action :set_category_rule, only: %i[ show edit update destroy ]

  # GET /category_rules or /category_rules.json
  def index
    @category_rules = CategoryRule.all
  end

  # GET /category_rules/1 or /category_rules/1.json
  def show
  end

  # GET /category_rules/new
  def new
    @category_rule = CategoryRule.new
  end

  # GET /category_rules/1/edit
  def edit
  end

  # POST /category_rules or /category_rules.json
  def create
    @category_rule = CategoryRule.new(category_rule_params)

    respond_to do |format|
      if @category_rule.save
        format.html { redirect_to @category_rule, notice: "Category rule was successfully created." }
        format.json { render :show, status: :created, location: @category_rule }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @category_rule.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /category_rules/1 or /category_rules/1.json
  def update
    respond_to do |format|
      if @category_rule.update(category_rule_params)
        format.html { redirect_to @category_rule, notice: "Category rule was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @category_rule }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @category_rule.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /category_rules/1 or /category_rules/1.json
  def destroy
    @category_rule.destroy!

    respond_to do |format|
      format.html { redirect_to category_rules_path, notice: "Category rule was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_category_rule
      @category_rule = CategoryRule.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def category_rule_params
      params.expect(category_rule: [ :name, :pattern, :priority, :parent_id ])
    end
end
