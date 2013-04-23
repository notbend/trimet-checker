# Trimet API interface in ruby
# tool to check when the bus is coming
# + user inputs mode, stop ids, 
#   - commandline flags?
#   - local config file 
#   - validate ids locally before (local cache of recently search ids)
# + build html request string, submit 
# + get xml and parse
# + format 
#   -command line 
require 'date'
require 'net/http'
#require 'rubygems'
require 'xmlsimple'
require 'pp'

$APPID= ''
$BASEURL= ''
$CONFIG = '../config'
class TrimetTrack 
  attr_accessor :query_time_ms, :result, :display
  #attr_writer :xml_data #for testing
  attr_reader :mode, :ids

  def initialize(mode, ids, my_app_id = '')
    @xml_data = nil
    @query_time_ms = nil
    if my_app_id != '' 
      $APPID = my_app_id
    end
    readConfig
    #mode used in query string
    @ids = ids.delete(' ').split(',')
    @url_opts = Hash.new()
    @mode = mode
    case mode 
    when 'arrivals' 
      @url_opts = { 'locIDs' => @ids}
    when 'routeconfig', 'routeConfig' #,'detours','routeconfig','stoplocation','tripplanner'
      @mode = 'routeConfig'
      @url_opts = { 'route' => @ids,
                    'dir'   => '0',
                    'tp'    => 'true'
                  }
    else
      @url_opts = { 'invalid' => 'option' }
    end
    @result = Hash.new(@ids.length)
    @display = ''
    @ids.each do |key|
      @result[key] = nil
    end
  end
  
  def routeConfig(route) #eg: line 8 to OHSU. 
    @mode = 'routeConfig'  
    _xml  = Array.new(2)
    _data = Array.new(2)
    initialize(@mode, route)
    for i in 0..1
      @url_opts['dir'] = i.to_s
      self.buildRequest
      _xml[i] = Net::HTTP.get_response(URI.parse(@url)).body 
      _data[i] = XmlSimple.xml_in(_xml[i], { 'KeyAttr' => 'seq', 'KeepRoot' => false})
      _data[i] = _data[i]['route'].first['dir'].first['stop']
    end
    #pp _data[1]
    #_data[i].each do |k,v|
    #   puts "#{k} => #{v.to_s}"
    #end
    return _data
  end

  def getRouteSequence(max_ids, l1, l2= nil)
    #get two location ids (l1, l2). if l2 is nil assume it is the last one on the route
    #return an array of all location ids between those two points. 
    #if location ids > max_ids, don't return more than max_ids 
    #for example, if there are 20 ids from 1 to 20 and max_ids is 3, it should return 1,10, and 20
    #
    #it's possible, as with line 8, 2 points could fall between the end of an inbound route and the
    #begining of an outbound route (or vice versa). for now, only the simple case of 2 points within
    #either out or inbound are accounted for 
  end
  def buildRequest #base url + mode + ids + appID 
    #http://developer.trimet.org/ws/V1/routeConfig?route=75&dir=1&tp=true&appID=B0E5ECC078C9608F6781AE3E1
    _sub_url = '?'
    @url_opts.each do |k, v|
      _sub_url << k << '='
      if v.kind_of?(Array)
        _sub_url << v.join(',')
      else 
        _sub_url << v 
      end
      _sub_url << '&'
    end  
    @url = $BASEURL + @mode + _sub_url + 'appID=' + $APPID
  end

  def xml_data=(xml)
    @xml_data = xml
  end

  def xml_data #HTTP Request, just the raw xml
    #try or failquery_time_ms
    if @xml_data =='' || @xml_data == nil
      self.buildRequest
      @xml_data = Net::HTTP.get_response(URI.parse(@url)).body 
      return @xml_data
    else
      return @xml_data 
    end
  end

  def statusReport(status, stamp) # ...arriving in 3 minutes, ...scheduled at Tuesday, 4:45am
    if status == 'scheduled'
      _d = DateTime.strptime(stamp,'%Q') #%Q = milliseconds since unix epoch
      _d = _d.to_time #localize before strftime. consider forcing this to PST
      return ("#{status}  at  #{_d.strftime '%A, %I:%M %P'}")
    else
      arrival = ((@query_time_ms - stamp.to_i) / 1000 / 60).abs
      if arrival != 1 #plural minutes, 0 minutes, 2 minutes ...
        arrival = arrival.to_s << " minutes"
      else # expecting "1 minute"
        arrival = arrival.to_s << " minute"
      end
      return ("#{status} arrival in #{arrival}")
    end
  end

  def parseXML #create a human readable text block
    @xml_data = self.xml_data
    data = XmlSimple.xml_in(@xml_data, { 'ForceArray' => true })
    @query_time_ms= data['queryTime'].to_i
    data['location'].each do |loc|
      if @result.include? loc['locid']
        @result[loc['locid']] = loc
        @result[loc['locid']]['routes'] = Hash.new
      end
    end
    #trimet xml data for stop information and arrivals to the stop are not nested xml.
    #arrivals are set in a second loop to ensure they correspond to an already set stop location 
    data['arrival'].each do |v|
      if @result.include? v['locid'] 
        route = @result[v['locid']]['routes']
        if route.include? v['route']
           route[v['route']][0] += "\t#{self.statusReport(v['status'], v['scheduled'])}\n" 
        else
          route[v['route']] = Array.new 
          route[v['route']].push(v['fullSign'] + "\n" )
          route[v['route']][0] +=  "\t#{self.statusReport(v['status'], v['scheduled'])}\n" 
          route[v['route']].push(v)
        end
      else
        #error?
      end #elsif orphaned arrival
    end
  end

  def niceDisplay #human readable
    if @query_time_ms == nil#lazy way to ensure parseXML has happened
      self.parseXML
    end
    if @display ==''
      @result.each do |k,v|
        @display << "Stop ID #{k}: #{v['desc']} \n"
        #@display << "#{v['routes']}"
        if (v['routes'])
          v['routes'].each do |id,info|
            @display << "#{info[0]} \n"
          end
        end
      end
    end
    return @display
  end 

  private

  def readConfig #text file options for developer key, base url
    # get vars from a config file if one exists
    line_num = 1 # 1 is appid, 2 is baseurl
    File.readlines('../config').each do |line| 
      line = line.gsub("\n",'')
      if line_num == 1 && $APPID ==''
        $APPID = line
      elsif line_num == 2 && $BASEURL == ''
        $BASEURL = line
      end
      line_num +=1
    end
  end
  
end

#sample usage
#track = TrimetTrack.new("arrivals", "6805, 7646, 7634") #stops from different routes
#track = TrimetTrack.new("arrivals", "6786, 6784, 6802") #consecutive stops on the same route 
#puts track.buildRequest
#puts track.niceDisplay
