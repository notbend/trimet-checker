#test/trimetcheck_test.rb
require File.join(File.dirname(__FILE__),'..','app','trimetcheck.rb')
require 'test/unit'

class TrimetCheckTest < Test::Unit::TestCase
  def setup 
    @min = 60000
    @hour = @min * 60
    @day = @hour * 24
    @base_stamp = 1365651602456 #Wednesday, 08:40 pm
    @app_id = "fake_id_not_from_the_config"
    #tc0: are config values read? can they be overridden?
    #tc1: are the ids being properly read and array'd?
    @tc0 = TrimetTrack.new("arrivals", "1, 123")
    @tc1 = TrimetTrack.new("arrivals", "1, 234,  5",@app_id)
    
    #tc2: are xml files being correctly parsed?
    #xml dummy files are used in place of live data.
    @tc2 = TrimetTrack.new("arrivals", "7646, 7634")
    file = File.open("xml/7646_7634_840_wed_arrivals.xml", "rb")
    @tc2.xml_data = file.read
    file.close
    @tc2.parseXML

    #tc3: are timestamp values being correctly translated?
    #
    #tc4: are time diffs correct?
      #@tdata = Array.new
      ############# queryTime,      stopIDs,     routes,     arrivals, file
      #@tdata[0] = ['1365651602456','7646,7634','190,200,4,33']

  end
  def test_initialize #(mode, ids, my_app_id = '') 
    msg = "Can we load an TrimetCheck object?"
    assert_equal('arrivals', @tc0.mode, msg)
    assert_equal('1', @tc0.ids[0], msg)
    assert_equal('123', @tc0.ids[1],msg)
    assert_equal(2, @tc0.ids.length,msg)


    #msg = "Can we run without a stop id?"
    #_t0 = TrimetTrack.new("arrivals",'1')
    #assert_equal(1, _t0.ids.length, msg)

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
    msg = "Are urls well formed?"
    assert_equal(3, @tc1.ids.length, msg)
    assert_equal("http://developer.trimet.org/ws/V1/arrivals?locIDs=1,234,5&appID=#{@app_id}", @tc1.buildRequest)

    #TODO: request url with default values
  end

  def test_xml_parse
    #can external xml be loaded?
    xml = "<x>testing</x>"
    t1 = TrimetTrack.new("arrivals", "7646, 7634", @app_id)
    t1.xml_data= xml
    #t1.parseXML #this should not overwrite the value 
    assert_equal(xml, t1.xml_data)
  end

  def test_epoch_to_date
    msg ="is the epoch date a number and does it agree with the xml?"
    assert_equal(1365651602456, @tc2.query_time_ms, msg)
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

    assert_equal("scheduled  at  Wednesday, 08:40 pm", @tc2.statusReport("scheduled", @base_stamp.to_s), "a msg")
    assert_equal("scheduled  at  Wednesday, 08:41 pm", @tc2.statusReport("scheduled",(@base_stamp + @min).to_s), "a msg")
    assert_equal("scheduled  at  Wednesday, 09:40 pm", @tc2.statusReport("scheduled",(@base_stamp + @hour).to_s), "a msg")
    assert_equal("scheduled  at  Wednesday, 10:10 pm", @tc2.statusReport("scheduled",(@base_stamp + @hour + (30 * @min)).to_s), "a msg")
    assert_equal("scheduled  at  Thursday, 01:40 am",  @tc2.statusReport("scheduled",(@base_stamp + (5 * @hour)).to_s), "a msg")
  end
  def test_status_report_estimated
    #reasonable cases from 0 - 90 minutes
    assert_equal("estimated arrival in 0 minutes",  @tc2.statusReport("estimated", @base_stamp.to_s), "a msg")
    assert_equal("estimated arrival in 1 minute",   @tc2.statusReport("estimated",(@base_stamp - @min).to_s), "a msg")
    assert_equal("estimated arrival in 10 minutes", @tc2.statusReport("estimated",(@base_stamp - (@min * 10)).to_s), "a msg")
  end
end
