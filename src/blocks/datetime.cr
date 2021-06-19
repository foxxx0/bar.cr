require "../block"

class DatetimeBlock < Block
  def run
    spawn do
      loop do
        tstamp = Time.local
        @full_text = tstamp.to_s(@format)
        @comm.send({@id, @full_text})
        sleep sleep_time(@interval.as(Int32), tstamp)
      end
    end
  end
end
