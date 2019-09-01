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

class YaGPIO
	attr_reader :file	

	INPUT = 'in'
	OUTPUT = 'out'
	OUTPUT_HIGH = 'high'

	EDGE_RISING = 'rising'
	EDGE_FALLING = 'falling'
	EDGE_BOTH = 'both'
	EDGE_NONE = 'none'

	MAX_RETRY = 3

	@@wait = true

	def initialize(pin, direction)
		raise 'direction must be one of INPUT, OUTPUT, OUTPUT_HIGH' unless [INPUT, OUTPUT, OUTPUT_HIGH].include?(direction)

		@pin = pin
		@callback = nil
		@direction = direction

		export
		open

		ObjectSpace.define_finalizer(self, self.class.finalize(@pin))
	end

	# Unexport the port when the program exits
	def self.finalize(pin)
		proc do
			File.write('/sys/class/gpio/unexport', pin)
 		end
	end

	def high?
		read() != 0
	end

	def low?
		read() == 0
	end

	def high
		write(1)
	end

	def low
		write(0)
	end

	# Invert all values and settings. After set to true, HIGH means LOW and LOW means HIGH.
	# Be prepared to be confused if you're using this feature
	def active_low=(active)
		File.write("/sys/class/gpio/gpio#{@pin}/active_low", active ? '1' : '0')
	end

	def active_low?
		File.read("/sys/class/gpio/gpio#{@pin}/active_low") != '0'
	end

	def set_interrupt(edge, &block)
		raise 'interrupt can only be set on input pin' unless @direction == INPUT

		set_edge(edge)	
		@callback = block
	end

	def clear_interrupt()
		set_edge(EDGE_NONE)	
		@callback = nil
	end

	def trigger(active)
		if @callback.nil?
		    puts "No Callback defined for #{@pin}"
		else
		    @callback.call(active)
		end
	end

	def unexport()
		File.write('/sys/class/gpio/unexport', @pin.to_s)
	end

	alias :close :unexport

	# Software debounce has not been implemented.
	# You can use a 1uF capacitor in your setup to fix bounce issues.
	#
	# Will block until the program exits or YaGPIO::resume() is called from a callback
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

	# Stop the wait loop, must be run from a callbacktriggered by the wait
	def self.resume
		@@wait = false
	end

	private

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
end

# vim: ts=4:sw=4:ai
