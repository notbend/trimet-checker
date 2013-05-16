#!/usr/bin/env ruby
require 'optparse'
require_relative 'trimetcheck.rb'


options = {}
error   = ''

opt_parser = OptionParser.new do |opt|
  opt.banner = "Usage: trimet COMMAND [-[OPTIONS]"
  opt.separator  ""
  opt.separator  "Commands"
  opt.separator  "  from [LOCATION_ID(s)]. Bus or MAX stop id(s). If more than one, seperate by comma"
  opt.separator  "  to   [LOCATION_ID]. Destination Bus or MAX stop id. Returns arrivals at stops between from and to"
  opt.separator  "       -l, --line is required with to"
  opt.separator  ""

  opt.on("-l","--line ROUTE_ID", String,
         "bus route number or MAX color (R,G,B,Y). Required with 'to' command ") do |id|
    options[:rids] = id 
  end

  opt.on("-x","--xml",TrueClass,"output xml") do
    options[:xml] = true
  end

  opt.on("-t", "--test XML_FILE", String, "Trimet xml for testing") do |xml_file|
    options[:test_with] = xml_file
  end

  opt.on("-h","--help","help") do
    options[:help] = true
  end
  opt.separator  ""
  opt.separator  "Examples"
  opt.separator  "  trimet from 718,818"
  opt.separator  "  trimet from 718 to 818 --line 8"
  opt.separator  "  trimet from 718 to 818 --line R"
  opt.separator  "  trimet from 718 to 818 --line R -x"
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

if options.length < 1 or options[:help] == true
  puts opt_parser
  exit
end

if options.has_key? 'from'
  if options.has_key? 'to' and options.has_key? :rids
    track  = TrimetTrack.new("routeConfig", options[:rids])
    _stops = track.getRouteSequence(options[:rids], 10, options['from'],options['to'])
    track = TrimetTrack.new("arrivals", _stops)
  else 
    track = TrimetTrack.new("arrivals", options['from'])
  end

  if options.has_key? :test_with
    _file = File.open(options[:test_with], "rb")
    track.xml_data = _file.read 
    _file.close 
  end
  track.parseXML

  if options.has_key? :rids
    options[:rids].downcase!
    options[:rids].gsub!('r','90')
    options[:rids].gsub!('g','200')
    options[:rids].gsub!('b','100')
    options[:rids].gsub!('y','190')
    track.filter_result(options[:rids])
  end

  if options.has_key? :xml 
    puts track.xml_data
  else
    puts track.niceDisplay
  end
end

