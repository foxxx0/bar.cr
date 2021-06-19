BYTE_UNITS = %w[B KiB MiB GiB TiB PiB]

module Helpers
  extend self
  Log = ::Log.for(self)

  macro debug(text)
    {% unless flag?(:release) %}
      puts "DEBUG: " + {{text}}
    {% end %}
  end

  def sleep_time(interval : Int32, tstamp : Time = Time.local) : Float64
    interval - ((tstamp.to_unix_ms/1_000) % interval)
  end

  def hexcolor_to_rgb(hex : String) : Tuple(UInt8, UInt8, UInt8)
    values = hex.lstrip("#")
    slice_sz = if (4..6).includes?(values.size)
                 2
               elsif (1..3).includes?(values.size)
                 1
               else
                 raise ArgumentError.new("invalid hexadecimal color: '#{hex}'")
               end

    colors = [] of UInt8
    values.chars.each_slice(slice_sz) do |slice|
      colors << slice.join.rjust(2, '0').to_u8(16)
    end

    raise "convert failed, too few slices: #{colors}" if colors.size < 3
    raise "convert failed, too many slices: #{colors}" if colors.size > 3

    { colors[0], colors[1], colors[2] }
  end

  def format_bytes(bytes : Int64) : Tuple((Float64|Int64), String, String)
    unit = ""
    formatted = bytes
    BYTE_UNITS.each_with_index do |u, idx|
      unit = u
      break if formatted < 1000
      formatted /= 1024
    end
    format = unit == "B" ? "%d" : "%.2f"
    { formatted, format, unit }
  end

  def format_kbytes(kbytes : Int64) : Tuple((Float64|Int64), String, String)
    unit = ""
    formatted = kbytes
    BYTE_UNITS[1..-1].each_with_index do |u, idx|
      unit = u
      break if formatted < 1000
      formatted /= 1024
    end
    format = "%.2f"
    { formatted, format, unit }
  end
end
