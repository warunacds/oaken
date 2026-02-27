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
