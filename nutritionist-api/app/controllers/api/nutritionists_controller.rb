module Api
  class NutritionistsController < ApplicationController
    # GET /api/nutritionists?q=&page=&per_page=
    def index
      query = params[:q]
      page = params[:page]
      per_page = params[:per_page]

      result = Nutritionists::Search.call(
        query: query,
        page: page,
        per_page: per_page
      )

      render_result(result)
    end

    private

    def render_result(result)
      render json: {
        data: result.records.map { |nutritionist| NutritionistSerializer.render(nutritionist) },
        meta: {
          page: result.page,
          per_page: result.per_page,
          total_count: result.total_count,
          total_pages: result.total_pages
        }
      }
    end
  end
end