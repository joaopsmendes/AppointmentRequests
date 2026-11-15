require "test_helper"

class ServiceTest < ActiveSupport::TestCase
  test "requires a description and a location" do
    service = Service.new(nutritionist: nutritionists(:ana), price_cents: 4000, duration_minutes: 60)

    assert_not service.valid?
    assert service.errors.of_kind?(:description, :blank)
    assert service.errors.of_kind?(:location, :blank)
  end

  %i[price_cents duration_minutes].each do |attribute|
    test "requires #{attribute} to be a positive integer" do
      service = services(:ana_first_appointment)

      { 0 => :greater_than, -10 => :greater_than, 1.5 => :not_an_integer, nil => :not_a_number }.each do |value, error|
        service[attribute] = value
        assert_not service.valid?, "#{attribute} = #{value.inspect} should be invalid"
        assert service.errors.of_kind?(attribute, error), "#{attribute} = #{value.inspect} should give #{error}"
      end
    end
  end

  test "cannot be deleted while it has appointment requests" do
    service = services(:ana_first_appointment)

    assert_no_difference -> { Service.count } do
      assert_not service.destroy
    end
  end
end
