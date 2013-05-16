#test/tc_cli_test.rb
require 'test/unit'

class TC_cli_Test < Test::Unit::TestCase
  def setup 
    @cli = File.join(File.dirname(__FILE__),'..','app','tc_cli.rb')
    @data1 = {
      :stops => '7646,7634', #unrelated stops
      :to    => nil,
      :xml   => '../test/xml/7646_7634_840_wed_arrivals.xml',
      :line  => nil 
    } 
    @data2 = {
      :stops => '10491',
      :to    => '11010', 
      :xml   => '../test/xml/10491_to_11010.xml',
      :line  => '8' 
    } 
  end

  def test_help
    _msg = "Can we get the --help output?"
    _helps = ["#{@cli}","#{@cli} --help","#{@cli} -h"]
    _helps.each do |help|
      assert_match('Usage: trimet COMMAND [-[OPTIONS]', `#{help}`, "#{_msg} with this command: #{help}")
    end
  end
  
  def test_from
    _command = "#{@cli} from #{@data1[:stops]} --test #{@data1[:xml]}"
    _msg ="can we use 'from' by itself with this command: #{_command}"
    assert_match('Green Line', `#{_command}`, _msg)
  end

  def test_to
    _command = "#{@cli} from #{@data2[:stops]} to #{@data2[:to]} --test #{@data2[:xml]}  --line #{@data2[:line]}" 
    _msg ="can we use the command format 'from x to y' and gets inbetween stops?"
    assert_match('Stop ID 7794', `#{_command}`, _msg)
  end

  def test_xml_output
    _command = "#{@cli} from #{@data1[:stops]} --test #{@data1[:xml]} --xml"
    _msg ="can we output unfiltered xml"
    _f = File.open(@data1[:xml], "rb")
    _xml_data = _f.read
    _f.close
    assert_equal(_xml_data,`#{_command}`, _msg)
  end

end
