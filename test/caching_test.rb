# frozen_string_literal: true

require_relative "test_helper"

# Test double: Hash-backed cache store that tracks calls for assertions
class MemoryStore
  attr_reader :data, :fetch_calls

  def initialize
    @data = {}
    @fetch_calls = []
  end

  def fetch(key, **options)
    @fetch_calls << { key: key, options: options }
    if @data.key?(key)
      @data[key]
    else
      value = yield
      @data[key] = value
      value
    end
  end
end

# Stub objects for caching tests
CacheUser = Struct.new(:id, :first_name, :email)
CacheVideo = Struct.new(:id, :caption, :approved, :updated_at, :creator)
CacheComment = Struct.new(:id, :body)
CacheArticle = Struct.new(:id, :title, :comments)

class CachedUserSerializer < Oaken::Serializer
  include Oaken::Caching

  def serialize(user)
    cached(["v1", "user", user.id]) do
      { id: user.id, first_name: user.first_name, email: user.email }
    end
  end
end

class CachedCommentSerializer < Oaken::Serializer
  include Oaken::Caching

  def serialize(comment)
    cached(["v1", "comment", comment.id]) do
      { id: comment.id, body: comment.body }
    end
  end
end

class CachedArticleSerializer < Oaken::Serializer
  include Oaken::Caching

  def serialize(article)
    cached(["v1", "article", article.id]) do
      {
        id: article.id,
        title: article.title,
        comments: nest_many(CachedCommentSerializer, article.comments)
      }
    end
  end
end

class CachedVideoSerializer < Oaken::Serializer
  include Oaken::Caching

  def serialize(video)
    cached(["v1", "video", video.id, video.updated_at], expires_in: 600) do
      {
        id: video.id,
        caption: video.caption,
        creator: nest(CachedUserSerializer, video.creator)
      }
    end
  end
end

class NonCachedSerializer < Oaken::Serializer
  def serialize(obj)
    { id: obj.id }
  end
end

class CachedContextSerializer < Oaken::Serializer
  include Oaken::Caching

  def serialize(user)
    cache_key = ["v1", "user", user.id, context[:full] ? "full" : "mini"]
    cached(cache_key) do
      result = { id: user.id, first_name: user.first_name }
      result[:email] = user.email if context[:full]
      result
    end
  end
end

class CachedNestSerializer < Oaken::Serializer
  include Oaken::Caching

  def serialize(video)
    cached(["v1", "nest_test", video.id]) do
      {
        id: video.id,
        creator: nest(CachedUserSerializer, video.creator)
      }
    end
  end
end

class CachedNestManySerializer < Oaken::Serializer
  include Oaken::Caching

  def serialize(article)
    cached(["v1", "nest_many_test", article.id]) do
      {
        id: article.id,
        comments: nest_many(CachedCommentSerializer, article.comments)
      }
    end
  end
end

