require 'spec_helper'

describe "app" do
  include Rack::Test::Methods

  def app
    Redmon::App.new(Redmon::DEFAULT_OPTS)
  end

  def stub_redis_cmd(cmd, *args)
    mock_redis.should_receive(cmd).with(*args).and_return({})
  end

  def mock_redis
    redis = double :redis
    Redis.stub(:connect).and_return(redis)
    redis
  end

  let(:json) {"application/json;charset=utf-8"}

  describe "GET /" do
    it "should render the app" do
      stub_redis_cmd :config, :get, '*'
      get "/"
      last_response.should be_ok
      last_response.body.include?('Redmon')
    end
  end

  describe "GET /config" do
    it "should render the redis config params" do
      stub_redis_cmd :config, :get, '*'
      get "/config"
      last_response.should be_ok
      last_response.headers["Content-Type"].should == json
    end
  end

  describe "PUT /config" do
    it "should set a redis config param" do
      stub_redis_cmd :config, :set, 'param', 'value'
      put "/config?param=param&value=value"
      last_response.should be_ok
    end
  end

  describe "GET /cli" do
    let(:params) { URI.encode("keys *") }

    it "should execute the passed command" do
      stub_redis_cmd :keys, '*'
      get URI.encode("/cli?tokens=keys *")
      last_response.should be_ok
    end

    it "should render an empty list result" do
      redis = mock_redis
      redis.stub(:send).and_return([])

      get "/cli?tokens=#{params}"
      last_response.should be_ok
      last_response.body.include? Redmon::RedisUtils.empty_result
    end

    it "should render the wrong arguments result" do
      redis = mock_redis
      redis.stub(:send).and_raise(ArgumentError)

      get "/cli?tokens=#{params}"
      last_response.should be_ok
      last_response.body.include? Redmon::RedisUtils.wrong_number_of_arguments_for(:keys)
    end

    it "should return an unknown result" do
      redis = mock_redis
      redis.stub(:send).and_raise(RuntimeError)

      get "/cli?tokens=#{params}"
      last_response.should be_ok
      last_response.body.include? Redmon::RedisUtils.unknown(:keys)
    end

    it "should return a connection refused result" do
      redis = mock_redis
      redis.stub(:send).and_raise(Errno::ECONNREFUSED)

      get "/cli?tokens=#{params}"
      last_response.should be_ok
      last_response.body.include? Redmon::RedisUtils.connection_refused_for(Redmon::DEFAULT_OPTS[:redis_url])
    end
  end

  describe "GET /info" do
    it "should render a single json result" do
      stub_redis_cmd :zrange, 'redmon:redis.info', -1, -1
      get "/info"
      last_response.should be_ok
      last_response.headers["Content-Type"].should == json
    end

    it "should request the correct # of historical info records from redis" do
      stub_redis_cmd :zrange, 'redmon:redis.info', -666, -1
      get "/info?count=666"
      last_response.should be_ok
    end
  end

end