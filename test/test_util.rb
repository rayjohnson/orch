require 'helper'

class TestUtil < OrchTest

  def setup
    @methods = [
      :http_post,
      :http_put,
      :http_get,
      :http_delete,
    ]
  end

  def test_not_mixed
    @methods.each do |method|
      assert_raises NameError do
        self.send method
      end
    end
  end

  def test_mixed
    class << self
      include Orch::Util
    end

    @methods.each do |method|
      assert_raises ArgumentError do
        self.send method
      end
    end
  end

end
