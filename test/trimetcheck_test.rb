#test/trimetcheck_test.rb
require File.join(File.dirname(__FILE__),'..','app','trimetcheck.rb')
require 'test/unit'

class TrimetCheckTest < Test::Unit::TestCase
  def test_initialize #(mode, ids, my_app_id = '') 
    t1 = TrimetTrack.new("arrivals", "7646, 7634")
    assert_equal('arrivals', t1.mode)
    assert_equal('xrrivals', t1.mode)
#track = TrimetTrack.new("arrivals", "7646, 7634")

  end
end
