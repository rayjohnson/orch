require './lib/orch'

require 'minitest/autorun'

class OrchTest < Minitest::Test

  def assert_http_methods_mixed cls
    assert cls.new.methods.include?(:http_post),
      "expected :http_post to be mixed in"
    assert cls.new.methods.include?(:http_put),
      "expected :http_put to be mixed in"
    assert cls.new.methods.include?(:http_get),
      "expected :http_get to be mixed in"
    assert cls.new.methods.include?(:http_delete),
      "expected :http_delete to be mixed in"
  end

  def assert_mixed_constants cls
    assert @cls.constants.include?(:JSON_HEADERS), @cls.constants
  end

end

