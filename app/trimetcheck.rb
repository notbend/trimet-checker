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
    when 'getRouteSequence','routeconfig', 'routeConfig' #,'detours','routeconfig','stoplocation','tripplanner'
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
    @mode  = 'routeConfig'  
    _xml   = Array.new(2)
    _data  = Array.new(2)
    _routes= Array.new(2)
    initialize(@mode, route)
    for i in 0..1
      @url_opts['dir'] = i.to_s
      self.buildRequest
      _xml[i] = Net::HTTP.get_response(URI.parse(@url)).body 
      _data[i] = XmlSimple.xml_in(_xml[i], { 'KeyAttr' => 'seq', 'KeepRoot' => false})
      _routes[i] = Array.new()
      _cur_seq = 0
      _data[i]['route'].first['dir'].first['stop'].each do |v|
        if v[0].to_i >= _cur_seq
          _cur_seq = v[0].to_i
          _routes[i] << v
        else
          _routes[i] << 'out of sequence?' #US
        end 
      end
    end
    #pp _data[1]
    #_data[i].each do |k,v|
    #   puts "#{k} => #{v.to_s}"
    #end
    #return _data
    return _routes
  end

  def getRouteSequence(route, max_ids, x1, x2= nil)
    #get two location ids (x1, x2). if x2 is nil assume it is the last one on the route
    #return an array of all location ids between those two points. 
    #if location ids > max_ids, don't return more than max_ids 
    #for example, if there are 20 ids from 1 to 20 and max_ids is 3, it should return 1,10, and 20
    #
    #it's possible, as with line 8, 2 points could fall between the end of an inbound route and the
    #begining of an outbound route (or vice versa). for now, only the simple case of 2 points within
    #either out or inbound are accounted for 
    _route_seq = Array.new()  #return x1 ... x2, with max_ids - 2 ids between
    _indicies = {:s_dir => 0, #either 0 or 1, indicates if the Starting location is within the dir 0 or 1 route
                 :e_dir => 0, #like s_dir, for the Ending location 
                 :s_ind => 0, #0..n, the index that contains the Starting location
                 :e_ind => 0} #like e_i
    #possible _indicies:
    # :s_dir = 0, :e_dir = 0, :s_1 = 7, :e_i = 9  (simple case 1)
    #    start and end locations are both within the dir 0 route. there are 3 stops in the series
    # :s_dir = 1, :e_dir = 1, :s_1 = 0, :e_i = 10 (simple case 2) 
    #    start and end locations are both within the dir 1 route. there are 11 stops in the series
    # :s_dir = 0, :e_dir = 1, :s_1 = 55, :e_i = 5 (must filter out duplicate locations?) see: route 8 to OHSU
    #    start is in the dir 0 route while the end is in the dir 1 route
    #    since there may be 0 or more stops on dir 1 after 55, there will be at least 7 stops in the series
    r1, r2 = nil
    route_dirs = routeConfig(route)
    route_dirs.each_with_index do |rt, dir| #US: no check for a valid route
      if x2 == nil #if x2 is nil, we can assume the entire series will NOT overlap dir 0 and 1 
        r2 = rt[-1][1]['locid'] #location id from the last stop on the route 
        _indicies[:e_dir] = dir
        _indicies[:e_in]  = -1
      end
      rt.each_with_index do |v, ind| #US: assuming that all routes have a corresponding inbound/outbound version
        vid = v[1]['locid']
        if vid == x1
          r1 = x1
          _indicies[:s_dir] = dir
          _indicies[:s_ind] = ind
        elsif (vid == x2 or vid == r2) and r1 != nil
          r2 = vid 
          _indicies[:e_dir] = dir
          _indicies[:e_ind] = ind
        end
        break if r1 != nil and r2 != nil
      end
      break if r1 != nil and r2 != nil
    end
    if _indicies[:s_dir] == _indicies[:e_dir]#simple cases 1 and 2
      _route_seq = route_dirs[_indicies[:s_dir]][_indicies[:s_ind].._indicies[:e_ind]]
    else #US assuming x1 is in dir 0 and x2 is in dir 1 
      _route_seq = route_dirs[_indicies[:s_dir]].drop(_indicies[:s_ind])
      _route_seq + route_dirs[_indicies[:e_dir]].take(_indicies[:e_ind])
    end 
    #if _route_seq.length > max_ids
    #  _step = (_route_seq.length / max_ids).floor
    #end
    return _route_seq.map {|v| v[1]['locid']} #make array of just locids
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
    File.readlines(File.expand_path("../../config", __FILE__)).each do |line| 
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
#puts track.niceDisplay
