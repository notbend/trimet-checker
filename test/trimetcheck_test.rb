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
    @tc0 = TrimetTrack.new("arrivals", "1, 234", @app_id)
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
    msg = "Are urls well formed?"
    assert_equal("http://developer.trimet.org/ws/V1/arrivals?locIDs=1,234&appID=#{@app_id}", @tc0.buildRequest, msg + ' arrivals')
    _tc0 = TrimetTrack.new("routeconfig", "75", @app_id)
    assert_equal("http://developer.trimet.org/ws/V1/routeConfig?route=75&dir=0&tp=true&appID=#{@app_id}", _tc0.buildRequest, msg + ' routeConfig')
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

  #line (route) 75 examples 
  #dir=1
  #"NE 41st & Klickitat" locid="7500" seq="3750" tp="false" lat="45.547046999998" lng="-122.62087299998"/> dir=1
  #"SE Cesar Chavez Blvd & Stephens" locid="7490" seq="4750" tp="false" lat="45.5095671899025" lng="-122.622850361189"/> dir=1
  #
  #dir=0
  #"N Lombard & Oatman" locid="3528" seq="5700" tp="false" lat="45.577199999998" lng="-122.70042099998"/>
  #"N Lombard & Wabash" locid="3566" seq="5750" tp="false" lat="45.577211999998" lng="-122.703125"/>
  #"N Lombard & Washburne" locid="3572" seq="5800" tp="false" lat="45.577216999998" lng="-122.70529299998"/>
  #"N Lombard & Chautauqua" locid="3478" seq="5850" tp="false" lat="45.577214" lng="-122.707801"/>
  #"N Lombard & Russet" locid="3548" seq="5900" tp="false" lat="45.5780735501307" lng="-122.71182645126"/>
  #"N Lombard & Dwight" locid="3487" seq="5950" tp="false" lat="45.578962999998" lng="-122.71424799998"/>
  #
  #line (route) 8, an example with dir 0 and 1 overlaps
  #locids that don't overlap*
  #dir = 0
  #*"SW 5th & Hall" locid="10491" seq="2150" tp="false" lat="45.5102484374056" lng="-122.682309139087"/>
  #*"SW 5th & Broadway" locid="7588" seq="2200" tp="false" lat="45.5070794175557" lng="-122.683850353684"/>
  #*"SW 6th & Sheridan" locid="7794" seq="2250" tp="false" lat="45.5053589218292" lng="-122.684451816893"/>
  #*"SW Terwilliger & Sam Jackson" locid="5804" seq="2300" tp="false" lat="45.502537999998" lng="-122.68751599998"/>
  #*"SW Terwilliger & Campus" locid="11010" seq="2350" tp="false" lat="45.4992493262091" lng="-122.682732956279"/>
  #"SW US Veterans Rd & Bldg #16" locid="8455" seq="2400" tp="false" lat="45.4964183647869" lng="-122.682219978021"/>
  # ... 9 overlapping stops ...
  #"700 SW Campus Dr at Doernbecher" locid="10176" seq="2900" tp="false" lat="45.4978730883951" lng="-122.685901020567"/>
  #"SW Campus Dr & Main Dental School" locid="868" seq="2950" tp="false" lat="45.498186999998" lng="-122.68430299998"/>
  #"SW Campus Dr & Terwilliger" locid="870" seq="3000" tp="true" lat="45.49910455037" lng="-122.682572023037"/>
  #
  #dir = 1
  #"SW US Veterans Rd & Bldg #16" locid="8455" seq="50" tp="true" lat="45.4964183647869" lng="-122.682219978021"/>
  #"US Veterans Hospital" locid="5975" seq="100" tp="true" lat="45.4970583336085" lng="-122.683270682382"/>
  # ... 9 overlapping stops...
  #"SW Campus Dr & Main Dental School" locid="868" seq="600" tp="false" lat="45.498186999998" lng="-122.68430299998"/>
  #"SW Campus Dr & Terwilliger" locid="870" seq="650" tp="false" lat="45.49910455037" lng="-122.682572023037"/>
  #*"SW Terwilliger & Sam Jackson" locid="9861" seq="700" tp="false" lat="45.502742999998" lng="-122.68742299998"/>
  #*"SW 6th & Sheridan" locid="7793" seq="750" tp="false" lat="45.5054336359249" lng="-122.684177436404"/>
  #
  #if we want a sequence of routes from SW 5th & Hall to SW Terwilliger & sam jackson we will cross from dir 0 to 1
  #note: clearly this isn't a trip someone would make. the query would be for examining the OHSU bus loop
  def test_get_route_sequence
    msg = "Can we get a sequence of location IDs between two stops?"
    _tc0 = TrimetTrack.new("routeconfig", "75") #, @app_id)
   #assert_equal("hi!",  _tc0.getRouteSequence('8',10,'10491','8455'), msg + " with a default for x2")
   #assert_equal("hi!",  _tc0.getRouteSequence('8',10,'10491','11010'), msg + " with a default for x2")
   #assert_equal("hi!",  _tc0.getRouteSequence('8',10,'11010','7793'), msg + " with a default for x2")
  end
end
