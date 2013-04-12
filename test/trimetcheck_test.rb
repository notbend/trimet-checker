#test/trimetcheck_test.rb
require File.join(File.dirname(__FILE__),'..','app','trimetcheck.rb')
require 'test/unit'

class TrimetCheckTest < Test::Unit::TestCase
  def xml_test_data
    @tdata = Array.new
    ############ queryTime,      stopIDs,     routes,     arrivals, file
    @tdata[0] = ['1365651602456','7646,7634','190,200,4,33']
    file = File.open("xml/7646_7634_840_wed_arrivals.xml", "rb")
    @xml_test_data= file.read
    file.close
    return @xml_test_data
  end
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
    t1.xml_data= xml
    #t1.parseXML #this should not overwrite the value 
    assert_equal(xml, t1.xml_data)
  end

  def test_epoch_to_date
    t1 = TrimetTrack.new("arrivals", "7646, 7634")
    t1.xml_data=(self.xml_test_data)
    t1.parseXML
    ##assert_not_equal(nil, t1.query_time_ms, "Expecting 1")
    assert_equal(1365651602456, t1.query_time_ms, "Expecting 1")
  end

  def test_status_report_scheduled
    # Trimet time values are in milliseconds since epoch
    # 13 digit value => 1000 * 60 * 60 * 24 * 365 * 43ish
    # 1365651602456
    # ---------1000 1 second
    # --------60000 1 minute
    # ------3600000 1 hour
    # -----86400000 1 day
    # --31536000000 1 year
    t1 = TrimetTrack.new("arrivals", "7646, 7634")
    t1.xml_data = self.xml_test_data
    t1.parseXML
    min = 60000
    hour = min * 60
    day = hour * 24
    base_stamp = 1365651602456 #Wednesday, 08:40 pm
    assert_equal("scheduled  at  Wednesday, 08:40 pm", t1.statusReport("scheduled", base_stamp.to_s), "a msg")
    assert_equal("scheduled  at  Wednesday, 08:41 pm", t1.statusReport("scheduled",(base_stamp + min).to_s), "a msg")
    assert_equal("scheduled  at  Wednesday, 09:40 pm", t1.statusReport("scheduled",(base_stamp + hour).to_s), "a msg")
    assert_equal("scheduled  at  Wednesday, 10:10 pm", t1.statusReport("scheduled",(base_stamp + hour + (30 * min)).to_s), "a msg")
    assert_equal("scheduled  at  Thursday, 01:40 am",  t1.statusReport("scheduled",(base_stamp + (5 * hour)).to_s), "a msg")
  end

  def test_status_report_scheduled
    t1 = TrimetTrack.new("arrivals", "7646, 7634")
    t1.xml_data = self.xml_test_data
    t1.parseXML
    min = 60000
    hour = min * 60
    day = hour * 24
    base_stamp = 1365651602456 #Wednesday, 08:40 pm
    #reasonable cases from 0 - 90 minutes
    assert_equal("estimated arrival in 0 minutes",  t1.statusReport("estimated",base_stamp.to_s), "a msg")
    assert_equal("estimated arrival in 1 minute",  t1.statusReport("estimated",(base_stamp - min).to_s), "a msg")
    assert_equal("estimated arrival in 10 minutes",  t1.statusReport("estimated",(base_stamp - (min * 10)).to_s), "a msg")
  end
end
