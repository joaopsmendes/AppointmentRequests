require "test_helper"

module Api
  class NutritionistsControllerTest < ActionDispatch::IntegrationTest
    test "GET /api/nutritionists returns the nutritionists with their services and the pagination" do
      get "/api/nutritionists"

      assert_response :ok
      body = response.parsed_body
      assert_equal ["Ana Lima", "João Silva", "Rita Costa"], body["data"].map { |n| n["name"] }

      ana = body["data"].first
      assert_equal %w[id license_number name photo_url services], ana.keys.sort
      assert_equal nutritionists(:ana).id, ana["id"]
      assert_equal "1001N", ana["license_number"]

      service = ana["services"].first
      assert_equal %w[description duration_minutes id location price_cents], service.keys.sort
      assert_equal({ "id" => services(:ana_first_appointment).id, "description" => "First appointment",
                     "price_cents" => 4000, "duration_minutes" => 60, "location" => "Lisboa" }, service)

      assert_equal({ "page" => 1, "per_page" => 25, "total_count" => 3, "total_pages" => 1 }, body["meta"])
    end

    test "GET /api/nutritionists filters by q" do
      get "/api/nutritionists", params: { q: "sports" }

      assert_response :ok
      assert_equal ["João Silva"], response.parsed_body["data"].map { |n| n["name"] }
    end

    test "GET /api/nutritionists paginates with page and per_page" do
      get "/api/nutritionists", params: { page: 2, per_page: 1 }

      assert_response :ok
      body = response.parsed_body
      assert_equal ["João Silva"], body["data"].map { |n| n["name"] }
      assert_equal({ "page" => 2, "per_page" => 1, "total_count" => 3, "total_pages" => 3 }, body["meta"])
    end
  end
end
