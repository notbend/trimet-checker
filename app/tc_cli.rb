require 'optparse'
require_relative 'trimetcheck.rb'


options = {}

opt_parser = OptionParser.new do |opt|
  opt.banner = "Usage: ttt [-[OPTIONS]"
  opt.separator  ""

  opt.on("-s","--start LOCATION_ID(s)","bus or max stop id(s). if more than one, seperate by comma, eg: '1,2,3'") do |id|
    options[:sids] = id 
  end

  opt.on("-e","--end LOCATION_ID","bus or max stop id. -l required. If given, many stops along the route will be given") do |id|
    options[:eids] = id 
  end

  opt.on("-l","--line ROUTE_ID","bus route number or MAX color (R,G,B,Y). Required with 'to' command ") do |id|
    options[:rids] = id 
  end

  opt.on("-h","--help","help") do
    options[:help] = true
  end
end

opt_parser.parse!

ARGV.map! {|str| str = str.downcase}
commands = ['from','to']
commands.each do |c|
  if ARGV.include?(c)
    _index = ARGV.index(c) + 1
    options[c] = ARGV[_index] if ARGV.length >= _index
  end
end

puts options

if options.has_key? 'from'
  if options.has_key? 'to'
    track  = TrimetTrack.new("routeConfig", options[:rids])
    _stops = track.getRouteSequence(options[:rids], 10, options['from'],options['to'])
    track = TrimetTrack.new("arrivals", _stops)
  else 
    track = TrimetTrack.new("arrivals", options['from'])
    puts track.niceDisplay
  end
  track.parseXML
  track.filter_result(options[:rids]) if options.has_key? :rids
  puts track.niceDisplay
end
