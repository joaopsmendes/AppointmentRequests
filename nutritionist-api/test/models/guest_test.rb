require "test_helper"

class GuestTest < ActiveSupport::TestCase
  test "removes extra spaces from the name" do
    assert_equal "Maria Santos", Guest.new(name: "  Maria   Santos ").name
  end

  test "stores the email without spaces and in lowercase" do
    assert_equal "maria@example.com", Guest.new(email: "  Maria@Example.COM ").email
  end

  test "accepts common email formats" do
    %w[ana@example.com ana.lima+tag@mail.example.pt].each do |email|
      assert Guest.new(name: "Ana", email: email).valid?, "#{email} should be valid"
    end
  end

  test "refuses emails without a dot in the domain or with spaces" do
    ["brunafl@a", "ana@", "@example.com", "ana example@mail.com", "ana@mail.com\nx@y.z"].each do |email|
      guest = Guest.new(name: "Ana", email: email)
      assert_not guest.valid?, "#{email.inspect} should be invalid"
      assert guest.errors.of_kind?(:email, :invalid)
    end
  end

  test "cannot be deleted while it has appointment requests" do
    guest = guests(:pedro)

    assert_no_difference -> { Guest.count } do
      assert_not guest.destroy
    end
  end
end
