# Oaken

High-performance Ruby JSON serializer. Uses [Oj](https://github.com/ohler55/oj) under the hood. Simple class-based API with no DSL magic — explicit, predictable, and LLM-friendly.

[![Gem Version](https://badge.fury.io/rb/oaken.svg)](https://rubygems.org/gems/oaken)

## Installation

```ruby
gem "oaken"
```

## Usage

### Define a serializer

```ruby
class UserSerializer < Oaken::Serializer
  def serialize(user)
    {
      id: user.id,
      first_name: user.first_name,
      email: user.email
    }
  end
end
```

### Serialize a single object

```ruby
UserSerializer.new.to_json(user)
# => '{"id":1,"first_name":"Jane","email":"jane@example.com"}'
```

### Serialize a collection

```ruby
UserSerializer.new.to_json([user1, user2])
# => '[{"id":1,...},{"id":2,...}]'
```

### Nest serializers

```ruby
class PostSerializer < Oaken::Serializer
  def serialize(post)
    {
      id: post.id,
      title: post.title,
      author: nest(UserSerializer, post.author),
      comments: nest_many(CommentSerializer, post.comments)
    }
  end
end
```

`nest` returns `nil` if the object is `nil`. `nest_many` returns `[]` if the collection is `nil` or empty.

Both `nest` and `nest_many` return plain Ruby Hashes — not JSON strings — so there is only one `Oj.dump` call at the outermost level. No double-serialization overhead.

### Extract attributes

`Oaken.extract` pulls attributes from an object into a Hash. It uses `public_send`, so private methods are not accessible.

```ruby
def serialize(user)
  Oaken.extract(user, :id, :first_name, :email)
  # => { id: 1, first_name: "Jane", email: "jane@example.com" }
end
```

Combine with `.merge` for computed fields:

```ruby
def serialize(user)
  Oaken.extract(user, :id, :first_name, :email).merge(
    crew_code: user.crew&.code,
    full_name: "#{user.first_name} #{user.last_name}"
  )
end
```

### Context

Pass request-specific data (flags, current user, etc.) via `context`:

```ruby
# Controller
render json: UserSerializer.new(context: { full: true }).to_json(@user)

# Serializer
class UserSerializer < Oaken::Serializer
  def serialize(user)
    result = Oaken.extract(user, :id, :first_name)
    result[:email] = user.email if context[:full]
    result
  end
end
```

Context propagates automatically through `nest` and `nest_many` — child serializers receive the same context as the parent.

```ruby
class PostSerializer < Oaken::Serializer
  def serialize(post)
    {
      id: post.id,
      title: post.title,
      author: nest(UserSerializer, post.author) # UserSerializer gets the same context
    }
  end
end
```

Context defaults to an empty Hash, so existing serializers work without changes.

### Caching

Opt-in caching via `Oaken::Caching`. Works with any cache store that implements `.fetch(key, **options, &block)` (e.g., `Rails.cache`, `ActiveSupport::Cache::MemoryStore`).

**Setup** (Rails example):

```ruby
# config/initializers/oaken.rb
Oaken::Caching.cache_store = Rails.cache
```

**Usage:**

```ruby
class SkateVideoSerializer < Oaken::Serializer
  include Oaken::Caching

  def serialize(video)
    cached(["v1", "skate_video", video.id, video.updated_at], expires_in: 10.minutes) do
      Oaken.extract(video, :id, :caption, :approved).merge(
        creator: nest(UserSerializer, video.creator)
      )
    end
  end
end
```

The `cached` method wraps the block with a cache store `.fetch` call. You control the cache key and TTL — no magic key generation. Including `Oaken::Caching` only affects the serializer it is included in.

## Important: instantiate per request

Always create a new serializer instance per request. Do not store serializer instances in constants or class-level variables — `nest` and `nest_many` cache nested serializer instances on the serializer object, so a shared instance will hold onto those caches indefinitely.

```ruby
# ✅ Correct — fresh instance per request
ActivityItemSerializer.new.to_json(item)

# ❌ Dangerous — cache persists across requests
SERIALIZER = ActivityItemSerializer.new
SERIALIZER.to_json(item)
```

## Benchmarks

Run `bundle exec ruby benchmarks/bench.rb` to compare against Alba and Blueprinter.

Results on Ruby 3.3.6 (arm64-darwin):

| Scenario | Oaken | Alba | Blueprinter |
|---|---|---|---|
| Single nested object | 399,890 i/s | 49,081 i/s (8.15x slower) | 19,148 i/s (20.88x slower) |
| Collection of 50 nested | 8,449 i/s | 1,033 i/s (8.18x slower) | 397 i/s (21.26x slower) |

## Design philosophy

- **Explicit over implicit** — no metaprogramming, no DSL magic
- **LLM-friendly** — simple, predictable patterns that AI assistants generate correctly every time
- **Single Oj.dump** — nested serializers return Hashes, not strings
- **No Rails dependency** — works with any Ruby 3.1+ project
- **Opt-in caching** — include `Oaken::Caching` only where needed, with explicit cache keys

## License

MIT
