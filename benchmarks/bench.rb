# frozen_string_literal: true

require "benchmark/ips"
require "json"
require_relative "../lib/oaken"

# Alba setup
require "alba"
Alba.backend = :oj

# Blueprinter setup
require "blueprinter"

# --- Stub data ---
User = Struct.new(:id, :first_name, :last_name, :email)
Comment = Struct.new(:id, :body, :author)
Post = Struct.new(:id, :title, :author, :comments)

user     = User.new(1, "Jane", "Doe", "jane@example.com")
comments = 5.times.map { |i| Comment.new(i, "Comment #{i}", user) }
post     = Post.new(1, "Hello World", user, comments)
posts    = 50.times.map { |i| Post.new(i, "Post #{i}", user, comments) }

# --- Oaken ---
class OakenUserSerializer < Oaken::Serializer
  def serialize(u)
    { id: u.id, first_name: u.first_name, last_name: u.last_name, email: u.email }
  end
end

class OakenCommentSerializer < Oaken::Serializer
  def serialize(c)
    { id: c.id, body: c.body, author: nest(OakenUserSerializer, c.author) }
  end
end

class OakenPostSerializer < Oaken::Serializer
  def serialize(p)
    {
      id: p.id,
      title: p.title,
      author: nest(OakenUserSerializer, p.author),
      comments: nest_many(OakenCommentSerializer, p.comments)
    }
  end
end

# --- Alba ---
class AlbaUserSerializer
  include Alba::Resource
  attributes :id, :first_name, :last_name, :email
end

class AlbaCommentSerializer
  include Alba::Resource
  attributes :id, :body
  one :author, resource: AlbaUserSerializer
end

class AlbaPostSerializer
  include Alba::Resource
  attributes :id, :title
  one :author, resource: AlbaUserSerializer
  many :comments, resource: AlbaCommentSerializer
end

# --- Blueprinter ---
class BlueprintUserSerializer < Blueprinter::Base
  fields :id, :first_name, :last_name, :email
end

class BlueprintCommentSerializer < Blueprinter::Base
  fields :id, :body
  association :author, blueprint: BlueprintUserSerializer
end

class BlueprintPostSerializer < Blueprinter::Base
  fields :id, :title
  association :author, blueprint: BlueprintUserSerializer
  association :comments, blueprint: BlueprintCommentSerializer
end

puts "=== Single nested object ==="
Benchmark.ips do |x|
  x.report("Oaken")       { OakenPostSerializer.new.to_json(post) }
  x.report("Alba")        { AlbaPostSerializer.new(post).serialize }
  x.report("Blueprinter") { BlueprintPostSerializer.render(post) }
  x.compare!
end

puts "\n=== Collection of 50 nested objects ==="
Benchmark.ips do |x|
  x.report("Oaken")       { OakenPostSerializer.new.to_json(posts) }
  x.report("Alba")        { AlbaPostSerializer.new(posts).serialize }
  x.report("Blueprinter") { BlueprintPostSerializer.render(posts) }
  x.compare!
end
