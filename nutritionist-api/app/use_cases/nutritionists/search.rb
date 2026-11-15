# app/use_cases/nutritionists/search.rb
module Nutritionists
  class Search
    Result = Struct.new(:records, :page, :per_page, :total_count, :total_pages, keyword_init: true)

    def self.call(query: nil, page: 1, per_page: nil)
      per_page = nil unless per_page.to_i.positive?
      scope = build_scope(query)
      paginated_scope = scope.page(page).per(per_page, max_per_page: 25)

      Result.new(
        records: paginated_scope,
        page: paginated_scope.current_page,
        per_page: paginated_scope.limit_value,
        total_count: paginated_scope.total_count,
        total_pages: paginated_scope.total_pages
      )
    end

    # The search looks at the normalized copies (name_search, description_search: no accents, lowercase)
    def self.build_scope(query)
      scope = Nutritionist.preload(:services).order(:name, :id)
      return scope if query.blank?

      term = "%#{Nutritionist.sanitize_sql_like(SearchText.normalize(query))}%"
      matching_services = Service.where("description_search ILIKE ?", term).select(:nutritionist_id)

      scope.where("nutritionists.name_search ILIKE ?", term)
           .or(scope.where(id: matching_services))
    end

    private_class_method :build_scope
  end
end
