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

 

## Basic Usage
SequenceFile.ck defines a public class for creating, editing, recalling and reading a file that stores a sequence of parameter values. 

```ChucK
SequenceFile seq;

// select a location to load and save sequence files
seq.setDirectory(me.dir()+"sequences");

// this creates a new sequence file with 8 steps
seq.createNewFile("example1", 8);
```

For each step you can set the value of an existing parameter or create a new paramter and value. Just give a parameter name as a string and the parameter value as an 8bit integer (0-255)
```ChucK
// this gives step 1 (ie 0) a "note" parameter value of 31  
seq.setParam(0,"note",31);
```
SequenceFile has an array called ```paramValues``` that is associatively indexed with the names of parameters. This array is updated whenever ```paramDump``` method is called.
```ChucK
// paramDmup returns an array of all the param names of the step
seq.paramDump(stepNumber) @=> string names[];
for(int p; p<names.size(); p++) {
  // paramValues contains the param value associated with the param names
  seq.paramValues[names[p]] => int paramVal;
}
```

# Methods

## File Managing
``` void setDirectory(string path) ```  
Choose an absolute path to a directory that will be the location of loading and saving sequence files

``` int loadSequence(string name) ```  
Returns 1 if successfully loaded, 0 if not. The file name does not need an extention.

``` int saveFileAs(string newName) ```  
Returns 1 if successfully saved, 0 if not. After save as the loaded file is the new file. This function will prevent overriding existing files. The file name needs no extention.

``` int createNewFile(string newName, int numSteps) ```  
Returns 1 if successfully created, 0 if not. This function will prevent overriding existing files. If the file you tried to create already exists by name, that file will be loaded. The file name needs no extention.

### Sequence Editing
``` int getSequenceLength() ```  
Returns the number of steps in the sequence.  

``` void addStep(int insPos) ```  
Create a new step at any position in the sequence. 0 is before the first step and getSequenceLength() is after the last step (any number greater than that will put a step at the end of the sequence).  

``` void clearStep(int stepNum) ```  
Delete all parameter data from a step. 

``` void removeStep(int stepNum) ```  
Delete a step, shortening the sequence length. 

more step editing methods wip...

### Parameter Editing
``` int checkForParam(int stepNum, string paramName) ```  
Returns 1 if the parameter exists for the given step, 0 if not.

``` void setParam(int stepNum, string paramName, int paramVal) ```  
Set the value of an existing parameter in a step if it exists. If the parameter does not already exist it will create it and set the value. The value is always clamped to 0 - 255.

``` int addToParam(int stepNum, string paramName, int addVal) ```  
Returns the new value of the parameter. Add to the value of an existing parameter in a step if it exists. If the parameter does not already exist it will create it and set the value as the add value. The value after adding is always clamped to 0 - 255.

more param editing wip...

### Parameter Getting
``` int getParam(int stepNum, string paramName) ```  
Returns the parameter value of a given step and parameter. If it doesnt exist it returns -1.

``` int getStepParamCount(int stepNum) ```  
Returns the number of parameters of a given step.

``` string[] paramDump(int stepNum) ```  
Returns a string array of all the parameter names for a given step. This function also updates an internal array of parameter values for the given step. 

``` int[] pVals() ```  
Returns the array of parameter values for the step that was given in the last call of paramDump. This array is only associativly indexed, meaning it is indexed with the names of the parameters. If you try to check the size of this array it will always be 0 because it has no number indexes. 

### Other Methods 
There are other methods in SequenceFile but they all pretain to reading, writing and navigating the bytes of the file.  


# File Structure
Here is the definition of the SequenceFile file structure:
```

SequenceFile is an interface for reading and writing to a file 
for the purpose of storing and recalling parameter data for sequences of steps

files have a variable number of steps in them
steps have a variable number of parameters in them
the paramaeters have a name and a value
the parameters name is an ASCII string and the value is a 1 byte int

the file structures the data in bytes in the following way:

FILE HEADER STRUCTURE:
- total num bytes in file (INT32, 4 bytes : 4294967295 bytes max [plenty])
- total num steps in sequence (INT16, 2 byte : 65535 steps max)
* from this point the number of bytes in the file is variable 

STEP STRUCTURE, this structure is variable length and repeats for each step:
- step beginning (INT32, 4 bytes : 0x53544550[constant] aka STEP in ascii. this helps check that steps are the size they say they are, by providing a consistent anchor at the begining of each one)
- step size (INT16, 2 bytes : the number of bytes for the step, including the step size, beginning and number of bytes in parameters) 
[ if step size is 0x6 that means their is no param data in the step, there should never be less than 6 ]
* from this point the number of bytes in the step is variable

PARAMETER STRUCTURE, this structure is variable length and repeats for each parameter in the step:
[ param size is not givin explicitly, but it is param name size + 4 ]
- param beginning (INT8, 1 byte : 0x56[constant] aka V in ascii )
- param name size (INT16, 2 bytes : the number of bytes in the param name, i.e. the number of ASCII characters)
[ if param name size is equal to 0 the param is invalid and should be ignored. the param size should be 4 in this case ]
* from this point the number of bytes in the parameter is variable
- param name (X bytes : string in ASCII)
- param value (INT8, 1 byte : the value of the parameter, 0-255 int)

These structures can be listed in the following example order of a sequence file:

FILE HEADER STRUCTURE
STEP STRUCTURE
* if a step has no parameters, the next step in the sequence will be listed
STEP STRUCTURE
* if there are parameters in a step they are listed after the step they are a part of
PARAMETER STRUCTURE
* numerous parameters of a step are listed one after another in no particular order
PARAMETER STRUCTURE
PARAMETER STRUCTURE
PARAMETER STRUCTURE
* once the last parameter in a step is listed, the next step is listed
STEP STRUCTURE
PARAMETER STRUCTURE
PARAMETER STRUCTURE
STEP STRUCTURE
PARAMETER STRUCTURE
STEP STRUCTURE
STEP STRUCTURE
* thats the end of it

```

