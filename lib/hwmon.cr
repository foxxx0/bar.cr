# https://techpubs.jurassic.nl/manuals/linux/developer/REACTLINUX_PG/sgi_html/ch07.html
RE_SYSFS_PCI_DEV = /(?<domain>[[:xdigit:]]{4})\:(?<bus>[[:xdigit:]]{2})\:(?<slot>[[:xdigit:]]{2})\.(?<function>[[:xdigit:]]{1,})/x

HWMON_SYSFS_BASE = "/sys/class/hwmon"

DRIVER_WHITELIST = %w[coretemp k10temp nvme amdgpu nct6792 pch_skylake]

SENSOR_PREFIXES = %w[temp in fan power intrusion]
SENSOR_TEMPERATURE_SUFFIXES = %w[offset min max max_hyst crit crit_hyst crit_alarm alarm type]
SENSOR_POWER_SUFFIXES = %w[cap]
SENSOR_VOLTAGE_SUFFIXES = %w[min max alarm beep]
SENSOR_INTRUSION_SUFFIXES = %w[beep]
SENSOR_FAN_SUFFIXES = %w[min max alarm beep pulses]

@[AlwaysInline]
macro debug(text)
  {% unless flag?(:release) %}
    puts "DEBUG: " + {{text}}
  {% end %}
end

