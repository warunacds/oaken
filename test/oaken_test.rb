# frozen_string_literal: true

require_relative "test_helper"

# Stub objects — no Rails/ActiveRecord needed
User = Struct.new(:id, :first_name, :last_name, :email)
Post = Struct.new(:id, :title, :author)
Comment = Struct.new(:id, :body)
Article = Struct.new(:id, :title, :comments)

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

class PostSerializer < Oaken::Serializer
  def serialize(post)
    {
      id: post.id,
      title: post.title,
      author: nest(UserSerializer, post.author)
    }
  end
end

class CommentSerializer < Oaken::Serializer
  def serialize(comment)
    { id: comment.id, body: comment.body }
  end
end

class ArticleSerializer < Oaken::Serializer
  def serialize(article)
    {
      id: article.id,
      title: article.title,
      comments: nest_many(CommentSerializer, article.comments)
    }
  end
end

class OakenTest < Minitest::Test
  def setup
    @user = User.new(1, "Jane", "Doe", "jane@example.com")
  end

  # Task 2: Single object
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

  # Task 3: Collection
  def test_serializes_collection_to_json_array
    users = [
      User.new(1, "Jane", "Doe", "jane@example.com"),
      User.new(2, "John", "Smith", "john@example.com")
    ]
    result = UserSerializer.new.to_json(users)
    parsed = JSON.parse(result)

    assert_instance_of Array, parsed
    assert_equal 2, parsed.length
    assert_equal 1, parsed[0]["id"]
    assert_equal 2, parsed[1]["id"]
  end

  def test_serializes_empty_collection
    result = UserSerializer.new.to_json([])
    parsed = JSON.parse(result)
    assert_equal [], parsed
  end

  # Task 4: Nested serialization
  def test_nests_single_serializer
    post = Post.new(42, "Hello World", @user)

    result = PostSerializer.new.to_json(post)
    parsed = JSON.parse(result)

    assert_equal 42, parsed["id"]
    assert_equal "Hello World", parsed["title"]
    assert_equal 1, parsed["author"]["id"]
    assert_equal "Jane", parsed["author"]["first_name"]
  end

  def test_nest_returns_nil_for_nil_object
    post = Post.new(42, "Hello World", nil)
    result = PostSerializer.new.to_json(post)
    parsed = JSON.parse(result)

    assert_nil parsed["author"]
  end

  # Task 5: nest_many
  def test_nest_many_serializes_collection
    comments = [Comment.new(1, "Great!"), Comment.new(2, "Nice!")]
    article = Article.new(10, "My Article", comments)

    result = ArticleSerializer.new.to_json(article)
    parsed = JSON.parse(result)

    assert_equal 2, parsed["comments"].length
    assert_equal 1, parsed["comments"][0]["id"]
    assert_equal "Great!", parsed["comments"][0]["body"]
  end

  def test_nest_many_returns_empty_array_for_nil
    article = Article.new(10, "My Article", nil)
    result = ArticleSerializer.new.to_json(article)
    parsed = JSON.parse(result)
    assert_equal [], parsed["comments"]
  end

  def test_nest_many_returns_empty_array_for_empty_collection
    article = Article.new(10, "My Article", [])
    result = ArticleSerializer.new.to_json(article)
    parsed = JSON.parse(result)
    assert_equal [], parsed["comments"]
  end

  # Task 6: NotImplementedError
  def test_raises_not_implemented_error_when_serialize_not_defined
    klass = Class.new(Oaken::Serializer)
    assert_raises(NotImplementedError) { klass.new.to_json(Object.new) }
  end
end

# --- Oaken.extract tests ---

class ExtractTest < Minitest::Test
  def setup
    @user = User.new(1, "Jane", "Doe", "jane@example.com")
  end

  def test_extracts_multiple_attributes_into_hash
    result = Oaken.extract(@user, :id, :first_name, :email)
    assert_equal({ id: 1, first_name: "Jane", email: "jane@example.com" }, result)
  end

  def test_extracts_single_attribute
    result = Oaken.extract(@user, :id)
    assert_equal({ id: 1 }, result)
  end

  def test_returns_empty_hash_with_no_attributes
    result = Oaken.extract(@user)
    assert_equal({}, result)
  end

  def test_raises_no_method_error_on_private_methods
    obj = Object.new
    def obj.public_value; "ok"; end
    class << obj; private; def secret; "hidden"; end; end

    assert_raises(NoMethodError) { Oaken.extract(obj, :secret) }
  end

  def test_handles_nil_attribute_values
    user = User.new(1, nil, "Doe", nil)
    result = Oaken.extract(user, :first_name, :email)
    assert_equal({ first_name: nil, email: nil }, result)
    assert result.key?(:first_name)
    assert result.key?(:email)
  end

  def test_works_with_merge_pattern
    result = Oaken.extract(@user, :id, :first_name).merge(
      full_name: "#{@user.first_name} #{@user.last_name}"
    )
    expected = { id: 1, first_name: "Jane", full_name: "Jane Doe" }
    assert_equal expected, result
  end

  def test_works_with_open_struct
    require "ostruct"
    obj = OpenStruct.new(id: 1, name: "test")
    assert_equal({ id: 1, name: "test" }, Oaken.extract(obj, :id, :name))
  end

  def test_works_with_plain_object
    obj = Object.new
    def obj.id; 42; end
    assert_equal({ id: 42 }, Oaken.extract(obj, :id))
  end

  def test_string_attributes_normalized_to_symbol_keys
    result = Oaken.extract(@user, "id", "first_name")
    assert_equal({ id: 1, first_name: "Jane" }, result)
    assert result.key?(:id)
    refute result.key?("id")
  end
