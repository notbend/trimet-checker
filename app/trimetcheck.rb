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
#require 'pp'

$APPID= ''
$BASEURL= ''
$CONFIG = '../config'
class TrimetTrack 
  attr_accessor :query_time_ms, :result, :display
  attr_writer :xml_data #for testing
  attr_reader :mode, :ids

  def initialize(mode, ids, my_app_id = '')
    @query_time_ms = nil
    if my_app_id != '' 
      $APPID = my_app_id
    end
    readConfig
    #mode used in query string
    if ['arrivals','detours','routeconfig','stoplocation','tripplanner'].include? mode 
      @mode = mode
    else
      @mode = 'arrivals'
    end
    @ids = ids.delete(' ').split(',')
    @result = Hash.new(@ids.length)
    @display = ''
    @ids.each do |key|
      @result[key] = nil
    end
  end

  def buildRequest #base url + mode + ids + appID 
    @url = $BASEURL + @mode + '?locIDs=' + @ids.join(',') + '&appID=' + $APPID
  end

  def xml_data #HTTP Request, just the raw xml
    #try or failquery_time_ms
    if @xml_data =='' || @xml_data == nil
      self.buildRequest
      @xml_data = Net::HTTP.get_response(URI.parse(@url)).body 
    else
      return @xml_data 
    end
  end

  def status_report(status, stamp) # ...arriving in 3 minutes, ...scheduled at Tuesday, 4:45am
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
      return ("#{status}  arrival in  #{arrival}")
    end
  end

  def parseXML #create a human readable text block
    self.xml_data
    data = XmlSimple.xml_in(@xml_data, { 'KeyAttr' => 'block' })
    @query_time_ms= data['queryTime'].to_i
    data['location'].each do |loc|
      if @result.include? loc['locid']
        @result[loc['locid']] = loc
        @result[loc['locid']]['routes'] = Hash.new
      end
    end
    #trimet xml data for stop information and arrivals to the stop are not nested xml.
    #arrivals are set in a second loop to ensure they correspond to an already set stop location 
    data['arrival'].each do |k,v|
      if @result.include? v['locid'] 
        route = @result[v['locid']]['routes']
        if route.include? v['route']
           route[v['route']][0] += "\t#{self.status_report(v['status'], v['scheduled'])}\n" 
        else
          route[v['route']] = Array.new 
          route[v['route']].push(v['fullSign'] + "\n" )
          route[v['route']][0] +=  "\t#{self.status_report(v['status'], v['scheduled'])}\n" 
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

#track = TrimetTrack.new("arrivals", "6805, 7646, 7634")
#track = TrimetTrack.new("arrivals", "7646, 7634")
#url = track.buildRequest
#puts track.niceDisplay
#track.parseXML
#puts track.display
#puts url
#track.readConfig
