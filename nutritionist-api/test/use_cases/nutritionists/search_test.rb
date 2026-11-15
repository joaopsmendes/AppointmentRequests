require "test_helper"

module Nutritionists
  class SearchTest < ActiveSupport::TestCase
    test "returns every nutritionist ordered by name when the query is blank" do
      result = Search.call(query: "")

      assert_equal ["Ana Lima", "João Silva", "Rita Costa"], names(result)
      assert_equal 3, result.total_count
    end

    test "finds nutritionists by name, ignoring case" do
      result = Search.call(query: "JOÃO")

      assert_equal ["João Silva"], names(result)
    end

    test "finds nutritionists by service description" do
      result = Search.call(query: "sports")

      assert_equal ["João Silva"], names(result)
    end

    test "finds every nutritionist offering a matching service" do
      result = Search.call(query: "follow-up")

      assert_equal ["Ana Lima", "Rita Costa"], names(result)
    end

    test "returns all services of a nutritionist matched by only one of them" do
      ana = Search.call(query: "first appointment").records.first

      assert_equal ["First appointment", "Online follow-up"], ana.services.map(&:description).sort
    end

    test "preloads services to avoid N+1 queries" do
      result = Search.call(query: "")

      assert result.records.all? { |nutritionist| nutritionist.association(:services).loaded? }
    end

    test "returns each nutritionist once when the name and several services match" do
      # "o" matches both of Ana's services and the names of João and Rita
      result = Search.call(query: "o")

      assert_equal ["Ana Lima", "João Silva", "Rita Costa"], names(result)
      assert_equal 3, result.total_count
    end

    test "treats LIKE wildcards in the query as plain text" do
      assert_empty names(Search.call(query: "%"))
      assert_empty names(Search.call(query: "_"))
    end

    # --- Accents ------------------------------------------------------------------------

    test "finds nutritionists by name, ignoring accents" do
      assert_equal ["João Silva"], names(Search.call(query: "joao"))
      assert_equal ["Ana Lima"], names(Search.call(query: "Ána"))
    end

    test "finds nutritionists by service description, ignoring accents" do
      Service.create!(nutritionist: nutritionists(:rita), description: "Nutrição clínica",
                      price_cents: 4000, duration_minutes: 60, location: "Leiria")

      assert_equal ["Rita Costa"], names(Search.call(query: "nutricao clinica"))
    end

    # --- Typo tolerance (pg_trgm word similarity) ------------------------------------

    test "finds nutritionists by name despite a typo" do
      assert_equal ["Ana Lima"], names(Search.call(query: "ana lma"))
    end

    test "finds nutritionists by service description despite a typo" do
      assert_equal ["João Silva"], names(Search.call(query: "nutriton")) # Sports nutrition
    end

    test "tolerates a typo and missing accents together" do
      assert_equal ["João Silva"], names(Search.call(query: "joao slva"))
    end

    test "lists exact matches before close matches" do
      Nutritionist.create!(name: "Anita Costa", license_number: "9001N")

      # Alphabetically Anita comes first, but only Rita contains the query
      assert_equal ["Rita Costa", "Anita Costa"], names(Search.call(query: "rita costa"))
    end

    test "returns an empty result when nothing matches" do
      result = Search.call(query: "cardiology")

      assert_empty names(result)
      assert_equal 0, result.total_count
      assert_equal 0, result.total_pages
    end

    test "paginates the results" do
      result = Search.call(page: 2, per_page: 2)

      assert_equal ["Rita Costa"], names(result)
      assert_equal 2, result.page
      assert_equal 2, result.per_page
      assert_equal 3, result.total_count
      assert_equal 2, result.total_pages
    end

    test "caps per_page at 25" do
      assert_equal 25, Search.call(per_page: 1000).per_page
    end

    test "breaks ties on the same name by id, so pagination is stable" do
      twin = Nutritionist.create!(name: "Ana Lima", license_number: "1004N")
      fixture_ana = nutritionists(:ana)

      first_page = Search.call(query: "Ana Lima", per_page: 1, page: 1).records.to_a
      second_page = Search.call(query: "Ana Lima", per_page: 1, page: 2).records.to_a

      assert_equal [fixture_ana.id, twin.id].sort, (first_page + second_page).map(&:id)
    end

    test "returns no records for a page past the last one" do
      result = Search.call(page: 99)

      assert_empty names(result)
      assert_equal 3, result.total_count
      assert_equal 25, result.per_page
    end

    test "treats a whitespace-only query as blank" do
      assert_equal 3, Search.call(query: "   ").total_count
    end

    test "falls back to the first page for invalid page values" do
      [nil, 0, -1, "abc"].each do |page|
        assert_equal 1, Search.call(page: page).page, "page=#{page.inspect}"
      end
    end

    test "falls back to the default per_page for invalid values" do
      # Params arrive as strings, so "0" is what ?per_page=0 sends.
      [nil, "", "abc", -5, 0, "0"].each do |per_page|
        assert_equal 25, Search.call(per_page: per_page).per_page, "per_page=#{per_page.inspect}"
      end
    end

    private

    def names(result)
      result.records.map(&:name)
    end
  end
end
