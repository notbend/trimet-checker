#test/tc_cli_test.rb
require 'test/unit'

class TC_cli_Test < Test::Unit::TestCase
  def setup 
    @cli = File.join(File.dirname(__FILE__),'..','app','tc_cli.rb')
  end

  def test_help
    msg = "Can we get the --help output?"
    helps = ["#{@cli}","#{@cli} --help","#{@cli} -h"]
    helps.each do |help|
      assert_match('Usage: trimet COMMAND [-[OPTIONS]', `#{help}`, "#{msg} with command #{help}")
    end
  end

end
