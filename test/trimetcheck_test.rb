#test/trimetcheck_test.rb
require File.join(File.dirname(__FILE__),'..','app','trimetcheck.rb')
require 'test/unit'

class TrimetCheckTest < Test::Unit::TestCase
  def test_initialize #(mode, ids, my_app_id = '') 
    t1 = TrimetTrack.new("arrivals", "7646, 7634")
    assert_equal('arrivals', t1.mode)
    assert_equal('7646', t1.ids[0])
    assert_equal('7634', t1.ids[1])
    assert_equal(2, t1.ids.length)

    t2 = TrimetTrack.new("arrivals", "7646 ")
    assert_equal(1, t2.ids.length)

    #http://developer.trimet.org/ws/V1/arrivals?locIDs=6849,6850&appID=B0E5ECC078C9608F6781AE3E1
    t3 = TrimetTrack.new("arrivals", "1,  2,3,  4")
    assert_equal(4, t3.ids.length)

    #supplied app_id should override the config file
    #TODO: read config values for testing to make sure they're read correctly
    app_id = "a_custom_app_id_not_the_config_value"
    t4 = TrimetTrack.new("arrivals", "1", app_id)
    assert_equal("http://developer.trimet.org/ws/V1/arrivals?locIDs=1&appID=#{app_id}", t4.buildRequest)
#track = TrimetTrack.new("arrivals", "7646, 7634")
  end

  def test_build_request
    app_id = "fake-id"
    t1 = TrimetTrack.new("arrivals", "123, 456, 789,1,3,4", app_id)
    assert_equal(6, t1.ids.length)
    assert_equal("http://developer.trimet.org/ws/V1/arrivals?locIDs=123,456,789,1,3,4&appID=#{app_id}", t1.buildRequest)

    #TODO: request url with default values
    
  end

  def test_xml_parse
    app_id = "I_bet_any_old_string_will_do" 
   

    #can external xml be loaded?
    xml = "<x>testing</x>"
    t1 = TrimetTrack.new("arrivals", "7646, 7634", app_id)
    t1.xml_data = xml
    t1.xml_data
    #t1.parseXML #this should not overwrite the value 
    assert_equal(xml, t1.xml_data)
  end

  def test_epoch_to_date

  end
end