class CachingTest < Minitest::Test
  def setup
    @store = MemoryStore.new
    Oaken::Caching.cache_store = @store
    @user = CacheUser.new(1, "Jane", "jane@example.com")
  end

  def teardown
    Oaken::Caching.cache_store = nil
  end

  # Basic caching tests

  def test_cached_returns_serialized_hash
    result = CachedUserSerializer.new.serialize(@user)
    assert_equal({ id: 1, first_name: "Jane", email: "jane@example.com" }, result)
  end

  def test_to_json_works_with_cached_serializer
    json = CachedUserSerializer.new.to_json(@user)
    parsed = JSON.parse(json)
    assert_equal 1, parsed["id"]
    assert_equal "Jane", parsed["first_name"]
    assert_equal "jane@example.com", parsed["email"]
  end

  def test_cache_hit_on_second_call
    serializer = CachedUserSerializer.new
    first_result = serializer.serialize(@user)

    # Mutate the object — cached result should be stale
    @user.first_name = "MODIFIED"
    second_result = serializer.serialize(@user)

    assert_equal "Jane", first_result[:first_name]
    assert_equal "Jane", second_result[:first_name], "Expected stale cached data"
  end

  def test_different_cache_keys_produce_different_values
    user_a = CacheUser.new(1, "Jane", "jane@example.com")
    user_b = CacheUser.new(2, "John", "john@example.com")

    serializer = CachedUserSerializer.new
    result_a = serializer.serialize(user_a)
    result_b = serializer.serialize(user_b)

    assert_equal "Jane", result_a[:first_name]
    assert_equal "John", result_b[:first_name]
  end

  def test_cache_miss_calls_block_and_stores_result
    CachedUserSerializer.new.serialize(@user)

    assert_equal 1, @store.fetch_calls.length
    assert @store.data.key?(["v1", "user", 1])
    assert_equal({ id: 1, first_name: "Jane", email: "jane@example.com" }, @store.data[["v1", "user", 1]])
  end

  # Cache key tests

  def test_array_keys_work
    serializer = CachedUserSerializer.new
    serializer.serialize(@user)

    assert @store.data.key?(["v1", "user", 1])
  end

  def test_string_keys_work
    klass = Class.new(Oaken::Serializer) do
      include Oaken::Caching
      def serialize(user)
        cached("user-#{user.id}") do
          { id: user.id }
        end
      end
    end

    klass.new.serialize(@user)
    assert @store.data.key?("user-1")
  end

  # Cache options tests

  def test_expires_in_forwarded_to_cache_store
    creator = CacheUser.new(10, "Creator", "creator@example.com")
    video = CacheVideo.new(1, "Kickflip", true, "2024-01-01", creator)

    CachedVideoSerializer.new.serialize(video)

    video_call = @store.fetch_calls.find { |c| c[:key][2] == video.id && c[:key][0] == "v1" && c[:key][1] == "video" }
    assert video_call, "Expected a fetch call for the video"
    assert_equal 600, video_call[:options][:expires_in]
  end

  def test_no_options_when_expires_in_is_nil
    CachedUserSerializer.new.serialize(@user)

    call = @store.fetch_calls.first
    refute call[:options].key?(:expires_in)
  end

  # Error handling tests

  def test_raises_runtime_error_without_configured_cache_store
    Oaken::Caching.cache_store = nil

    assert_raises(RuntimeError) do
      CachedUserSerializer.new.serialize(@user)
    end
  end

  def test_error_message_mentions_configuration
    Oaken::Caching.cache_store = nil

    error = assert_raises(RuntimeError) do
      CachedUserSerializer.new.serialize(@user)
    end
    assert_match(/cache_store/, error.message)
    assert_match(/not configured/, error.message)
  end

  # Nil/edge case tests

  def test_block_returning_nil_caches_nil
    klass = Class.new(Oaken::Serializer) do
      include Oaken::Caching
      def serialize(obj)
        cached("nil-key") { nil }
      end
    end

    result = klass.new.serialize(@user)
    assert_nil result
    assert @store.data.key?("nil-key")
  end

  def test_block_returning_false_caches_false
    klass = Class.new(Oaken::Serializer) do
      include Oaken::Caching
      def serialize(obj)
        cached("false-key") { false }
      end
    end

    result = klass.new.serialize(@user)
    assert_equal false, result
    assert @store.data.key?("false-key")
  end

  def test_block_returning_empty_hash_works
    klass = Class.new(Oaken::Serializer) do
      include Oaken::Caching
      def serialize(obj)
        cached("empty-key") { {} }
      end
    end

    result = klass.new.serialize(@user)
    assert_equal({}, result)
  end

  def test_cached_block_with_nest_inside
    creator = CacheUser.new(10, "Creator", "creator@example.com")
    video = CacheVideo.new(1, "Kickflip", true, "2024-01-01", creator)

    serializer = CachedNestSerializer.new
    result = serializer.serialize(video)

    assert_equal 1, result[:id]
    assert_equal 10, result[:creator][:id]
    assert_equal "Creator", result[:creator][:first_name]
  end

  def test_cached_block_with_nest_many_inside
    comments = [CacheComment.new(1, "Great!"), CacheComment.new(2, "Nice!")]
    article = CacheArticle.new(10, "My Article", comments)

    serializer = CachedNestManySerializer.new
    result = serializer.serialize(article)

    assert_equal 10, result[:id]
    assert_equal 2, result[:comments].length
    assert_equal "Great!", result[:comments][0][:body]
  end

  # Integration tests

  def test_to_json_on_cached_serializer_with_nested_cached_serializers
    creator = CacheUser.new(10, "Creator", "creator@example.com")
    video = CacheVideo.new(1, "Kickflip", true, "2024-01-01", creator)

    json = CachedVideoSerializer.new.to_json(video)
    parsed = JSON.parse(json)

    assert_equal 1, parsed["id"]
    assert_equal "Kickflip", parsed["caption"]
    assert_equal 10, parsed["creator"]["id"]
    assert_equal "Creator", parsed["creator"]["first_name"]
  end

  def test_caching_with_context
    mini_serializer = CachedContextSerializer.new
    full_serializer = CachedContextSerializer.new(context: { full: true })

    mini_result = mini_serializer.serialize(@user)
    full_result = full_serializer.serialize(@user)

    refute mini_result.key?(:email)
    assert_equal "jane@example.com", full_result[:email]
  end

  # Isolation tests

  def test_including_caching_in_one_serializer_does_not_affect_others
    refute NonCachedSerializer.method_defined?(:cached),
      "NonCachedSerializer should not have cached method"
  end

  def test_cached_method_unavailable_without_including_module
    serializer = NonCachedSerializer.new
    refute serializer.respond_to?(:cached)
  end
end
