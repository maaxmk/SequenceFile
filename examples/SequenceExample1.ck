
// instantiate
SequenceFile seq;

// select a location to load and save sequence file
seq.setDirectory(me.dir()+"sequences");

// run this to create a new sequence
//seq.createNewFile("example1",8); 
//me.yield(); // yield to prevent setting params before its finished 

// run this to load an existing sequence
seq.loadSequence("example1");      

// you only need to run these one time to write some data in the sequence file
/*
// "note" will set the midi note/frequency of s
seq.setParam(0,"note",31);
seq.setParam(2,"note",22);
seq.setParam(3,"note",14);
seq.setParam(5,"note",44);
seq.setParam(6,"note",10);

// "gain" will set the gain of m, inversely set the db of s and trigger the fm envelope
seq.setParam(0,"gain",0);
seq.setParam(2,"gain",12);
seq.setParam(3,"gain",4);
seq.setParam(4,"gain",6);
seq.setParam(7,"gain",12);

// "trig" will trigger the output envelope and set the length of decay
seq.setParam(0,"trig",100);
seq.setParam(3,"trig",255);
seq.setParam(5,"trig",10);
seq.setParam(6,"trig",50);
seq.setParam(7,"trig",100);

// "dope" will trigger a sample envelope and set the position of the sample
seq.setParam(3,"dope",255);
seq.setParam(7,"dope",25);
//*/

// Synth
SinOsc m => ADSR mEnv => SinOsc s => Gain g => LPF lp => ADSR env => dac;
m.freq(800);
s.sync(2);
env.set(8::ms,200::ms,0.,200::ms);
mEnv.set(8::ms,60::ms,0.,30::ms);
g.gain(0.4);
lp.freq(1200);

// Sample
SndBuf buf => ADSR dEnv => dac;
"special:dope" => buf.read;
1. => buf.rate;
0.75 => buf.gain;
dEnv.set(8::ms,60::ms,0.,30::ms);


130::ms => dur stepTime;
0 => int stepCount;

while(true) {
	
	<<< "step -", stepCount >>>;
	<<< "-------------","" >>>;
	
	// get all the parameter names for a step
	seq.paramDump(stepCount) @=> string names[];
	
	// interate through all parameters of the current step
	for(int p; p<names.size(); p++) {
		
		// paramValues is an associatively indexed array
		// it is updated with the param values for a step when paramDump() is called
		names[p] => string pName;
		seq.pVals()[names[p]] => int pVal;
		<<< pName, "=", pVal >>>;
		
		// use the parameters
		if(pName == "note") {
			Math.mtof(pVal+32) => s.freq;
		}
		if(pName == "gain") {
			Std.dbtolin(-pVal) => s.gain;
			pVal*200 => m.gain;
			mEnv.keyOn();
		}
		if(pName == "trig") {
			env.set(8::ms,pVal::ms,0.,pVal::ms);
			env.keyOn();
		}
		if(pName == "dope") {
			pVal*10 => buf.pos;
			dEnv.keyOn();
		}
		
	}
	
	if(!names.size()) <<< "no params","" >>>;
	<<< "=============","" >>>;
	
	
	// step forward in the sequence and modulo by sequence length
	(stepCount+1) % seq.getSequenceLength() => stepCount;
	
	stepTime => now;
	
}

