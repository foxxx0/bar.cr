module MemStats
  extend self
  Log = ::Log.for(self)

  def fetch : Tuple(Int64, Int64)
    total = Int64::MIN
    avail = Int64::MIN
    File.read("/proc/meminfo").lines.map(&.chomp).each do |line|
      if line.starts_with?("MemTotal:")
        total = line.split[1].to_i64
      elsif line.starts_with?("MemAvailable:")
        avail = line.split[1].to_i64
      end
    end
    { total, avail }
  end

  def pct : Float64
    total, avail =  self.fetch
    pct = 100 * (total - avail)/total
    Log.debug { "calculated #{pct} percent load from #{total} total and #{total} avail" }
    pct
  end

  def used : Int64
    total, avail =  self.fetch
    used = total - avail
  end

  def avail : Int64
    self.fetch[1]
  end

  def total : Int64
    self.fetch[0]
  end

  def get_value(prop : String) : Int64|Float64
    if prop == "pct"
      return self.pct
    elsif prop == "avail"
      return self.avail
    elsif prop == "used"
      return self.used
    elsif prop == "total"
      return self.total
    else
      error_msg = "invalid MemStats attribut: '#{prop}'"
      Log.error { error_msg }
      raise ArgumentError.new(error_msg)
    end
  end
end
