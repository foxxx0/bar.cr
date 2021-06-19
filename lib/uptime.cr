module Uptime
  extend self
  Log = ::Log.for(self)

  def fetch : Time::Span
    uptime_f = File.read("/proc/uptime").chomp.split.first.to_f64
    uptime_s = uptime_f.floor.to_i64
    uptime_ns = ((uptime_f - uptime_s) * 1_000_000_000).to_i64
    span = Time::Span.new(seconds: uptime_s, nanoseconds: uptime_ns)
    Log.debug { "uptime span = #{span}" }
    span
  end

  def format(span : Time::Span) : String
    out = ""
    out += sprintf("%dd ", span.days) if span.days > 0
    if span.hours > 0
      out += sprintf("%2dh %2dm", span.hours, span.minutes)
    else
      out += sprintf("%2dm %2ds", span.minutes, span.seconds)
    end
    out
  end
end
