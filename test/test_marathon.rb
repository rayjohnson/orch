require 'helper'

class TestMarathon < OrchTest

  def setup
    @cls = Orch::Marathon
    @url = 'http:://example.com'
    @app = 'foo'
  end

  def setup_mock_delete ret
    @cls
      .any_instance
      .expects(:http_delete)
      .with(@url, "/v2/apps/#{@app}", @cls::JSON_HEADERS)
      .returns(ret)
  end

  def setup_mock_restart ret
    @cls
      .any_instance
      .expects(:http_post)
      .with(@url, "/v2/apps/#{@app}/restart", '{}', @cls::JSON_HEADERS)
      .returns(ret)
  end

  def setup_mock_put ret
    @cls
      .any_instance
      .expects(:http_put)
      .with(@url, "/v2/apps/#{@app}", '', @cls::JSON_HEADERS)
      .returns(ret)
  end

  def test_http_methods_mixed
    assert_http_methods_mixed @cls
  end

  def test_constants
    assert_mixed_constants @cls
  end

  def test_deploy_raises_marathon_error
    assert_raises Orch::MarathonError do
      @cls.new.deploy nil, nil, nil
    end
  end

  def test_deploy_200
    mock_success = mock 'success' do
      expects(:code).returns('200')
    end

    setup_mock_put mock_success

    @cls.new.deploy @url, @app, ''
  end

  def test_deploy_201
    mock_success = mock 'success' do
      expects(:code).returns('201')
    end

    setup_mock_put mock_success

    @cls.new.deploy @url, @app, ''
  end

  def test_deploy_401
    mock_failure = mock 'unauthorized' do
      expects(:code).returns('401')
      expects(:body)
    end

    setup_mock_put mock_failure

    assert_raises Orch::AuthenticationError do
      @cls.new.deploy @url, @app, ''
    end
  end

  def test_deploy_unknown_response
    mock_failure = mock 'teapot' do
      expects(:code).returns('418')
      expects(:body).returns('chickens')
      expects(:message).returns('coooooooowwwwssss')
    end

    setup_mock_put mock_failure

    @cls.new.deploy @url, @app, ''
  end

  def test_delete_raises_marathon_error
    assert_raises Orch::MarathonError do
      @cls.new.delete nil, nil
    end
  end

  def test_delete_200
    mock_success = mock 'success' do
      expects(:code).returns('200')
    end

    setup_mock_delete mock_success

    @cls.new.delete @url, @app
  end

  def test_delete_404
    mock_failure = mock 'notfound' do
      expects(:code).returns('404')
    end

    setup_mock_delete mock_failure

    @cls.new.delete @url, @app
  end

  def test_delete_unknown_response
    mock_failure = mock 'teapot' do
      expects(:code).returns('418')
      expects(:body).returns('lemon')
      expects(:message).returns('limes')
    end

    setup_mock_delete mock_failure

    @cls.new.delete @url, @app
  end

  def test_restart_raises_marathon_error
    assert_raises Orch::MarathonError do
      @cls.new.restart nil, nil
    end
  end

  def test_restart_200
    mock_success = mock 'success' do
      expects(:code).returns('200')
    end

    setup_mock_restart mock_success

    @cls.new.restart @url, @app
  end

  def test_restart_unknown_response
    mock_failure = mock 'teapot' do
      expects(:code).returns('418')
      expects(:body).returns('lemon')
      expects(:message).returns('limes')
    end

    setup_mock_restart mock_failure

    @cls.new.restart @url, @app
  end

end
