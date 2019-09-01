# Yet Another GPIO gem for Raspberry Pi

## But why ?

Because making a new wheel is always fun !

There is already plenty of GPIO libraries for Raspberry Pi :

 - some using plain C : [c_GPIO](https://github.com/hujiko/c_GPIO)
 - some using the BCM C libs : [rpi_gpio](https://github.com/ClockVapor/rpi_gpio)
 - some small ones using Sysfs : [ruby-gpio](https://github.com/sausheong/ruby-gpio), [gpio](https://github.com/klappy/gpio), [raspi-gpio-rb](https://github.com/exybore/raspi-gpio-rb)
 - some big ones based on EventMachine : [pi_piper](https://github.com/jwhitehorn/pi_piper), [em-gpio](https://github.com/railsbob/em-gpio)

But none of them support interruptions to trigger events. I mean proper interruption without pooling within an infinite loop (and sometimes a sleep).
For example, _rpi-gpio_ gem is very good but the `wait_for_edge()` method is not available (yet).

This implementation is based on the Sysfs interface and so do not support integrated pull-down an pull-up resistors.
See [official kernel documentation](https://www.kernel.org/doc/Documentation/gpio/sysfs.txt) for more details.

NOTE: The pin number specified in the initializer uses *BCM numbering*.

## Permissions

Please note that lib require read/write access to the GPIO Sysfs subdirectory `/sys/class/gpio/`. If your script is not running as root, add your user to the `gpio` group.
On most Raspberry Pi compatible distributions, an UDEV event will automatically set proper permissions once the port is exported.

## Using interruptions

The implementation of the interrupt hander is based on Sysfs and uses the select(2) syscall, according to the offical linux kernel documentation. You can find an example in C here : [Attentes passives sur GPIO](https://www.blaess.fr/christophe/2013/04/15/attentes-passives-sur-gpio/).

Another implementation using poll(2) in ruby : [Evented GPIO on Raspberry PI with Ruby](https://tenderlovemaking.com/2017/01/17/evented-gpio-on-raspberry-pi-with-ruby.html)

### Example

```ruby
require 'ya_gpio'

led     = YaGPIO.new(23, YaGPIO::OUTPUT)
button1 = YaGPIO.new(22, YaGPIO::INPUT)
button2 = YaGPIO.new(25, YaGPIO::INPUT)

# Turn the led on when button 1 is pressed and 
# off when released
button1.set_interrupt(YaGPIO::EDGE_BOTH) do |high|
  if high
    led.high
  else
    led.low
  end
end

# Stop the wait() loop when button 2 is pressed
button2.set_interrupt(YaGPIO::EDGE_RISING) do |high|
  YaGPIO::resume
end

puts "ready"
YaGPIO::wait([button1, button2])
puts "wait() loop terminated"

```

If your application needs to listen to other file descriptors, you can override the `wait()` method to include those FDs in the `select()` call. See `lib/ya_gpio.rb` source file for more information.


## Testing

This module is fully tested on Raspberry Pi and has testing with rspec. To run them :

```
bundle install
bundle exec rake spec
```

## API documentation

The API documentation is available in the Yard format. To generate it under the `doc` directory, run :

```
bundle exec rake yard
```

## License

Copyleft 2019 - Nicolas AGIUS - GNU GPLv3

