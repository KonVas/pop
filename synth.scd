/*
A SuperCollider code constisting by sound oscillators and a feedback follower, the sound synthesis bit produces a series of random frequencies based in a fundamental value controlled by the light sensor, the other synth works as a feedback follower creating infinite drones of the former. The other element of the syntesis is a bank of oscillators which is activated when no motion occurs. The frequency value of the oscillators is controlled by a pitch tracker embedded in synth. In order to progress the stimuli of the environment, I implemented a system that tracks the input amplitude of the computer's microphone to attenuate the output of the feedbacked signal. Some machine-listening magic.
*/

///resources///
Server.default = s = Server.local;
o = Server.local.options;
o.numInputBusChannels_(2);
o.numOutputBusChannels_(2);
s.makeGui.window.alwaysOnTop = true;
s.meter;
s.reboot;
~feedBus = Bus.audio(s, 2);
~feedBus.scope(2);
~light=0.1;~light2=0.1;~temp=0.1;~motion=1;

s.waitForBoot({ {

SynthDef.new(\blip, {| out=0 |
	var sig, trig, env, freq;
	freq = LFNoise0.kr( \spCh.kr(0.1, 0.3) ).exprange( \fund.kr(200, 0.3), \fund.kr * 4 ).round( \fund.kr / 2 );
		trig = Dust.kr(\dens.kr(10, 0.3).round(0.01)) * \switch.kr(1, 0.1);
	sig = HPF.ar( SinOsc.ar(freq), 80);
	env = EnvGen.kr(Env.perc(\granAttack.kr(0.01, 0.3), \granRelease.kr(0.1, 0.3)), trig) * EnvGen.kr(Env.cutoff(\release.kr(1, 0.3)), \gate.kr(1, 0.3), doneAction: 2) ;
	sig = sig * env * \amp.kr(0.1, 0.3);
		PauseSelf.kr(\release.kr);
		Out.ar(out, Pan2.ar(sig, \pan.kr(0.0, 0.3), level:0.8) );
	Out.ar(~feedBus, sig )
}).add;
/*
	\/
	\/
 <feedBack>
	\/
	\/
*/
SynthDef.new(\feedblip, { | in |

	var source, pitch, sig, local, mic, amplitude, freq, hasFreq,
	threshold, attenuation, feedbackSignal, inputSignal, mod, out;

	inputSignal = Mix.new(In.ar(Server.default.options.numInputBusChannels));

	amplitude = Amplitude.kr(inputSignal);
	# freq, hasFreq = Pitch.kr(inputSignal);
	threshold = \thresh.kr(0.5);
	attenuation = (threshold - amplitude).max(0);


	sig = Limiter.ar(In.ar( ~feedBus, 2), \inLimit.kr(0.1) * attenuation );

	8.do { sig = AllpassN.ar(sig, 0.03, {Rand(0.005,0.02)}.dup, 1); };
	local = LocalIn.ar(2) * 0.98;
	local = OnePole.ar(local, 0.5);
	local = Rotate2.ar(local[0], local[1], 0.23);
	local = AllpassN.ar(local, 0.05, {Rand(0.01,0.05)}.dup, 2);
	local = DelayN.ar(local, 0.3, [0.19,0.26]);
	local = AllpassN.ar(local, 0.05, {Rand(0.03,0.15)}.dup, 2);
	local = LeakDC.ar(local);
	local = local + sig;
	LocalOut.ar(local);
		mod = Mix.new(local * VarSaw.ar( freq *  [0.5, 1, 2], 0, LFNoise0.kr(1).range(0, 1), \amp.kr(0.5, 0.3) ) );
      4.do({
			mod =  AllpassN.ar(mod, 0.040, [0.040.rand, 0.040.rand
			], 2);
		     });

		out = LinXFade2.ar(mod, local, \xFade.kr(-1).lag( 3 ) );

      OffsetOut.ar(0,
		out * attenuation  //.poll(label:"attenuation") //for debugging!
		)
}).add;

////////a pbind to play the blip synth///////
Pbind(
	\instrument, \blip,
	\out, Prand([0, ~feedBus], inf),
	\nodes, Pfunc{ ~light2.linlin(0.0, 1.0, 1.0, 5.0).asInteger },
	\dens, Pfunc{ ~light.linlin(0.0, 1.0, 0.3, 4.0).asFloat },
	\fund, Pfunc{ ~light.linexp(0.0, 1.0, 200, 1200).asInteger },
	\switch, Pfunc{ ~motion.asInteger },
	\granAttack, Pfunc{ ~temp / 100  },
	\granRelease, Pfunc{ ~temp / 100 + 0.3 },
	\amp, Pfunc { |e| 0.3! e.nodes / e.nodes},
	\fadeTime, 0.02,
	\detune, [0, 2, 5, 1],
	\sustain, 0.01,
	\release, Pfunc { ~motion.linlin(0, 1, 2, 0) },
	\delta, 1
).play;

s.sync;

~feedSynth = Synth( \feedblip, [\in, ~feedBus]);

	//~feedSynth.set(\thresh, 0.5)

NodeWatcher.register(~feedSynth);
~feedSynth.addNotifier(~feedSynth, \n_end, {| notification |
	notification.listener.objectClosed
});

}.fork(AppClock);
})