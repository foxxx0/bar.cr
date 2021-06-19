require "../block"
require "../../lib/uptime"

class UptimeBlock < Block
  def run
    spawn do
      loop do
        tstamp = Time.local
        uptime = Uptime.fetch
        @full_text = Uptime.format(uptime)
        @comm.send({@id, @full_text})
        sleep sleep_time(@interval.as(Int32), tstamp)
      end
    end
  end
end