end

# --- Context tests ---

# Serializers used by ContextTest
class ContextAwareUserSerializer < Oaken::Serializer
  def serialize(user)
    result = { id: user.id, first_name: user.first_name }
    result[:email] = user.email if context[:full]
    result
  end
end

class ContextAwarePostSerializer < Oaken::Serializer
  def serialize(post)
    {
      id: post.id,
      title: post.title,
      author: nest(ContextAwareUserSerializer, post.author)
    }
  end
end

class ContextAwareArticleSerializer < Oaken::Serializer
  def serialize(article)
    {
      id: article.id,
      comments: nest_many(ContextAwareCommentSerializer, article.comments)
    }
  end
end

class ContextAwareCommentSerializer < Oaken::Serializer
  def serialize(comment)
    result = { id: comment.id }
    result[:body] = comment.body if context[:full]
    result
  end
end

# For deep propagation test
Team = Struct.new(:id, :name, :captain)

class DeepCaptainSerializer < Oaken::Serializer
  def serialize(user)
    result = { id: user.id }
    result[:email] = user.email if context[:full]
    result
  end
end

class DeepTeamSerializer < Oaken::Serializer
  def serialize(team)
    {
      id: team.id,
      name: team.name,
      captain: nest(DeepCaptainSerializer, team.captain)
    }
  end
end

class ContextTest < Minitest::Test
  def setup
    @user = User.new(1, "Jane", "Doe", "jane@example.com")
  end

  def test_context_defaults_to_empty_hash
    serializer = UserSerializer.new
    assert_equal({}, serializer.context)
  end

  def test_backward_compat_no_args
    serializer = UserSerializer.new
    result = JSON.parse(serializer.to_json(@user))
    assert_equal 1, result["id"]
    assert_equal "Jane", result["first_name"]
  end

  def test_context_readable_inside_serialize
    serializer = ContextAwareUserSerializer.new(context: { full: true })
    result = serializer.serialize(@user)
    assert_equal "jane@example.com", result[:email]
  end

  def test_conditional_fields_based_on_context
    mini = ContextAwareUserSerializer.new
    full = ContextAwareUserSerializer.new(context: { full: true })

    mini_result = mini.serialize(@user)
    full_result = full.serialize(@user)

    refute mini_result.key?(:email)
    assert_equal "jane@example.com", full_result[:email]
  end

  def test_context_propagates_through_nest
    post = Post.new(42, "Hello", @user)
    serializer = ContextAwarePostSerializer.new(context: { full: true })
    result = serializer.serialize(post)

    assert_equal "jane@example.com", result[:author][:email]
  end

  def test_context_propagates_through_nest_many
    comments = [Comment.new(1, "Great!"), Comment.new(2, "Nice!")]
    article = Article.new(10, "My Article", comments)

    serializer = ContextAwareArticleSerializer.new(context: { full: true })
    result = serializer.serialize(article)

    assert_equal "Great!", result[:comments][0][:body]
    assert_equal "Nice!", result[:comments][1][:body]
  end

  def test_deep_propagation_grandchild_receives_context
    captain = User.new(1, "Jane", "Doe", "jane@example.com")
    team = Team.new(100, "Hawks", captain)

    serializer = DeepTeamSerializer.new(context: { full: true })
    result = serializer.serialize(team)

    assert_equal "jane@example.com", result[:captain][:email]
  end

  def test_different_context_values_produce_different_output
    mini_serializer = ContextAwareUserSerializer.new
    full_serializer = ContextAwareUserSerializer.new(context: { full: true })

    mini = mini_serializer.serialize(@user)
    full = full_serializer.serialize(@user)

    refute_equal mini, full
  end

  def test_context_hash_is_not_mutated
    original = { full: true }
    frozen_copy = original.dup
    serializer = ContextAwareUserSerializer.new(context: original)
    serializer.serialize(@user)

    assert_equal frozen_copy, original
  end

  def test_context_is_frozen
    serializer = ContextAwareUserSerializer.new(context: { full: true })
    assert serializer.context.frozen?
  end

  def test_mutating_context_raises_frozen_error
    serializer = ContextAwareUserSerializer.new(context: { full: true })
    assert_raises(FrozenError) { serializer.context[:injected] = "bad" }
  end
end

# --- Backward compatibility tests ---

class BackwardCompatibilityTest < Minitest::Test
  def setup
    @user = User.new(1, "Jane", "Doe", "jane@example.com")
  end

  def test_original_serializer_patterns_work_without_context
    result = JSON.parse(UserSerializer.new.to_json(@user))
    assert_equal 1, result["id"]
    assert_equal "Jane", result["first_name"]
    assert_equal "Doe", result["last_name"]
    assert_equal "jane@example.com", result["email"]
  end

  def test_nest_works_without_context
    post = Post.new(42, "Hello World", @user)
    result = JSON.parse(PostSerializer.new.to_json(post))
    assert_equal 1, result["author"]["id"]
  end

  def test_nest_many_works_without_context
    comments = [Comment.new(1, "Great!")]
    article = Article.new(10, "My Article", comments)
    result = JSON.parse(ArticleSerializer.new.to_json(article))
    assert_equal 1, result["comments"][0]["id"]
  end

  def test_not_implemented_error_still_raised
    klass = Class.new(Oaken::Serializer)
    assert_raises(NotImplementedError) { klass.new.to_json(Object.new) }
  end
end
