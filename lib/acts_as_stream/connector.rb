module ActsAsStream
  module Connector

    def register_new_activity! package = nil, key = nil
      return if package.nil?
      id = increment!
      ActsAsStream.redis.multi do
        time = Time.now.to_i
        #Add the key and package to the system
        ActsAsStream.redis.set "#{base_key}:#{id}", package
        #Add the id to a sorted set scored by time
        ActsAsStream.redis.zadd "#{base_key}:sorted", time, id
        if key.present?
          ActsAsStream.redis.zadd key, time, id
        end
      end
      id
    end

    def deregister_activity! ident, key = nil, mentions_key = nil
      return if ident.nil?
      ActsAsStream.redis.multi do
        ActsAsStream.redis.del "#{base_key}:#{ident}"
        ActsAsStream.redis.zrem "#{base_key}:sorted", ident
        if key.present?
          ActsAsStream.redis.zrem key, ident
        end
      end
      deregister_followers! ident
      if mentions_key.present?
        deregister_mentioned! ident, mentions_key
      end
    end

    def register_followers! options = {}
      options.assert_valid_keys(:following_keys, :activity_id)
      return if options[:following_keys].nil? or options[:activity_id].nil?
      raise ":following_keys must be an array of keys" if not options[:following_keys].is_a? Array
      ActsAsStream.redis.multi do
        options[:following_keys].each do |key|
          ActsAsStream.redis.zadd key, Time.now.to_i, options[:activity_id]
          ActsAsStream.redis.lpush "#{base_key}:#{options[:activity_id]}:followers", key
        end
      end
    end

    def deregister_followers! activity_id = nil
      return if activity_id.nil?
      followers_key = "#{base_key}:#{activity_id}:followers"
      len = ActsAsStream.redis.llen followers_key
      followers = ActsAsStream.redis.lrange followers_key, 0, len
      return if followers.nil?
      ActsAsStream.redis.multi do
        followers.each do |f|
          ActsAsStream.redis.zrem f, activity_id
        end
        ActsAsStream.redis.del "#{base_key}:#{activity_id}:followers"
      end
    end

    def register_mentions! options = {}
      options.assert_valid_keys(:mentioned_keys, :activity_id, :key)
      raise "Not all arguments present, need all of [:mentioned_keys, :activity_id, :key]" if options[:mentioned_keys].nil? or options[:activity_id].nil? or options[:key].nil?
      raise ":mentioned_keys must be an array of keys" if not options[:mentioned_keys].is_a? Array
      time = Time.now.to_i
      ActsAsStream.redis.multi do
        options[:mentioned_keys].each do |key|
          ActsAsStream.redis.zadd key, time, options[:activity_id]
          ActsAsStream.redis.lpush "#{base_key}:#{options[:activity_id]}:mentions", key
          ActsAsStream.redis.zadd options[:key], time, options[:activity_id]
        end
      end
      time
    end

    def deregister_mentioned! activity_id = nil, key = nil
      raise "Need activity id and a key" if activity_id.nil? or key.nil?
      mentioned_key = "#{base_key}:#{activity_id}:mentions"
      return if mentioned_key.nil?
      len = ActsAsStream.redis.llen mentioned_key
      mentioned = ActsAsStream.redis.lrange mentioned_key, 0, len
      return if mentioned.nil?
      ActsAsStream.redis.multi do
        mentioned.each do |f|
          ActsAsStream.redis.zrem f, activity_id
        end
        ActsAsStream.redis.del "#{base_key}:#{activity_id}:mentions"
        ActsAsStream.redis.zrem key, activity_id
      end
    end
    
    def get_activity_for key, options = {}
      offsets = get_offsets({:key => key}.merge options)
      ActsAsStream.redis.zrevrange(key, offsets[:start], offsets[:end], :with_scores => false).map{|i| get_activity i}
    end

    def get_offsets(options = {})
      options = {:page => 1, :page_size => ActsAsStream.page_size}.merge options
      options[:page] = 1 if options[:page] < 1

      if options[:page] > total_pages(options[:key], options[:page_size])
        options[:page] = total_pages(options[:key], options[:page_size])
      end

      starting_offset = ((options[:page] - 1) * options[:page_size])
      starting_offset = 0 if starting_offset < 0
      ending_offset = (starting_offset + options[:page_size]) - 1
      {:start => starting_offset, :end => ending_offset}
    end

    def get_activity id
      ActsAsStream.redis.get "#{base_key}:#{id}"
    end
    def get_activity_mentions id
      ActsAsStream.redis.lrange "#{base_key}:#{id}:mentions", 0, -1
    end

    def total_pages key, page_size = ActsAsStream.page_size
      (ActsAsStream.redis.zcard(key) / page_size.to_f).ceil
    end

    def count
      ActsAsStream.redis.get(ActsAsStream.activity_incr).to_i
    end

    def base_key
      "#{ActsAsStream.namespace}:#{ActsAsStream.activity_scope}"
    end
    def get_recent_activity(count=10)
      ActsAsStream.redis.mget *((ActsAsStream.count - count)...ActsAsStream.count).to_a.reverse.map{|i| "#{ActsAsStream.base_key}:#{i}"}
    end
    private

    def increment!
      ActsAsStream.redis.incr(ActsAsStream.activity_incr)
    end
    def time
      Time.now.to_i
    end
  end
end