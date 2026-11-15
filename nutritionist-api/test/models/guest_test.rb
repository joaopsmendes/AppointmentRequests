require "test_helper"

class GuestTest < ActiveSupport::TestCase
  test "removes extra spaces from the name" do
    assert_equal "Maria Santos", Guest.new(name: "  Maria   Santos ").name
  end

  test "stores the email without spaces and in lowercase" do
    assert_equal "maria@example.com", Guest.new(email: "  Maria@Example.COM ").email
  end

  test "cannot be deleted while it has appointment requests" do
    guest = guests(:pedro)

    assert_no_difference -> { Guest.count } do
      assert_not guest.destroy
    end
  end
end
