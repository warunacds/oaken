# frozen_string_literal: true

module Oaken
  class Serializer
    def serialize(object)
      raise NotImplementedError, "#{self.class}#serialize must be implemented"
    end

    def to_json(object)
      if object.is_a?(Array)
        Oj.dump(object.map { |item| serialize(item) }, mode: :compat)
      else
        Oj.dump(serialize(object), mode: :compat)
      end
    end

    # Both nest and nest_many cache serializer instances per class.
    # Nested serializer subclasses must be stateless (no mutable instance variables).
    def nest(serializer_class, object)
      return nil if object.nil?
      @_nest_cache ||= {}
      (@_nest_cache[serializer_class] ||= serializer_class.new).serialize(object)
    end

    def nest_many(serializer_class, collection)
      return [] if collection.nil?
      @_nest_cache ||= {}
      instance = (@_nest_cache[serializer_class] ||= serializer_class.new)
      collection.map { |item| instance.serialize(item) }
    end
  end
end
