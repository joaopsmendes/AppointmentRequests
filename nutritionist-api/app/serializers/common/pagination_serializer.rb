module Common
  class PaginationSerializer
    def self.render(result)
      {
        page: result.page,
        per_page: result.per_page,
        total_count: result.total_count,
        total_pages: result.total_pages
      }
    end
  end
end