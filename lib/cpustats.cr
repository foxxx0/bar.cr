module CpuStats
  extend self
  Log = ::Log.for(self)
  getter fetch, pct, get_value

  def fetch : Tuple(Int64, Int64, Int64, Int64)
    stats = File.read("/proc/stat").lines.first.chomp.split
    Log.debug { "/proc/stat[0]: #{stats}" }
    { stats[1].to_i64, stats[2].to_i64, stats[3].to_i64, stats[4].to_i64 }
  end

  def pct : Float64
    stats1 =  self.fetch
    sleep 0.5
    stats2 =  self.fetch
    sum1 = stats1.to_a.sum
    sum2 = stats2.to_a.sum
    pct = (100 * ((sum2 - sum1) - (stats2[3] - stats1[3])) / (sum2 - sum1))
    Log.debug { "calculated #{pct} percent load from #{sum2} and #{sum1}" }
    pct
  end

  def get_value(prop : String) : Float64
    if prop == "pct"
      return self.pct
    else
      error_msg = "invalid CpuStats attribut: '#{prop}'"
      Log.error { error_msg }
      raise ArgumentError.new(error_msg)
    end
  end
end
