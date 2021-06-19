require "log"

module ArgParser
  extend self
  Log = ::Log.for(self)

  def parse_args(args)
    config_path = nil
    log_level = ::Log::Severity::Error
    log_path = ::Log::IOBackend.new(STDOUT)
    flags = [] of String
    unknown = [] of String
    OptionParser.parse do |parser|
      parser.banner = "Usage: #{PROGRAM_NAME} [switches]"

      parser.on "-v", "--version", "Show version" do
        puts "version #{VERSION}"
        exit
      end
      parser.on "-h", "--help", "Show help" do
        puts parser
        exit
      end
      parser.on "-d", "--debug", "Enable debug output" do
        log_level = ::Log::Severity::Debug
        flags << "--debug"
      end
      parser.on "-l LEVEL", "--loglevel=LEVEL", "Specify loglevel" do |level|
        log_level = case level.downcase
                when "trace" then ::Log::Severity::Trace
                when "debug" then ::Log::Severity::Debug
                when "info" then ::Log::Severity::Info
                when "notice" then ::Log::Severity::Notice
                when "warn" then ::Log::Severity::Warn
                when "error" then ::Log::Severity::Error
                when "fatal" then ::Log::Severity::Fatal
                else
                  STDERR.puts "invalid loglevel: '#{level}'"
                  exit(5)
                end
        flags << "--loglevel=#{level}"
      end
      parser.on "-t FILE", "--logto=FILE", "Specify where to log to" do |path|
        expanded_path = Path.posix(path).normalize.expand(home: true)
        # TODO: needs some validation + ensure writing to that file is possible
        log_path = ::Log::IOBackend.new(File.new(expanded_path, "a+"))
        flags << "--logto=#{path}"
      end
      parser.on "-c CONFIG", "--config=CONFIG", "Configuration file to use" do |path|
        config_path = Path.posix(path).normalize.expand(home: true)
        flags << "--config=#{path}"
      end
      parser.missing_option do |option_flag|
        error_msg = "#{option_flag} is missing a parameter.\n#{parser}"
        Log.fatal { error_msg }
        exit(1)
      end
      parser.invalid_option do |option_flag|
        error_msg = "#{option_flag} is not a valid option.\n#{parser}"
        Log.fatal { error_msg }
        exit(2)
      end
      parser.unknown_args do |arg|
        unknown.concat(arg)
      end
    end
    { config_path, log_level, log_path, flags, unknown }
  end
end
