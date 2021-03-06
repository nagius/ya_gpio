# YaGPIO - Yet Another GPIO module for Raspberry Pi
# Copyleft 2019 - Nicolas AGIUS <nicolas.agius@lps-it.fr>

###########################################################################
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
###########################################################################

# YaGPIO is a simple module to control GPIO port on a Raspberry Pi.
# It's based on the Sysfs interface.
#
# @example Open port 22 as output and set it to high
#   pin = YaGPIO.new(22, YaGPIO::OUTPUT)
#   pin.high
#
# @example Open port 23 as input and read its state
#   pin = YaGPIO.new(23, YaGPIO::INPUT)
#   pp pin.low?
#
class YaGPIO
	# File descriptor to the sysfs entry of the pin. It is not recommended to access the file
	# directly. Use high() lov() helpers instead.
	attr_reader :file

	# Direction input
	INPUT = 'in'

	# Direction output with default low
	OUTPUT = 'out'

	# Direction output with default high
	OUTPUT_HIGH = 'high'

	# Interruption on rising edge
	EDGE_RISING = 'rising'

	# Interruption on falling edge
	EDGE_FALLING = 'falling'

	# Interruption on rising and falling edge
	EDGE_BOTH = 'both'

	# Disable interruption
	EDGE_NONE = 'none'


	# Create and configure a new GPIO pin. The pin will be _exported_ via the sysfs interface.
	# The pin will be _unexported_ and released for other use upon garbage collection.
	#
	# @param pin [Integer] Pin number to configure, using the BCM numbering
	# @param direction [String] The direction if the port. Must be one of INPUT, OUTPUT or OUTPUT_HIGH
	def initialize(pin, direction)
		raise 'direction must be one of INPUT, OUTPUT, OUTPUT_HIGH' unless [INPUT, OUTPUT, OUTPUT_HIGH].include?(direction)

		@pin = pin
		@callback = nil
		@direction = direction

		export
		open

		ObjectSpace.define_finalizer(self, self.class.finalize(@pin))
	end


	# Return true if the pin is high
	#
	# @return [Boolean] State of the pin
	def high?
		read() != 0
	end

	# Return true if the pin is low
	#
	# @return [Boolean] State of the pin
	def low?
		read() == 0
	end

	# Set the pin to high
	def high
		write(1)
	end

	# Set the pin to low
	def low
		write(0)
	end

	# Invert all values and settings. After set to true, HIGH means LOW and LOW means HIGH.
	# Be prepared to be confused if you're using this feature.
	#
	# @param active [Boolean] Feature state
	def active_low=(active)
		File.write("/sys/class/gpio/gpio#{@pin}/active_low", active ? '1' : '0')
	end

	# Return true is active_low feature is enabled
	#
	# @return [Boolean] Feature state
	def active_low?
		File.read("/sys/class/gpio/gpio#{@pin}/active_low") != '0'
	end

	# Define a callback to execute when an interruption will be triggered.
	#
	# @param edge [String] Edge to trigger interrution. Can be EDGE_RISING, EDGE_FALLING or EDGE_BOTH
	# @param block [Block] Block to execute as callback
	def set_interrupt(edge, &block)
		raise 'interrupt can only be set on input pin' unless @direction == INPUT

		set_edge(edge)	
		@callback = block
	end

	# Disable a previously set interruption
	def clear_interrupt()
		set_edge(EDGE_NONE)	
		@callback = nil
	end

	# Execute the interruption's callback.
	#
	# @param active [Boolean] Should be true if the pin is high
	def trigger(active)
		if @callback.nil?
		    puts "No Callback defined for #{@pin}"
		else
		    @callback.call(active)
		end
	end

	# Release the pin.
	# The object cannot be used after this method is called as the pin will not be configured anymore.
	def unexport()
		@file.close
		File.write('/sys/class/gpio/unexport', @pin.to_s)
	end

	alias :close :unexport

	# Wait for an interruption to be trigerred and run the associated callback.
	# This method will block until the program exits or YaGPIO::resume() is called from a callback.
	# 
	# Note that software debounce has not been implemented.
	# You can use a 1µF capacitor in your setup to fix bounce issues.
	#
	# @param gpios [Array] Array of YaGPIO to monitor
	def self.wait(gpios)
		# Initial read to clear interrupt triggered during setup 
		gpios.map{|g| g.high?}

		@@wait = true
		while @@wait do
			rs, ws, es = IO.select(nil, nil, gpios.map{|g| g.file})

			es.each do |f|
				gpio = gpios.select{|g| g.file == f}.first
				gpio.trigger(gpio.high?)
			end
		end
	end

	# Stop the wait loop, must be run from a callback triggered by YaGPIO::wait()
	def self.resume
		@@wait = false
	end

	private

	MAX_RETRY = 3	# Number of retries when openning the sysfs file
	@@wait = true	# Flag to enable the wait infinite loop

	def export()
		begin
			File.write('/sys/class/gpio/export', @pin.to_s)
		rescue Errno::EBUSY
			puts "WARNING: GPIO #{@pin} is already exported, may be in use."
		end
	end

	def open
		begin
			retries ||= 0
			case @direction
				when INPUT
					@file=File.open("/sys/class/gpio/gpio#{@pin}/value", 'r')
				else
					@file=File.open("/sys/class/gpio/gpio#{@pin}/value", 'r+')
			end

			@file.sync=true	# Auto flush
			File.write("/sys/class/gpio/gpio#{@pin}/direction", @direction)
		rescue Errno::EACCES
			if (retries += 1) <= MAX_RETRY
				puts "Permission on sysfs not ready yet, retrying (#{retries}/#{MAX_RETRY})..."
				sleep 0.1
				retry
			end

			raise
		end
	end

	def set_edge(edge)
		raise 'edge must be one of EDGE_RISING, EDGE_FALLING, EDGE_BOTH, EDGE_NONE' unless [EDGE_RISING, EDGE_FALLING, EDGE_BOTH, EDGE_NONE].include?(edge)

		File.write("/sys/class/gpio/gpio#{@pin}/edge", edge)
	end

	def read()
		@file.seek(0, IO::SEEK_SET)
		@file.read().to_i
	end

	def write(value)
		@file.seek(0, IO::SEEK_SET)
		@file.write(value)
	end

	# Unexport the port when the program exits
	def self.finalize(pin)
		proc do
			File.write('/sys/class/gpio/unexport', pin)
		end
	end

end

# vim: ts=4:sw=4:ai
