# frozen_string_literal: true

require "oj"
require_relative "oaken/version"
require_relative "oaken/serializer"
require_relative "oaken/caching"

module Oaken
  def self.extract(object, *attributes)
    result = {}
    attributes.each { |attr| result[attr.to_sym] = object.public_send(attr) }
    result
  end
end
