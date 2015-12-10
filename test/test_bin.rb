require 'helper'

# TODO figure out how to capture std* and regex on it maybe.
class BinTest < OrchTest

  def setup
    @app = Orch::Application.expects(:start)
  end

  def test_success
    @app.returns true
    load_bin
  end

  def test_user_error
    @app.raises Orch::UserError
    load_bin
  end

  def test_unknown_error
    @app.raises StandardError
    assert_raises StandardError do
      load_bin
    end
  end

  private

  def load_bin
    eval File.read './bin/orch'
  end

end

