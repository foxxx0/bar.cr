# bar.cr

i3bar-compatible json output generator, inspired by [i3blocks](https://github.com/vivien/i3blocks).

The main motivation for this to have a replacement with easier plugin support and to dive a bit into crystal again.

Note: This project is more or less still in the prototype/PoC state and subject to major changes.

## Requirements

For now crystal stdlib is sufficient, otherwise you can always check [shard.yml](../blob/master/shard.yml).


## Installation

There is no magic for downstream packaging or system-wide installation in place yet.
Basically it's just
```sh
crystal build --release app.cr
```
You can optionally specify `-o my_bar` to rename the output binary.


## Configuration

Simple INI format, inspired (again) by i3blocks.
Please see [example.ini](../blob/master/conf/example.ini) for an example.

There are still some quirks and likely some changes

Each block has to start with a unique name as an INI segment within square brackets (`[]`).
Afterwards a number of properties can and must be set.

Mandatory:
 - plugin
 - format

Optional:
 - color
 - interval

### plugin
Specify which plugin to load for this block.
Currently only exactly one plugin per block is supported.

### format
This is used to control the output format of the block.
Plugins may support special directives a.k.a. placeholders to reference values and apply a custom formatting.

### color
Colorize the output of this block.
Example: `#ffccbb` (hexadecimal `#rrggbb`)

### interval
Interval between updates of this block in seconds.
Currently one special value `once` which disables any further updates after the initial one.

### Plugins

#### datetime
Available directives: [Time::Format](https://crystal-lang.org/api/1.0.0/Time/Format.html)
Example:
```ini
plugin=datetime
format=Time is %H:%M:%S, today is %A %d.%m.%Y
```

#### uname
Available directives: TODO
Currently this is hardcoded to `uname -r` and shoulst support all command line options to `uname` in the future.

#### uptime
Available directives: none
Will output a formatted string based on the current uptime of the machine.

#### cpustats
Available directives: `pct`
Format syntax: `###DIRECTIVE:FORMAT###`
The `FORMAT` part is internally passed to `#sprintf()`, for details refer to [#sprintf](https://crystal-lang.org/api/1.0.0/toplevel.html#sprintf%28format_string,args:Array%7CTuple%29:String-class-method).
Be advised, the `%f` field type does not support zero decimal places, e.g. `%3.0f` is invalid and will result in an error. Use `%d` in these cases.
Example:
```ini
plugin=cpustats
format=CPU utilization is ###pct:%3d### percent
```

#### memstats
Available directives: `pct`, `avail`, `used`, `total`
Format syntax: `###DIRECTIVE:FORMAT###`
Attention: For all directives except `pct` you need to use `%s` as `FORMAT` right now, as the value is interally formatted based on its value with the corresponding unit.
Example:
```ini
plugin=memstats
format=CPU utilization is ###pct:%3d### percent
```

#### hwmon
Directive syntax: `DRIVER@ADDRESS.SENSOR`
Format syntax: `###DIRECTIVE:FORMAT###`
The `FORMAT` part is internally passed to `#sprintf()`, for details refer to [#sprintf](https://crystal-lang.org/api/1.0.0/toplevel.html#sprintf%28format_string,args:Array%7CTuple%29:String-class-method).
Be advised, the `%f` field type does not support zero decimal places, e.g. `%3.0f` is invalid and will result in an error. Use `%d` in these cases.

You can install `lm_sensors`, run `sensors-detect` and then use the output of `sensors` for reference.

The `DRIVER` directive is the first part of the header in each segment of the `sensors` output (the part before the first dash).
For example, `k10temp-pci-00c3` would translate to driver `k10temp`.

The `@ADDRESS` is not fully implemented and only needed when you have multiple hwmon instances for one driver. E.g. dual-socket system with two physical CPUS, multiple graphics cards, multiple NVMEs, and so on. It is the last part of the header in each segment.
For example, `k10temp-pci-00c3` would translate to address `00c3`.

The `SENSOR` directive is used to select the desired sensor. If a so-called label for a sensor exists, you have to use that, otherwise the sensor name is used. You can compare `sensors` vs. `sensors -u`, e.g. the `k10temp` sensor with label `Tdie` is named `temp2` (ignore everything after and including the first underscore).
Example:
```ini
plugin=hwmon
format=CPU temperature is ###k10temp.Tdie:%3d### percent
```

#### amixer
TODO

#### playerctl
TODO

## Integration with i3wm / i3bar

In order to use `bar.cr` in your i3wm setup, simply call the compiled binary together with a config file from within a `bar { ... }` section of your i3wm config:
```conf
bar {
   status_command /path/to/compiled/app -c ~/my_fancy_bar.ini
}
```

## Debugging

Some logging options are available as command line arguments.
Please run the compiled binary with `-h`/`--help` for further details.

Additionally, you can run the bar in terminal-mode by starting it from within a terminal and it will start outputting there.
This can come in handy for some testing and to check if it does what you want.
Combine this with the logging options and you should be able to track down whatever is misbehaving.

If you want to dig around in the code and test out your changes, there is no need to compile an optimized release binary every time.
You can "run" the application using:
```sh
crystal run app.cr -- -l debug -t debug.log -c my_config.ini
```

## Contributing

### Community contributions

Pull requests and feedback are welcome.

### Bugs

If you believe that you have found a bug, please take a look at the existing issues.
In case no one else has reported the bug yet, please open a new issue and describe
the problem as detailed as possible.

## License

Licensed under the GNU Affero General Public License, Version 3 (the "License").
You may not use this software except in compliance with License.
You should have obtained a copy of the License together with this software,
if not you may obtain a copy at [https://www.gnu.org/licenses/agpl-3.0.en.html](https://www.gnu.org/licenses/agpl-3.0.en.html).

```
https://www.gnu.org/licenses/agpl-3.0.en.html
```
