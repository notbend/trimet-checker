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

require 'net/http'
require 'rubygems'
require 'xmlsimple'

$APPID= 'B0E5ECC078C9608F6781AE3E1'
$BASEURL= 'http://developer.trimet.org/ws/V1/'

class TrimetCheck 

  def initialize(mode ='arrivals', ids)
      @mode = mode
      @ids = ids
  end
  def readConfig #text file options for developer key, base url
    # get vars from a config file if one exists
    #:app_id ='B0E5ECC078C9608F6781AE3E1'
    #:base_url = 'http://developer.trimet.org/ws/V1/'
  end
  def buildRequest #base url + mode + ids + appID 
    # format = http://developer.trimet.org/ws/V1/arrivals?locIDs=6849,6850&appID=0000000000000000000000000"
    #
    #arrivals?
    ids = ['123','555','99']
    @url = $BASEURL + @mode + '?locIDs=' + ids.join(',') + '&appID=' + $APPID
    puts @url
    #url ='http://developer.trimet.org/ws/V1/arrivals?locIDs=6849,6850&appID=B0E5ECC078C9608F6781AE3E1'
  end
  def makeRequest #make http request to trimet
    xml_data = Net::HTTP.get_response(URI.parse(@url)).body 
    puts xml_data
  end
  def parseXML #xml to variables 

  end
  
end

check = TrimetCheck.new("arrivals", "123")
check.buildRequest
check.makeRequest
