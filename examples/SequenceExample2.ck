
/*

with this example you can edit the sequence with your keyboard
MAKE SURE YOU CLICK ON YOUR DESKTOP BEFORE PRESSING KEYS 
OR YOU WILL EDIT THE FILE WHILE YOUR JAMMING!

keys: 1 - 8
Select the step you want to edit the values of

keys: up, down
Edit the value of the "dope" sound, 0 = no sound

keys: left, right
Edit the value of the "fm" sound, 0 = no sound

*/


SequenceFile seq;

// select a location to load and save sequence file
seq.setDirectory(me.dir()+"sequences");
"example2" => string exampleFile;

// run this to create a new sequence
//seq.createNewFile(exampleFile,8); 
//me.yield(); // yield to prevent setting params before its finished 

// run this to load an existing sequence
seq.loadSequence(exampleFile);



// Synth
PulseOsc m => ADSR mEnv => SinOsc s => Gain g => LPF lp => ADSR env => dac;
m.freq(800);
s.sync(1);
env.set(8::ms,200::ms,0.,200::ms);
mEnv.set(8::ms,60::ms,0.,30::ms);
g.gain(0.4);
lp.freq(4200);

// Sample
SndBuf buf => ADSR dEnv => dac;
"special:dope" => buf.read;
0.5 => buf.rate;
0.65 => buf.gain;
dEnv.set(1::ms,60::ms,0.,30::ms);



// setup the keyboard input
Hid hid;
HidMsg hidMsg;

// The devcice number below is the keyboard to use for the sequencer controller
// To find the right number goto the Device Browser window (cmnd+2) in miniAudicle or chuck --probe in cli
// in the device browser select "Human Interface Devices" in the drop-down menu
1 => int device;

if( !hid.openKeyboard( device ) ) me.exit();
<<< "keyboard '" + hid.name() + "' ready", "" >>>;

0 => int editStep;

fun void hidListener() {
	while(1) {
		hid => now;
		while(hid.recv( hidMsg )) {
			
			if(hidMsg.isButtonDown()) {
				if(hidMsg.which>29 && hidMsg.which<38) {
					hidMsg.which-30 => int newStep;
					if(newStep != editStep) {
						newStep => editStep;
						<<< "step selected: ", editStep >>>;
					}
				}
				
				if(hidMsg.which==79) { // right
					seq.addToParam(editStep,"fm",4) => int newVal;
					<<< "step:",editStep,"fm",newVal >>>;
				}
				
				if(hidMsg.which==80) { // left
					seq.addToParam(editStep,"fm",-4) => int newVal;
					<<< "step:",editStep,"fm",newVal >>>;
				}
				
				if(hidMsg.which==81) { // down
					seq.addToParam(editStep,"dope",-4) => int newVal;
					<<< "step:",editStep,"dope",newVal >>>;
				}
				
				if(hidMsg.which==82) { // up
					seq.addToParam(editStep,"dope",4) => int newVal;
					<<< "step:",editStep,"dope",newVal >>>;
				}
			}
			
		}
	}
}
spork ~ hidListener();



130::ms => dur stepTime;
0 => int stepCount;

while(true) {
	
	// get all the parameter names for a step
	seq.paramDump(stepCount) @=> string names[];
	
	// interate through all parameters of the current step
	for(int p; p<names.size(); p++) {
		
		// paramValues is an associatively indexed array
		// it is updated with the param values for a step when paramDump() is called
		names[p] => string pName;
		seq.pVals()[names[p]] => int pVal;
		
		// use the parameters
		if(pName == "fm") {
			Math.pow(pVal/4,2) => s.freq;
			pVal*5 => m.gain;
			800+Math.sin(pVal*0.43)*400 => m.freq;
			env.set(0.5::ms,(2*pVal)::ms,0.,pVal::ms);
			if(pVal>0) {
				mEnv.keyOn();
				env.keyOn();
			}
		}
		if(pName == "dope") {
			pVal*36 => buf.pos;
			if(pVal>0)
				dEnv.keyOn();
		}
		
	}
	
	// step forward in the sequence and modulo by sequence length
	(stepCount+1) % seq.getSequenceLength() => stepCount;
	
	stepTime => now;
	
}

