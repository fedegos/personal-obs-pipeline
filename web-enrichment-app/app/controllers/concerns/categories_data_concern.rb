# frozen_string_literal: true

module CategoriesDataConcern
  extend ActiveSupport::Concern

  private

  def prepare_categories_data
    @categories_map = CategoryRule.roots.includes(:children).each_with_object({}) do |root, hash|
      hash[root.name] = root.children.pluck(:name)
    end
    @categories_list = @categories_map.keys
    @categories_for_filter = @categories_map.flat_map { |cat, subs| [ cat ] + subs }.uniq.sort
  end
end
