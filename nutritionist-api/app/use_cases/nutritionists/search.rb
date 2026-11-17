module Nutritionists
  class Search
    Result = Struct.new(:records, :page, :per_page, :total_count, :total_pages, keyword_init: true)

    def self.call(query: nil, location: nil, page: 1, per_page: nil)
      per_page = nil unless per_page.to_i.positive?
      scope = build_scope(query, location)
      paginated_scope = scope.page(page).per(per_page, max_per_page: 25)

      Result.new(
        records: paginated_scope,
        page: paginated_scope.current_page,
        per_page: paginated_scope.limit_value,
        total_count: paginated_scope.total_count,
        total_pages: paginated_scope.total_pages
      )
    end

    # Searches accent-free, lowercase columns (name_search, description_search) using SearchText.
    # Combines exact substring matching (ILIKE) with pg_trgm typo tolerance (<%, threshold 0.6),
    # both backed by the same trigram indexes.
    NAME_MATCHES = "nutritionists.name_search ILIKE :term OR :query <% nutritionists.name_search".freeze
    DESCRIPTION_MATCHES = "description_search ILIKE :term OR :query <% description_search".freeze
    EXACT_MATCHES_FIRST = <<~SQL.squish.freeze
      CASE WHEN nutritionists.name_search ILIKE :term
             OR nutritionists.id IN (SELECT nutritionist_id FROM services WHERE description_search ILIKE :term)
           THEN 0 ELSE 1 END
    SQL

    def self.build_scope(query, location)
      scope = Nutritionist.preload(:services)
      services = Service.all
      if location.present?
        location_term = "%#{Service.sanitize_sql_like(SearchText.normalize(location))}%"
        services = services.where("location_search ILIKE ?", location_term)
        scope = scope.where(id: services.select(:nutritionist_id))
      end
      return scope.order(:name, :id) if query.blank?

      query = SearchText.normalize(query)
      values = { term: "%#{Nutritionist.sanitize_sql_like(query)}%", query: query }

      matching_services = services.where(DESCRIPTION_MATCHES, values).select(:nutritionist_id)

      scope.where(NAME_MATCHES, values)
           .or(scope.where(id: matching_services))
           .order(Arel.sql(Nutritionist.sanitize_sql_array([EXACT_MATCHES_FIRST, values])), :name, :id)
    end

    private_class_method :build_scope
  end
end
