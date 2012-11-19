module ActsAsStream
  module StreamableObject

    def self.included base
      base.extend ClassMethods
    end

    module ClassMethods

      def acts_as_stream options = {}
        cattr_accessor :activity_scope,
                       :activity_attr,
                       :activity_key_base,
                       :followers_attr,
                       :mentions_scope,
                       :mentions_key_base
        self.activity_scope = options[:activity_scope] || ActsAsStream.activity_scope
        self.mentions_scope = options[:mentions_scope] || ActsAsStream.mentions_scope
        self.activity_attr = options[:activity_attr] || ActsAsStream.activity_attr
        self.activity_key_base = "#{ActsAsStream.namespace}:#{self.activity_scope}"
        self.followers_attr = options[:followers_attr] || :all_followers
        send :include, ActsAsStream::StreamableObject::InstanceMethods
        unless options[:ignore_mentions]
          self.mentions_key_base = "#{ActsAsStream.namespace}:#{self.mentions_scope}"
          send :include, ActsAsStream::StreamableObject::MentionsMethods
        end
      end
    end

    module InstanceMethods

      def to_stream_hash
        {self.class.name.tableize.singularize.to_sym => {:id => self.id, activity_attr.to_sym => self.send(activity_attr)}}
      end
      def streamable_object_id
        "#{self.class.name.tableize.singularize}:#{self.send(self.class.activity_attr)}"
      end
      def activity_key
        "#{self.class.activity_key_base}:by:#{streamable_object_id}"
      end
      def following_key
        "#{self.class.activity_key_base}:for:#{streamable_object_id}"
      end
      def register_activity! package
        act_id = ActsAsStream.register_new_activity! package, activity_key
        self.register_followers! act_id
        act_id
      end

      def delete_activity act_id
        ActsAsStream.deregister_activity! act_id, activity_key
        ActsAsStream.deregister_mentions! act_id, mentions_key if respond_to? mentions_key
      end

      def register_followers! act_id
        ActsAsStream.register_followers! :following_keys => get_follower_keys, :activity_id => act_id
      end

      def get_follower_keys
        send(followers_attr)
      end

      def package(options = {})
        options.assert_valid_keys(:who, :action, :object, :ignore_stream_hash_on)
        options[:who] ||= self
        options[:time] = Time.now.to_i
        ActsAsStream.package options
      end

      def get_activity_for(options = {})
        options = {:whom => :others}.merge options
        self.send("get_#{options[:whom]}_activity", options)
      end
      def get_own_activity(options = {})
        options[:key] = activity_key
        get_activity options
      end
      def get_others_activity(options = {})
        options[:key] = following_key
        get_activity options
      end
      def activity_count since=nil
        since = since.present? ? "(#{since}" : "-inf"
        ActsAsStream.redis.zcount following_key, since, "+inf"
      end
      private

      def get_activity(options = {})
        options[:page_size] = activity_count if options[:all] and activity_count > 0
        options = {:page_size => ActsAsStream.page_size, :page => 1}.merge options
        ActsAsStream.get_activity_for options[:key], :page_size => options[:page_size], :page => options[:page]
      end

    end

    module MentionsMethods
      def register_mentions!(options = {})
        options = {:key => mentions_key}.merge options
        options[:mentioned_keys] = [options[:mentioned_keys]] unless options[:mentioned_keys].is_a?(Array)
        ActsAsStream.register_mentions! options
      end
      def mentioned_by_others_key
        "#{self.class.mentions_key_base}:of:#{streamable_object_id}"
      end
      def mentions_key
        "#{self.class.mentions_key_base}:by:#{streamable_object_id}"
      end
      def mentions_count since = nil
        since ||= 0
        ActsAsStream.redis.zcount mentioned_by_others_key, "(#{since}", "+inf"
      end
      def get_mentions_activity(options = {})
        options[:key] = mentioned_by_others_key
        get_activity options
      end
      def get_own_mentions_activity(options = {})
        options[:key] = mentions_key
        get_activity options
      end

      private

      def get_mentions(options = {})
        options[:page_size] = mentions_count if options[:all]
        options = {:page_size => ActsAsStream.page_size, :page => 1}.merge options
        ActsAsStream.get_activity_for options[:key], :page_size => options[:page_size], :page => options[:page]
      end


    end
  end
end