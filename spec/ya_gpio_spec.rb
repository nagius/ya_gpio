require 'spec_helper'

# test permission?


describe YaGPIO do
	include FakeFS::SpecHelpers

	let(:pin) { 12 }

	before do
		FileUtils.makedirs("/sys/class/gpio/gpio#{pin}")
		FileUtils.touch("/sys/class/gpio/gpio#{pin}/value")
	end

	it 'open a GPIO as output' do
		gpio = YaGPIO.new(pin, YaGPIO::OUTPUT)

		expect(File.read('/sys/class/gpio/export')).to eq pin.to_s
		expect(File.read("/sys/class/gpio/gpio#{pin}/direction")).to eq 'out'
	end

	it 'open a GPIO as output with default HIGH value' do
		gpio = YaGPIO.new(pin, YaGPIO::OUTPUT_HIGH)

		expect(File.read('/sys/class/gpio/export')).to eq pin.to_s
		expect(File.read("/sys/class/gpio/gpio#{pin}/direction")).to eq 'high'
	end

	it 'open a GPIO as input' do
		gpio = YaGPIO.new(pin, YaGPIO::INPUT)

		expect(File.read('/sys/class/gpio/export')).to eq pin.to_s
		expect(File.read("/sys/class/gpio/gpio#{pin}/direction")).to eq 'in'
	end

	it 'close the GPIO' do
		gpio = YaGPIO.new(pin, YaGPIO::INPUT)
		gpio.unexport

		expect(File.read('/sys/class/gpio/unexport')).to eq pin.to_s
	end

	it 'close the GPIO #2' do
		gpio = YaGPIO.new(pin, YaGPIO::INPUT)
		gpio.close

		expect(File.read('/sys/class/gpio/unexport')).to eq pin.to_s
	end
		
	it 'close the GPIO when destroyed' do
		gpio = YaGPIO.new(pin, YaGPIO::INPUT)
		gpio = nil

		GC.start
		expect(File.read('/sys/class/gpio/unexport')).to eq pin.to_s
	end

	it 'raise when instantiated with wrong direction' do
		expect{YaGPIO.new(pin, 'wrong-direction')}.to raise_error(RuntimeError)
	end

	it 'set active_low' do
		gpio = YaGPIO.new(pin, YaGPIO::OUTPUT)

		gpio.active_low = true
		expect(File.read("/sys/class/gpio/gpio#{pin}/active_low")).to eq '1'

		gpio.active_low = false
		expect(File.read("/sys/class/gpio/gpio#{pin}/active_low")).to eq '0'
	end
		
	it 'get active_low' do
		gpio = YaGPIO.new(pin, YaGPIO::OUTPUT)

		File.write("/sys/class/gpio/gpio#{pin}/active_low", '1')
		expect(gpio.active_low?).to be true

		File.write("/sys/class/gpio/gpio#{pin}/active_low", '0')
		expect(gpio.active_low?).to be false
	end
			
		
	it 'reads high value' do
		File.write("/sys/class/gpio/gpio#{pin}/value", '1')
		gpio = YaGPIO.new(pin, YaGPIO::INPUT)

		expect(gpio.high?).to be true
		expect(gpio.low?).to be false
	end

	it 'reads low value' do
		File.write("/sys/class/gpio/gpio#{pin}/value", '0')
		gpio = YaGPIO.new(pin, YaGPIO::INPUT)

		expect(gpio.high?).to be false
		expect(gpio.low?).to be true
	end

	it 'set high value' do
		gpio = YaGPIO.new(pin, YaGPIO::OUTPUT)
		gpio.high

		expect(File.read("/sys/class/gpio/gpio#{pin}/value")).to eq '1'
	end
		
	it 'set low value' do
		gpio = YaGPIO.new(pin, YaGPIO::OUTPUT)
		gpio.low

		expect(File.read("/sys/class/gpio/gpio#{pin}/value")).to eq '0'
	end

	it 'setup interrupt with edge' do
		gpio = YaGPIO.new(pin, YaGPIO::INPUT)

		gpio.set_interrupt(YaGPIO::EDGE_RISING)
		expect(File.read("/sys/class/gpio/gpio#{pin}/edge")).to eq 'rising'

		gpio.set_interrupt(YaGPIO::EDGE_FALLING)
		expect(File.read("/sys/class/gpio/gpio#{pin}/edge")).to eq 'falling'

		gpio.set_interrupt(YaGPIO::EDGE_BOTH)
		expect(File.read("/sys/class/gpio/gpio#{pin}/edge")).to eq 'both'
	end

	it 'raise when interrupt set with wrong edge' do
		gpio = YaGPIO.new(pin, YaGPIO::INPUT)

		expect{gpio.set_interrupt('wrong-edge')}.to raise_error(RuntimeError)
	end

	it 'clear interrupt' do
		gpio = YaGPIO.new(pin, YaGPIO::INPUT)
		gpio.clear_interrupt

		expect(File.read("/sys/class/gpio/gpio#{pin}/edge")).to eq 'none'
	end

	it 'wait for an interrupt and run callback once' do
		callback_count = 0
		File.write("/sys/class/gpio/gpio#{pin}/value", '1')

		gpio = YaGPIO.new(pin, YaGPIO::INPUT)
		gpio.set_interrupt(YaGPIO::EDGE_BOTH) do |active|
			callback_count += 1
			expect(active).to be true
			
			YaGPIO::resume # Prevent infinite loop during testing
		end

		allow(IO).to receive(:select).with(nil, nil, [gpio.file]).and_return([nil, nil, [gpio.file]])
		YaGPIO::wait([gpio])
		expect(callback_count).to eq 1
	end
	
end

# vim: ts=4:sw=4:ai
