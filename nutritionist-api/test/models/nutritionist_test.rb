require "test_helper"

class NutritionistTest < ActiveSupport::TestCase
  test "requires a name and a license number" do
    nutritionist = Nutritionist.new

    assert_not nutritionist.valid?
    assert nutritionist.errors.of_kind?(:name, :blank)
    assert nutritionist.errors.of_kind?(:license_number, :blank)
  end

  test "requires a unique license number" do
    nutritionist = Nutritionist.new(name: "Another Ana", license_number: nutritionists(:ana).license_number)

    assert_not nutritionist.valid?
    assert nutritionist.errors.of_kind?(:license_number, :taken)
  end

  test "removes extra spaces from the name and the license number" do
    nutritionist = Nutritionist.new(name: "  Ana   Lima ", license_number: " 9999N ")

    assert_equal "Ana Lima", nutritionist.name
    assert_equal "9999N", nutritionist.license_number
  end

  test "cannot be deleted while it has appointment requests, so the history is kept" do
    ana = nutritionists(:ana)

    assert_no_difference -> { Nutritionist.count } do
      assert_not ana.destroy
    end
    assert ana.errors.of_kind?(:base, :"restrict_dependent_destroy.has_many")
  end

  test "deletes its services when it is deleted without appointment requests" do
    rita = nutritionists(:rita) # one service, no requests
    service_id = services(:rita_follow_up).id

    rita.destroy!

    assert_not Service.exists?(service_id)
  end
end
