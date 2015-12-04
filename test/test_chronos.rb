require 'helper'

class TestChronos < OrchTest

  def setup
    @cls = Orch::Chronos
  end

  def test_http_methods_mixed
    assert_http_methods_mixed @cls
  end

  def test_constants
    assert_mixed_constants @cls
  end

end
