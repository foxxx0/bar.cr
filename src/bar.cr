require "log"
require "colorize"
require "json"
require "../lib/helpers"
require "../lib/hwmon"
require "./types"
require "./block"
require "./blocks/*"

INSTANCE_PLUGINS = %w[hwmon]

class Bar
  Log = ::Log.for(self)

  include Helpers

  @header : Hash(String, Int32|Bool)
  @blocks : Hash(Int32, Block)
  @comm : Comm
  @tty : Bool
  @hmwmon : Hwmon|Nil

  def initialize(@config : ConfigHash)
    @header = { "version" => 1, "click_events" => false }
    @blocks = {} of Int32 => Block
    @comm = Comm.new(10)
    @tty = STDOUT.tty? && STDERR.tty? && ENV["TERM"]? != "dumb"
    STDOUT.sync = true
    @hwmon = nil

    used_plugins = @config.values.map { |v| v.fetch("plugin", "") }.uniq
    Log.debug { "used plugins: #{used_plugins}" }

    (INSTANCE_PLUGINS & used_plugins).each do |plugin|
      Log.info { "creating global (single) instance for plugin #{plugin}" }
      if plugin == "hwmon"
        @hwmon = Hwmon.new
      end
    end

    cfg_iter = @config.each
    1.upto(@config.keys.size) do |idx|
      k, v = cfg_iter.next.as(ConfigTuple)
      kwargs = block_kwargs(v)
      case v["plugin"]
      when "uname"
        @blocks[idx] = UnameBlock.new(@comm, idx, k, "#{k}-#{idx}", **kwargs)
      when "datetime"
        @blocks[idx] = DatetimeBlock.new(@comm, idx, k, "#{k}-#{idx}", **kwargs)
      when "hwmon"
        @blocks[idx] = HwmonBlock.new(@comm, idx, k, "#{k}-#{idx}", @hwmon.not_nil!, **kwargs)
      when "cpustats"
        @blocks[idx] = CpustatsBlock.new(@comm, idx, k, "#{k}-#{idx}", **kwargs)
      when "memstats"
        @blocks[idx] = MemstatsBlock.new(@comm, idx, k, "#{k}-#{idx}", **kwargs)
      when "uptime"
        @blocks[idx] = UptimeBlock.new(@comm, idx, k, "#{k}-#{idx}", **kwargs)
      end
    end
    Log.debug { "init done - #{self}" }
  end

  def to_s(io : IO)
    io << "Bar blocks: #{@blocks.values}"
  end

  def run
    Colorize.on_tty_only!
    unless @tty
      puts @header.to_json
      puts "["
      puts @blocks.values.map(&.to_h).to_json
      self.render
    end
    @blocks.values.map(&.run)
    loop do
      from, msg = @comm.receive
      Log.info { "got '#{msg}' from #{@blocks[from]}" }
      self.render
    end
  end

  private def render
    data = @blocks.values.map(&.to_h)
    if @tty
      formatted = data.map do |block|
        color = block.has_key?("color") ? Colorize::ColorRGB.new(*hexcolor_to_rgb(block["color"])) : Colorize::ColorANSI::Default
        block["full_text"].colorize(color)
      end
      printf "%s\n", formatted.join(" · ".colorize.dark_gray)
    else
      puts "," + data.to_json
    end
  end

  private def block_kwargs(block_cfg : ConfigValue)
    kwargs_h = {
      "interval" => 2,
      "color" => nil,
      "align" => Alignment::Left,
      "min_width" => "",
      "format" => ""
    }.as(ConfigValue)

    block_cfg.reject("plugin", "plugin_args").each do |k, v|
      kwargs_h[k] = v
    end

    return NamedTuple(
      interval: Int32|String,
      color: String|Nil,
      align: Alignment,
      min_width: String,
      format: String
    ).from(kwargs_h)
  end
end
