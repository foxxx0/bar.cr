require "log"
require "colorize"
require "option_parser"
require "./src/*"
require "./lib/*"

Log.setup(:error)

VERSION = {{ `shards version #{__DIR__}`.chomp.stringify }}

config_path, log_level, log_path, flags, unknown_args = ArgParser.parse_args(ARGV)

unless unknown_args.empty?
  STDERR.puts "unknown arguments: #{unknown_args}"
  exit(3)
end

if config_path.nil?
  STDERR.puts "missing parameter: --config"
  exit(4)
end
config = {} of ConfigKey => ConfigValue
config = ConfigParser.parse_config(config_path.not_nil!)

Log.setup(log_level, log_path)

Colorize.on_tty_only!

bar = Bar.new(config)
bar.run
