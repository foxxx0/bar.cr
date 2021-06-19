require "../block"
require "../template"
require "../../lib/cpustats"

class CpustatsBlock < Block
  Log = ::Log.for(self)

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
          @template.fill({ k => CpuStats.get_value(k) })
        end
        @full_text = @template.render
        @comm.send({@id, @full_text})
        sleep @interval.as(Int32)
      end
    end
  end
end