class Hwmon
  Log = ::Log.for(self)
  getter instances, instances_by_driver, instances_by_address

  @instances : Array(Hwmon::Instance)
  @instances_by_driver : Hash(String, Array(Hwmon::Instance))
  @instances_by_address : Hash(Int32, Hwmon::Instance)

  def initialize
    @instances = [] of Hwmon::Instance
    @instances_by_driver = {} of String => Array(Hwmon::Instance)
    @instances_by_address = {} of Int32 => Hwmon::Instance

    Log.debug { "beginning initialization, scanning for hwmon sysfs paths ..." }

    Dir.glob("#{HWMON_SYSFS_BASE}/hwmon*").sort.each do |hwmon_dir|
      id = hwmon_dir.split("/").last.chomp.lstrip("hwmon").to_i
      driver = File.read("#{hwmon_dir}/name").chomp
      if DRIVER_WHITELIST.includes?(driver)
        @instances_by_driver[driver] = [] of Hwmon::Instance unless @instances_by_driver.has_key?(driver)
        Log.debug { "examining hwmon '#{id}' using driver '#{driver}'" }
        device_path = File.readlink("#{hwmon_dir}/device").split("/").last
        Log.debug { "hwmon#{id} device_path = '#{device_path}'" }
        sub_type, subsystem = File.readlink("#{hwmon_dir}/device/subsystem").split("/")[-2..-1]
        Log.debug { "hwmon#{id} sub_type = '#{sub_type}', subsystem = '#{subsystem}'" }
        addr = pci_addr(sub_type, subsystem, device_path)
        Log.debug { sprintf "hwmon%d addr = '0x%04x'", id, addr }
        instance = Hwmon::Instance.new(id, driver, addr)
        @instances << instance
        @instances_by_driver[driver] << instance
        @instances_by_address[addr] = instance
      else
        Log.warn { "driver '#{driver}' not supported, skipping hwmon#{id} ..." }
        next
      end
    end
    Log.debug { "init done - #{self}" }
  end

  def to_s(io : IO)
    io << sprintf "%s with %d instances, loaded drivers: %s", self.class, @instances.size, @instances_by_driver.keys
  end

  def pci_addr(sub_type : String, subsystem : String, device_path : String) : Int32
    path = device_path
    case sub_type
    when "class"
      name = device_path
      begin
        Log.debug { "trying to find real device path for '#{device_path}'" }
        path = File.readlink("/sys/#{sub_type}/#{subsystem}/#{name}/device").split("/").last
        Log.debug { "using path '#{path}' for '#{device_path}'" }
      rescue File::NotFoundError
        Log.debug { "no alternate path found for '#{device_path}', using 0 for address" }
        return 0
      end
    end

    pci_match_data = RE_SYSFS_PCI_DEV.match(path)
    if pci_match_data
      domain = pci_match_data["domain"].to_i(16)
      bus = pci_match_data["bus"].to_i(16)
      slot = pci_match_data["slot"].to_i(16)
      function = pci_match_data["function"].to_i(16)
      Log.debug { sprintf "parsed pci device path to: %x %x %x %x", domain, bus, slot, function }
      # https://github.com/lm-sensors/lm-sensors/blob/00a5fadd2edccc0bdd4c06e5d3acf2da6c3feaa8/lib/sysfs.c#L659
      addr = (domain << 16) + (bus << 8) + (slot << 3) + function
      Log.debug { sprintf "calculated pci address to 0x%04x", addr }
      return addr
    else
      # raise "unable to find pci address of #{path}"
      Log.debug { "unable to find pci address of '#{device_path}', using 0 for address" }
      return 0
    end
  end

  def get_sensor(path : String) : Hwmon::Sensor
    driver, label = path.split(".", 2)
    driver, addr = driver.split("@", 2) if driver.includes?("@")
    driver_instances = @instances_by_driver[driver]

    instance = nil

    if driver_instances.size > 1 && addr.nil?
      error_msg = "more than one instance found for driver #{driver}, you need to specify the address"
      Log.error { error_msg }
      raise ArgumentError.new(error_msg)
    elsif driver_instances.size > 1 && addr
      matches = driver_instances.select { |i| i.address == addr }
      if matches.size == 1
        instance = matches.first
      else
        error_msg = "driver instance #{driver}@#{addr} not found!"
        Log.error { error_msg }
        raise error_msg
      end
    elsif driver_instances.size == 1
      instance = driver_instances.first
    else
      error_msg = "unknown error. #{driver}, #{label}, #{addr}, #{driver_instances}"
      Log.error { error_msg }
      raise error_msg
    end

    return instance.not_nil!.sensors_by_label[label]
  end

  enum SensorType
    Temperature
    Fan
    Voltage
    Power
    Intrusion
    Unknown = -1
  end

  class Instance
    Log = ::Log.for(self)
    getter id, driver, address, sensors, sensors_by_label, sensors_by_path

    def initialize(@id : Int32, @driver : String, @address : Int32)
      @sensors = [] of Hwmon::Sensor
      @sensors_by_label = {} of String => Hwmon::Sensor
      @sensors_by_name = {} of String => Hwmon::Sensor

      Log.debug { "beginning initialization, scanning for sensors ..." }

      self.scan_sensors.each do |name, label, path, type, unit, supplemental|
        sensor = Hwmon::Sensor.new(@id, name, label, path, type, unit, supplemental)
        @sensors << sensor
        @sensors_by_label[label] = sensor
        @sensors_by_name[name] = sensor
      end
      Log.debug { "init done - #{self}" }
    end

    def scan_sensors : Array(Tuple(String, String, String, Hwmon::SensorType, String, Array(String)))
      found = [] of Tuple(String, String, String, Hwmon::SensorType, String, Array(String))
      glob_matches = Dir.glob("#{HWMON_SYSFS_BASE}/hwmon#{@id}/{#{SENSOR_PREFIXES.join(",")}}*").map { |m| m.split("/").last }
      sensors = glob_matches.select { |n| n if /^(#{SENSOR_PREFIXES.join("|")})\d+_/.match(n) }.map { |n| n.split("_").first }.uniq.sort
      sensors.each do |sensor|
        Log.debug { "found sensor: '#{sensor}'" }
        label_path = "#{HWMON_SYSFS_BASE}/hwmon#{@id}/#{sensor}_label"
        label = if File.exists?(label_path)
                  File.read(label_path).chomp
                else
                  sensor
                end
        if label != sensor
          Log.debug { "found label '#{label}' for '#{sensor}' in '#{label_path}'" }
        else
          Log.debug { "no label for for '#{sensor}', using '#{label}' as fallback" }
        end

        type = Hwmon::SensorType::Unknown
        unit = ""
        path = "#{sensor}_input"
        supplemental = [] of String

        if /^temp\d+$/.match(sensor)
          type = Hwmon::SensorType::Temperature
          unit = "°C"
          supplemental = find_supplementals(sensor, SENSOR_TEMPERATURE_SUFFIXES)
          Log.debug { "found temperature sensor, using unit '#{unit}'. supplementals: #{supplemental}" }
        elsif /^fan\d+$/.match(sensor)
          type = Hwmon::SensorType::Fan
          unit = "RPM"
          supplemental = find_supplementals(sensor, SENSOR_FAN_SUFFIXES)
          Log.debug { "found fan sensor, using unit '#{unit}'. supplementals: #{supplemental}" }
        elsif /^in\d+$/.match(sensor)
          type = Hwmon::SensorType::Voltage
          unit = "V"
          supplemental = find_supplementals(sensor, SENSOR_VOLTAGE_SUFFIXES)
          Log.debug { "found voltage sensor, using unit '#{unit}'. supplementals: #{supplemental}" }
        elsif /^power\d+$/.match(sensor)
          path = "#{sensor}_average"
          type = Hwmon::SensorType::Power
          unit = "W"
          supplemental = find_supplementals(sensor, SENSOR_POWER_SUFFIXES)
          Log.debug { "found power sensor, using unit '#{unit}'. supplementals: #{supplemental}" }
        elsif /^intrusion\d+$/.match(sensor)
          path = "#{sensor}_alarm"
          type = Hwmon::SensorType::Intrusion
          supplemental = find_supplementals(sensor, SENSOR_INTRUSION_SUFFIXES)
          Log.debug { "found intrusion sensor. supplementals: #{supplemental}" }
        end
        found << { sensor, label, path, type, unit, supplemental }
      end
      found
    end

    def find_supplementals(sensor : String, suffixes : Array(String)) : Array(String)
      result = [] of String
      Dir.glob("#{HWMON_SYSFS_BASE}/hwmon#{@id}/#{sensor}_{#{suffixes.join(",")}}").each do |f|
          result << f.split("/").last
      end
      result
    end

    def to_s(io : IO)
      io << sprintf "hwmon%d @ 0x%04x using %s", @id, @address, @driver
    end
  end

  class Sensor
    Log = ::Log.for(self)
    getter id, name, label, path, type, supplementals, value, formatted

    def initialize(
      @id : Int32,
      @name : String,
      @label : String,
      @path : String,
      @type : Hwmon::SensorType,
      @unit : String,
      @supplementals : Array(String) = [] of String)
      Log.debug { "init done - #{self}" }
    end

    def to_s(io : IO)
      io << sprintf "%s (%s) at %s of type %s (hwmon%d)", @name, @label, @path, @type, @id
    end

    def raw_value : Int32
      value = self.read_hwmon(@path)
      Log.debug { "raw value: #{value}" }
      value
    end

    def value : Float64|Int32|String
      raw = self.raw_value
      case @type
      when Hwmon::SensorType::Temperature
        return raw > 0 ? raw / 1_000 : raw
      when Hwmon::SensorType::Power
        return raw > 0 ? raw / 1_000_000 : raw
      when Hwmon::SensorType::Fan
        return raw
      when Hwmon::SensorType::Voltage
        return raw > 0 ? raw / 1_000 : raw
      when Hwmon::SensorType::Intrusion
        value = if raw == 0
                  "no"
                elsif raw > 0
                  "YES"
                else
                  "UNKNOWN"
                end
        return value
      else
        return raw
      end
    end

    def formatted : String
      raw = self.raw_value
      case @type
      when Hwmon::SensorType::Temperature
        value = raw > 0 ? raw / 1_000 : raw
        sprintf "%9.1f%-5s", value, @unit
      when Hwmon::SensorType::Power
        value = raw > 0 ? raw / 1_000_000 : raw
        sprintf "%9.2f %-4s", value, @unit
      when Hwmon::SensorType::Fan
        value = raw
        sprintf "%9d %-4s", value, @unit
      when Hwmon::SensorType::Voltage
        if raw == 0
          sprintf "%9d %-4s", 0, "mV"
        elsif raw.abs < 1000
          sprintf "%9.1f %-4s", raw, "mV"
        else
          sprintf "%9.3f %-4s", (raw / 1_000), "V"
        end
      when Hwmon::SensorType::Intrusion
        value = if raw == 0
                  "no"
                elsif raw > 0
                  "YES"
                else
                  "UNKNOWN"
                end
        sprintf "%9s     ", value
      else
        sprintf "%9d     ", raw
      end
    end

    def properties : String
      result = [] of String
      @supplementals.each do |s|
        prop = s.split("_", 2).last
        raw = read_hwmon(s)
        value = case @type
                when Hwmon::SensorType::Temperature then raw / 1_000
                when Hwmon::SensorType::Power then raw / 1_000_000
                when Hwmon::SensorType::Fan then raw
                when Hwmon::SensorType::Voltage then raw / 1_000
                else raw
                end

        if prop.ends_with?("alarm") || prop.ends_with?("beep")
          interpreted = if raw == 0
                          "no"
                        elsif raw > 0
                          "YES"
                        else
                          "UNKNOWN"
                        end
          result << sprintf("%s: %s", prop, interpreted)
        elsif prop.ends_with?("alarm") || prop.ends_with?("beep") || prop.ends_with?("offset") || prop.ends_with?("pulses")
          result << sprintf("%s: %d", prop, raw)
        elsif prop.ends_with?("type")
          type = case raw
                 when 1 then "CPU diode"
                 when 2 then "transistor"
                 when 3 then "thermal_diode"
                 when 4 then "thermistor"
                 when 5 then "AMD AMDSI"
                 when 6 then "Intel PECI"
                 else "unknown"
                 end
          result << sprintf("sensor: %s", type)
        else
          result << sprintf("%s: %.2f %s", prop, value, @unit)
        end
      end
      result.join(", ")
    end

    private def read_hwmon(sensor : String) : Int32
      path = "#{HWMON_SYSFS_BASE}/hwmon#{@id}/#{sensor}"
      Log.debug { "trying to read value from path '#{path}'" }
      File.read(path).chomp.to_i
    end
  end
end
