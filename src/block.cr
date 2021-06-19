require "log"
require "./types"
require "../lib/helpers"

abstract class Block
  Log = ::Log.for(self)

  include Helpers

  def initialize(
    @comm : Comm,
    @id : Int32,
    @name : String,
    @instance : String,
    @full_text : String = "",
    @color : String|Nil = nil,
    @interval : Int32|String = 2,
    @align : Alignment = Alignment::Left,
    @min_width : String = "",
    @format : String = ""
  )
    Log.debug { "init done - #{self}" }
  end

  def to_s(io : IO)
    io << sprintf "Block %d - '%s', '%s'", @id, @name, @instance
  end

  def to_h
    my_h = { "full_text" => @full_text,
             "name" => @name,
             "instance" => @instance,
             "align" => @align.to_s,
             "min_width" => @min_width }
    my_h["color"] = @color.not_nil! unless @color.nil?
    my_h
  end

  abstract def run
end
