require "../block"
require "../template"
require "../../lib/memstats"
require "../../lib/helpers"

class MemstatsBlock < Block
  Log = ::Log.for(self)

  include Helpers

  def initialize(
    @comm : Comm,
    @id : Int32,
    @name : String,
    @instance : String,
    @full_text : String = "",
    @interval : Int32|String = 2,
    @align : Alignment = Alignment::Left,
    @color : String|Nil = nil,
    @min_width : String = "",
    @format : String = "",
  )
    @template = Template.new(@format)
    Log.debug { "init done - #{self}" }
  end

  def run
    spawn do
      loop do
        @template.fields.each do |k, _|
          value = MemStats.get_value(k)
          if k == "pct"
            @template.fill({ k => value })
          else
            formatted, fmt, unit = format_kbytes(value.to_i64)
            value = sprintf("%5.2f %-3s", formatted, unit)
            @template.fill({ k => value })
          end
        end
        @full_text = @template.render
        @comm.send({@id, @full_text})
        sleep @interval.as(Int32)
      end
    end
  end
end
