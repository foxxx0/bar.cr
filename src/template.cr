require "./types"

RE_TEMPLATE_FIELD = /(###(.*?)###)/

struct Template
  Log = ::Log.for("template")

  getter body : String
  getter fields : Hash(String, String)
  getter values : Hash(String, TemplateValue)

  def initialize(@body)
    Log.debug { "initializing template from: '#{@body}'" }
    @fields = {} of String => String
    @values = {} of String => TemplateValue
    @body.gsub(RE_TEMPLATE_FIELD) do |match|
      Log.debug { "found placeholder: '#{match}'" }
      prop, fmt = match.strip("#").split(":", 2)
      Log.debug { "property: '#{prop}', format: '#{fmt}'" }
      @fields[prop] = fmt
    end
    Log.debug { "init done - #{self}" }
  end

  def fill(values : Hash(String, TemplateValue))
    values.each do |k, v|
      if @fields.has_key?(k)
        Log.debug { "setting value '#{v}' for property '#{k}'" }
        @values[k] = v
      else
        error_msg = "value key '#{k}' not present in template body '#{@body}'"
        Log.error { error_msg }
        raise ArgumentError.new(error_msg)
      end
    end
  end

  def render : String
    @body.gsub(RE_TEMPLATE_FIELD) do |match|
      prop = match.strip("#").split(":", 2).first
      begin
        Log.debug { "trying to render '#{@values[prop]}' as '#{@fields[prop]}'" }
        sprintf @fields[prop], @values[prop]
      rescue ex : ArgumentError
        error_msg = "Malformed format string: #{@fields[prop]} (#{ex})"
        Log.error { error_msg }
        raise ArgumentError.new(error_msg)
      end
    end
  end
end
