# SequenceFile
```
be00 0000 0800 5045 5453 1e00 5604 006e
6f74 651f 5604 0067 6169 6e00 5604 0074
7269 6764 5045 5453 0600 5045 5453 1600
5604 006e 6f74 6516 5604 0067 6169 6e0c
5045 5453 2600 5604 006e 6f74 650e 5604
0067 6169 6e04 5604 0074 7269 67ff 5604
0064 6f70 65ff ...
```

## Inroduction
SequnceFile is a class for making sequencers that have a list of steps with parameters that are arbitrarily designated for each step. I wanted to create a sequencer where a parameter didn't need to be determined for each step of the sequence. In other words, I didn't want to use a 2D array. I decided to create something like a JSON syntax combined with inspiration from a network packet's data structure. The sequence file is a blob of bytes that is writen and read using the ```FileIO``` class.

 

## Example Usage
SequenceFile.ck defines a public class for creating, editing, recalling and reading a file that stores a sequence of parameter values. 

```
// instantiate class
SequenceFile seq;

// select a location to load and save sequence files
seq.setDirectory(me.dir()+"sequences");

// this creates a new sequence file with 8 steps
seq.createNewFile("example1", 8);
```

For each step you can set the value of an existing parameter or create a new paramter and value. Just give a parameter name as a string and the parameter value as an 8bit integer (0-255)
```
// this gives step 1 (ie 0) a "note" parameter value of 31  
seq.setParam(0,"note",31);
```
SequenceFile has an array called ```paramValues``` that is associatively indexed with the names of parameters. This array is updated whenever ```paramDump``` method is called.
```
// paramDmup returns an array of all the param names of the step
seq.paramDump(stepNumber) @=> string names[];
for(int p; p<names.size(); p++) {
  // paramValues contains the param value associated with the param names
  seq.paramValues[names[p]] => int paramVal;
}
```
