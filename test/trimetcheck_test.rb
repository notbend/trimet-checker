#test/trimetcheck_test.rb
require File.join(File.dirname(__FILE__),'..','app','trimetcheck.rb')
require 'test/unit'

MIN = 60000
HOUR = MIN * 60
DAY = HOUR * 24
class TrimetCheckTest < Test::Unit::TestCase
  def setup 
    @base_stamp = 1365651602456 #Wednesday, 08:40 pm
    @app_id = "fake_id_not_from_the_config"
    @tc0 = TrimetTrack.new("arrivals", "1, 234")
    @tc_xml_1 = TrimetTrack.new("arrivals", "7646, 7634")
    file = File.open("xml/7646_7634_840_wed_arrivals.xml", "rb")
    @tc_xml_1.xml_data = file.read
    file.close
    @tc_xml_1.parseXML
  end

  def test_initialize #(mode, ids, my_app_id = '') 
    msg = "Can we load an TrimetCheck object?"
    assert_equal('arrivals', @tc0.mode, msg)
    assert_equal('1', @tc0.ids[0], msg)
    assert_equal('234', @tc0.ids[1],msg)
    assert_equal(2, @tc0.ids.length,msg)

    msg = "Can we read just one id?"
    _t1 = TrimetTrack.new("arrivals", "1")
    assert_equal(1, _t1.ids.length, msg)

    msg = "Can we read 4 ids in with no spaces between?"
    _t2 = TrimetTrack.new("arrivals", "1,2,3,4")
    assert_equal(4, _t2.ids.length, msg)

    msg = "Can we read 4 ids in with no spaces between?"
    _t3 = TrimetTrack.new("arrivals", "1,2,3,4")
    assert_equal(4, _t3.ids.length, msg)

    msg = "Can we read 3 ids in with 1 or more spaces between?"
    _t4 = TrimetTrack.new("arrivals", "1,  2  ,  3")
    assert_equal(3, _t4.ids.length, msg)
    #supplied app_id should override the config file
    #TODO: read config values for testing to make sure they're read correctly
    msg = "Can we override the default appID from the config file?"
    _t5 = TrimetTrack.new("arrivals", "1", @app_id)
    assert_equal("http://developer.trimet.org/ws/V1/arrivals?locIDs=1&appID=#{@app_id}", _t5.buildRequest, msg)
  end

  def test_build_request
    #msg = "Are urls well formed?"
    #assert_equal("http://developer.trimet.org/ws/V1/arrivals?locIDs=1,234&appID=#{@app_id}", @tc0.buildRequest, msg)
  end

  def test_xml_parse
    #can external xml be loaded?
    xml = "<x>testing</x>"
    @tc0.xml_data= xml
    assert_equal(xml, @tc0.xml_data)
  end

  def test_epoch_to_date
    msg ="is the epoch date a number and does it agree with the xml?"
    assert_equal(1365651602456, @tc_xml_1.query_time_ms, msg)
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
    
    msg = "Are scheduled dates correct?"
    assert_equal("scheduled  at  Wednesday, 08:40 pm", @tc0.statusReport("scheduled", @base_stamp.to_s), msg)
    assert_equal("scheduled  at  Wednesday, 08:41 pm", @tc0.statusReport("scheduled",(@base_stamp + MIN).to_s), msg)
    assert_equal("scheduled  at  Wednesday, 09:40 pm", @tc0.statusReport("scheduled",(@base_stamp + HOUR).to_s), msg)
    assert_equal("scheduled  at  Wednesday, 10:10 pm", @tc0.statusReport("scheduled",(@base_stamp + HOUR + (30 * MIN)).to_s), msg)
    assert_equal("scheduled  at  Thursday, 01:40 am",  @tc0.statusReport("scheduled",(@base_stamp + (5 * HOUR)).to_s), msg)
  end

  def test_status_report_estimated
    #reasonable cases from 0 - 90 minutes, needs xml for the stamp data
    #DST Notes: 
    #  began at 2:00 AM, 2013 March 10 (Sunday)
    #  ends at 2:00 AM, 2013 November 3 (Sunday)
    #TOD0: DST related tests?
    msg = "Are estimated time differences correct?"
    assert_equal("estimated arrival in 0 minutes",  @tc_xml_1.statusReport("estimated", @base_stamp.to_s), msg)
    assert_equal("estimated arrival in 1 minute",   @tc_xml_1.statusReport("estimated",(@base_stamp - MIN).to_s), msg)
    assert_equal("estimated arrival in 10 minutes", @tc_xml_1.statusReport("estimated",(@base_stamp - (MIN * 10)).to_s), msg)
  end
end
