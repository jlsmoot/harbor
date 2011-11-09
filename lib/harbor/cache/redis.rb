class Harbor::Cache::Redis < Harbor::Cache

  TRACKER_KEY_NAME="cache-keys"
  
  def initialize(redis)
    raise ArgumentError.new("+redis+ must not be nil") unless redis
    @redis = redis
  end

  def get(key)
    if (value = @redis.get(key))
      item = load(key, value)
      
      if item.expired?
        @redis.srem(TRACKER_KEY_NAME, key)
        nil
      else
        @redis.expire(key, item.ttl)
        item
      end
    else
      nil
    end
  end

  alias [] get

  def put(key, ttl, maximum_age, content, cached_at)
    item = Harbor::Cache::Item.new(key, ttl, maximum_age, content, cached_at)
    data = { "ttl" => item.ttl, "maximum_age" => item.maximum_age, "content" => item.content, "cached_at" => item.cached_at, "expires_at" => item.expires_at }
    @redis.set(key, YAML::dump(data))
    @redis.expire(key, ttl)
    @redis.sadd(TRACKER_KEY_NAME, key)
    item
  end

  def delete(key)
    @redis.del(key)
    @redis.srem(TRACKER_KEY_NAME, key)
  end

  def delete_matching(key_regex)
    if (matches = keys_matching(key_regex)).empty?
      nil
    else
      @redis.srem(TRACKER_KEY_NAME, *matches)
      @redis.del(*matches)
    end
  end
  
  def keys_matching(key_regex)
    @redis.smembers(TRACKER_KEY_NAME).select { |key| key =~ key_regex }
  end

  def bump(key)
    if item = get(key)
      delete(key)
      item.bump
      put(key, item.ttl, item.maximum_age, item.content, item.cached_at)
    end
  end
  
  def load(key, data)
    value = YAML::load(data)
    Harbor::Cache::Item.new(key, value["ttl"], value["maximum_age"], value["content"], value["cached_at"], value["expires_at"])
  end
end