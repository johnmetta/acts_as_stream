module ActsAsStream
  module StreamActivity

    def package options = {}
      options.assert_valid_keys(:who, :action, :time, :object)
      raise "You need at least a :who and an :action! to create an activity package" if options[:who].nil? or options[:action].nil?
      opts = {:time => Time.now.to_i}.merge options
      # Try to ensure :time is in seconds
      opts[:time] = opts[:time].to_i if opts[:time].is_a?(Time)

      [:who, :object].each do |opt|
        #unless we are ignoring the stream hash for this object, use StreamableObject.stream_hash
#        begin
          begin
            opts[opt] = opts[opt].to_stream_hash
          rescue NoMethodError
            raise "The model #{opts[opt].class.name} does not have a method called #{opts[opt].activity_attr}. Perhaps you should look at your ActsAsStream configuration, or set :activity_attr"
          end
#        rescue NoMethodError
#          raise "The model #{opts[opt].class.name} does not respond to the :to_stream_hash method. Make that happen, or use a custom packager"
#        end
      end
      # then, if everything is fine, bundle it up into a JSON string
      opts.to_json
    end
    
    def parse package
      package = JSON.parse(package)
      package.keys.each{|k| package[k.to_sym] = package[k]; package.delete(k)}

      # Try to cast :who and :object to instances, cowardly return nil if the record is not found, because it might have
      # been deleted from the SQL database and not de-registered from Redis
      begin
        package[:who].keys.each{|k| package[:who] = k.titleize.constantize.find(package[:who][k]["id"].to_i)}
      rescue RecordNotFound
        return nil
      end

      begin
        package[:object].keys.each{|k| package[:object] = k.titleize.constantize.find(package[:object][k]["id"].to_i)}
      rescue RecordNotFound
        return nil
      end
      package[:time] = Time.at package[:time].to_i
      package
    end

  end
end