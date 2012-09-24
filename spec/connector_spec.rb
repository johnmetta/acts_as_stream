require 'spec_helper'

describe ActsAsStream::Connector do

  before :each do
    @user = Factory :user
    @admin = Factory :admin
    @widget = Factory :widget
    @thing = Factory :thing
    @key = ActsAsStream.base_key
    @sorted_key = "#{@key}:sorted"
    @count = ActsAsStream.redis.zcard(@sorted_key)
    @package = test_package
  end

  describe "Id Counter" do
    it "should automatically score" do
      time = Time.now.to_i
      sleep 1
      ActsAsStream.register_new_activity! @package
      key = "#{@key}:#{ActsAsStream.count}"
      ActsAsStream.redis.get(key).should == @package
    end

    it "should get the counter incrementor" do
      counter = ActsAsStream.count
      counter.should be(0)
    end

    it "should get a correct page count" do
      key = @user.following_key
      acts = (1..3).collect{ActsAsStream.register_new_activity! @package}
      acts.each{|a| ActsAsStream.register_followers! :following_keys => [key], :activity_id => a}

      ActsAsStream.total_pages(key).should be(1)
      ActsAsStream.total_pages(key, 2).should be(2)
    end
  end

  describe "registration" do

    it "should register a new activity" do
      ActsAsStream.register_new_activity! @package
      key = "#{@key}:#{ActsAsStream.count}"
      ActsAsStream.redis.get(key).should == @package
    end

    it "should register time keys with new activity" do
      # we're assuming this test will take less than one second!
      time = Time.now.to_i
      id = ActsAsStream.register_new_activity! @package

      ActsAsStream.redis.get("#{@key}:#{id}").should == @package
      ActsAsStream.redis.zcard(@sorted_key).should eq(@count + 1)
      ActsAsStream.redis.zrevrange(@sorted_key,0,-1,:with_scores => false).include?("#{id}").should be_true
    end

  end

  describe "Deregistration" do
    it "should remove all keys on deregistration" do
      # we're assuming this test will take less than one second!
      time = Time.now.to_i
      package = test_package
      id = ActsAsStream.register_new_activity! package

      ActsAsStream.redis.get("#{@key}:#{id}").should == package
      ActsAsStream.redis.zcard(@sorted_key).should eq(@count + 1)
      ActsAsStream.redis.zrange(@sorted_key,0,-1,:with_scores => false).include?("#{id}").should be_true

      ActsAsStream.deregister_activity! id

      ActsAsStream.redis.get("#{@key}:#{id}").should be(nil)
      ActsAsStream.redis.zcard(@sorted_key).should eq(@count)
      ActsAsStream.redis.zrange(@sorted_key,0,-1,:with_scores => false).include?(id).should be_false
    end
    it "should deregister an activity" do
      ActsAsStream.register_new_activity! @package
      key = "#{@key}:#{ActsAsStream.count}"
      ActsAsStream.redis.get(key).should == @package

      ActsAsStream.deregister_activity! ActsAsStream.count
      ActsAsStream.redis.get(key).should be(nil)
    end

  end

  describe "followers" do

    it "should add a weighted record to the sorted set for a list of followers" do
      id = ActsAsStream.register_new_activity! @package
      followers = [23,32,42].map{|f| "#{@key}:user:#{f}"}
      ActsAsStream.register_followers! :following_keys => followers, :activity_id => id

      followers.each do |f|
        ActsAsStream.redis.zcard(f).should be(1)
        ActsAsStream.redis.zrevrange(f,0,-1,:with_scores=>false).should =~ ["#{id}"]
        ActsAsStream.redis.lrange("#{@key}:#{id}:followers",0,15).include?(f).should be_true
      end
      ActsAsStream.redis.llen("#{@key}:#{id}:followers").should be(3)
    end
    it "should return a correct list of packaged activities for a follower key" do
      key = @user.following_key
      packages = (1..3).collect{|i| test_package i}
      packages.each do |p|
        id = ActsAsStream.register_new_activity! p
        ActsAsStream.register_followers! :following_keys => [key], :activity_id => id
      end
      ActsAsStream.total_pages(key).should be(1)
      ActsAsStream.get_activity_for(key).should =~ packages
      ActsAsStream.get_activity_for(key, :page_size => 2).size.should be(2)
      ActsAsStream.redis.zrevrange(key,0,-1,:with_scores=>false).count.should be(3)
      ActsAsStream.get_activity_for(key, :page_size => 2, :page => 10).count.should be(1)
    end

    it "should remove followers on deregistration" do
      id = ActsAsStream.register_new_activity! @package
      followers = [56,43,65].map{|f| "#{@key}:user:#{f}"}
      ActsAsStream.register_followers! :following_keys => followers, :activity_id => id

      followers.each do |f|
        ActsAsStream.redis.zcard(f).should be(1)
        ActsAsStream.redis.zrevrange(f,0,-1,:with_scores=>false).should =~ ["#{id}"]
        ActsAsStream.redis.lrange("#{@key}:#{id}:followers",0,15).include?(f).should be_true
      end
      ActsAsStream.redis.llen("#{@key}:#{id}:followers").should be(3)

      ActsAsStream.deregister_activity! id

      followers.each do |f|
        ActsAsStream.redis.zcard(f).should be(0)
        ActsAsStream.redis.lrange("#{@key}:#{id}:followers",0,15).include?(f).should be_false
      end
      ActsAsStream.redis.llen("#{@key}:#{id}:followers").should be(0)

    end
  end


  describe "mentions" do
    it "should not respond to mentions by default" do
      @widget.respond_to?(:mentioned_by_others_key).should be_false
    end
    it "should allow for a mentions system" do
      @user.respond_to?(:mentioned_by_others_key).should be_true
    end

    it "should add a weighted record to the sorted set for a list of mentions" do
      id = ActsAsStream.register_new_activity! @package
      mentioned = [23,32,42].map{|f| "#{@key}:user:#{f}"}
      ActsAsStream.register_mentions! :mentioned_keys => mentioned, :activity_id => id, :key => "test"

      mentioned.each do |f|
        ActsAsStream.redis.zcard(f).should be(1)
        ActsAsStream.redis.zrevrange(f,0,25,:with_scores=>false).should =~ ["#{id}"]
        ActsAsStream.redis.lrange("#{@key}:#{id}:mentions",0,15).include?(f).should be_true
      end
      ActsAsStream.redis.llen("#{@key}:#{id}:mentions").should be(3)
    end
    it "should return a correct list of packaged activities for a mentioned key" do
      key = @user.following_key
      packages = (1..3).collect{|i| test_package i}
      packages.each do |p|
        id = ActsAsStream.register_new_activity! p
        ActsAsStream.register_mentions! :mentioned_keys => [key], :activity_id => id, :key => @user.mentions_key
      end
      ActsAsStream.total_pages(key).should be(1)
      ActsAsStream.get_activity_for(key).should =~ packages
      ActsAsStream.get_activity_for(key, :page_size => 2).size.should be(2)
      ActsAsStream.get_activity_for(key, :page_size => 2, :page => 10).count.should be(1)
      ActsAsStream.get_activity_for(@user.mentions_key).count.should be(3)
    end

    it "should remove mentions on deregistration" do
      id = ActsAsStream.register_new_activity! @package
      mentions = [56,43,65].map{|f| "#{@key}:user:#{f}"}
      ActsAsStream.register_mentions! :mentioned_keys => mentions, :activity_id => id, :key => "test"

      mentions.each do |f|
        ActsAsStream.redis.zcard(f).should be(1)
        ActsAsStream.redis.zrevrange(f,0,25,:with_scores=>false).should =~ ["#{id}"]
        ActsAsStream.redis.lrange("#{@key}:#{id}:mentions",0,15).include?(f).should be_true
      end
      ActsAsStream.redis.llen("#{@key}:#{id}:mentions").should be(3)

      ActsAsStream.deregister_activity! id
      ActsAsStream.deregister_mentioned! id, "test"

      mentions.each do |f|
        ActsAsStream.redis.zcard(f).should be(0)
        ActsAsStream.redis.lrange("#{@key}:#{id}:mentions",0,15).include?(f).should be_false
      end
      ActsAsStream.redis.llen("#{@key}:#{id}:mentions").should be(0)

    end

    it "should return a list of recent activity" do
      key = @user.following_key
      packages = (1..10).collect{|i| test_package i}
      packages.each do |p|
        id = ActsAsStream.register_new_activity! p
        ActsAsStream.register_mentions! :mentioned_keys => [key], :activity_id => id, :key => @user.mentions_key
      end
      ActsAsStream.get_recent_activity(10).should have(10).items
      ActsAsStream.get_recent_activity(3).should have(3).items
    end

  end

  private

  def test_package number = nil
    if number
      "{'test':'#{Time.now}','number':'#{number}'}"
    else
      "{'test':#{Time.now}}"
    end
  end

end