# frozen_string_literal: true

require_relative "test_helper"

# Stub object — no Rails/ActiveRecord needed
User = Struct.new(:id, :first_name, :last_name, :email)

class UserSerializer < Oaken::Serializer
  def serialize(user)
    {
      id: user.id,
      first_name: user.first_name,
      last_name: user.last_name,
      email: user.email
    }
  end
end

class OakenTest < Minitest::Test
  def setup
    @user = User.new(1, "Jane", "Doe", "jane@example.com")
  end

  def test_serializes_single_object_to_json_string
    result = UserSerializer.new.to_json(@user)
    parsed = JSON.parse(result)

    assert_equal 1, parsed["id"]
    assert_equal "Jane", parsed["first_name"]
    assert_equal "Doe", parsed["last_name"]
    assert_equal "jane@example.com", parsed["email"]
  end

  def test_returns_string
    result = UserSerializer.new.to_json(@user)
    assert_instance_of String, result
  end
end
