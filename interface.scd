{
~arduino = FirmataDevice(SerialPort.devices[2]);

	6.wait;

~sensors = [\light, \temperature, \light2, \motion];

//:Window
~window = Window("Arduino").front
.view.layout = HLayout (
	* (~sliders = {Slider()} !4) );

~window.addNotifier(\arduino1, \light, { | val |
	~sliders[0].value = val / 1023;
	~light = ~sliders[0].value;
})
//temp = (5.0 * analogRead(tempPin) * 100.0) / 1024;
.addNotifier(\arduino1, \temperature, { | val |
	~sliders[1].value = val /1023;
	~temp = ~sliders[1].value;
})
.addNotifier(\arduino1, \light2, { | val |
	~sliders[2].value = val / 1023;
	~light2 = ~sliders[2].value;
})
.addNotifier(\arduino1, \motion, { | val |
	~sliders[3].value = val;
	~motion = ~sliders[3].value;
	~feedSynth.set(\xFade, val.linlin(0.0, 1.0, 1.0, -1.0) )
});

//:pins action


	~arduino.analogPinAction = {|index, value|
	{ \arduino1.changed(~sensors[index], value) }.defer;
	/*[index, value].postln;*/
};

~arduino.setPinMode(13, \INPUT);
~arduino.reportDigitalPort(1, true);

~arduino.digitalPortAction_({arg index, value;
	"Digital port % : %".format(index, value).postln;
	if ( value == 32 )
	{ "Motion Detected".warn; }
	{ "NO Motion".warn; };
	{ \arduino1.changed(~sensors[3], value) }.defer;
});



	// ~arduino.digitalPortAction = nil

	//:initiate
~arduino.reportAnalogPin(0, true);
~arduino.reportAnalogPin(1, true);
~arduino.reportAnalogPin(2, true);

~window.onClose = { ~window.objectClosed };

	0.5.wait;

	"~/Dropbox/Arduino/synth.scd".load;

}.fork(AppClock);

CmdPeriod.doOnce({ ~arduino.close; SerialPort.closeAll; ~window.close;  })




