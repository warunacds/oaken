# frozen_string_literal: true

module Oaken
  module Caching
    def self.cache_store
      @cache_store
    end

    def self.cache_store=(store)
      @cache_store = store
    end

    def cached(key, expires_in: nil)
      store = Oaken::Caching.cache_store
      raise "Oaken::Caching.cache_store is not configured" unless store
      options = {}
      options[:expires_in] = expires_in if expires_in
      store.fetch(key, **options) { yield }
    end
  end
end
