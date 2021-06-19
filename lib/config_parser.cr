require "../src/types"
require "ini"

module ConfigParser
  extend self
  Log = ::Log.for(self)

  class InvalidConfigError < Exception; end

  def parse_config(path : Path) : ConfigHash
    # TODO: add some proper validation to ensure the config is okay-ish
    begin
      raw = File.read(path)
      parsed = INI.parse(raw)
      result = {} of ConfigKey => ConfigValue
      parsed.each do |block, props|
        result[block] = {} of ConfigKey => ConfigProperty
        props.each do |k, v|
          value = v
          if k == "interval"
            value = case v
                    when /^[oO]nce$/ then v.downcase
                    when /^(\-|)\d+$/ then v.to_i
                    else raise InvalidConfigError.new("Invalid interval: #{v} (in block [#{block}])")
                    end
          end
          result[block][k] = value
        end
      end
      return result
    rescue File::NotFoundError
      STDERR.puts "ERROR: config file #{path} does not exist.\n"
      exit(2)
    rescue File::AccessDeniedError
      STDERR.puts "ERROR: insufficient permission to read config file #{path} .\n"
      exit(3)
    rescue ex : INI::ParseException
      STDERR.puts "ERROR: unable to parse config file #{path} :\n"
      STDERR.puts ex
      exit(4)
    end
  end
end
