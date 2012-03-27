require 'spec_helper'

describe ActsAsStream::StreamActivity do

  before :each do
    @user = Factory :user
    @widget = Factory :widget
    @admin = Factory :admin
    @time = Time.now.to_i
    @valid_options = {:who => @user,
                      :action => "Tested StreamActivity!",
                      :time => Time.at(@time),
                      :object => @widget}
    @valid_json = "{\"time\":#{@time},\"who\":{\"user\":{\"id\":#{@user.id}}},\"action\":\"Tested StreamActivity!\",\"object\":{\"widget\":{\"id\":#{@widget.id}}}}"
  end

  describe "parse" do
    it "should probably parse JSON to a hash with symbol keys" do
      hash = ActsAsStream.parse(package(@valid_options))
      @valid_options.keys.each{|k| hash[k].should == @valid_options[k]}
    end
  end

  describe "time" do
    it "should create a valid package with all valid options" do
      package(@valid_options).should == @valid_json
    end

    it "should create a valid package without a time" do
      options = @valid_options.dup
      options.delete(:time)
      #Making an assumption this won't block on time!
      time = Time.now.to_i

      json = "{\"time\":#{time},\"who\":{\"user\":{\"id\":#{@user.id}}},\"action\":\"Tested StreamActivity!\",\"object\":{\"widget\":{\"id\":#{@widget.id}}}}"
      package(options).should == json
    end

    it "should create a valid package with a Time object" do
      options = @valid_options.dup
      time = Time.now
      options[:time] = time
      #Making an assumption this won't block on time!
      json = "{\"time\":#{time.to_i},\"who\":{\"user\":{\"id\":#{@user.id}}},\"action\":\"Tested StreamActivity!\",\"object\":{\"widget\":{\"id\":#{@widget.id}}}}"
      decode(package(options)).should == decode(json)
    end
  end

  describe "stream_hash" do
    it "should correctly create a stream hash" do
      json = {:widget =>{ :id => @widget.id}}
      @widget.to_stream_hash.should == json
    end
    it "should correctly create a stream hash with a non-id attribute" do
      json = {:admin =>{ :id => @admin.id, :guid => @admin.guid}}
      @admin.to_stream_hash.should == json
    end

    it "should respond correctly with an object that does not" do
      class TestObject;end
      options = @valid_options.dup
      options[:object] = TestObject.new
      lambda {package(options)}.should raise_error
    end
  end


  describe ActsAsStream::StreamableObject do
    it "should create a package with the instance method" do
      options = @valid_options.dup
      time = Time.now.to_i
      options[:time] = time
      decode(@user.package(:action => "Tested StreamActivity!", :object => @widget)).should == decode(package(options))
    end
  end

  private

  def decode json
    ActiveSupport::JSON.decode(json)
  end
  def package(options={})
    ActsAsStream.package options
  end
end