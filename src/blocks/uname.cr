require "../block"

class UnameBlock < Block
  def run
    spawn do
      loop do
        # TODO: implement @format, currently the -r is hardcoded
        @full_text = `uname -r`.chomp
        @comm.send({@id, @full_text})
        if @interval == "once"
          sleep
        elsif @interval.is_a?(Int32) && @interval.as(Int32) > 0
          sleep @interval.as(Int32)
        else
          raise "#{self.class}: unsupported interval: #{@interval}"
        end
      end
    end
  end
end
