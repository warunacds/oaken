# Oaken

High-performance Ruby JSON serializer. Uses [Oj](https://github.com/ohler55/oj) under the hood. Simple class-based API with no DSL magic — explicit, predictable, and LLM-friendly.

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

Results on Ruby 4.0.1 (arm64-darwin):

| Scenario | Oaken | Alba | Blueprinter |
|---|---|---|---|
| Single nested object | 399,890 i/s | 49,081 i/s (8.15x slower) | 19,148 i/s (20.88x slower) |
| Collection of 50 nested | 8,449 i/s | 1,033 i/s (8.18x slower) | 397 i/s (21.26x slower) |

## Design philosophy

- **Explicit over implicit** — no metaprogramming, no DSL magic
- **LLM-friendly** — simple, predictable patterns that AI assistants generate correctly every time
- **Single Oj.dump** — nested serializers return Hashes, not strings
- **No Rails dependency** — works with any Ruby 4+ project

## License

MIT
