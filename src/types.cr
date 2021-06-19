enum Alignment
  Left
  Center
  Right
end

alias Comm = Channel(Tuple(Int32, String))

alias ConfigKey = String
alias ConfigProperty = String|Int32|Nil|Alignment
alias ConfigValue = Hash(String, ConfigProperty)
alias ConfigHash = Hash(ConfigKey, ConfigValue)
alias ConfigTuple = Tuple(ConfigKey, ConfigValue)

alias TemplateValue = Float32|Float64|Int32|Int64|String
