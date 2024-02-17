
/*

SequenceFile is an interface for reading and writing to a file 
for the purpose of storing and recalling parameter data for sequences of steps

files have a variable number of steps in them
steps have a variable number of parameters in them
the paramaeters have a name and a value
the parameters name is an ASCII string and the value is a 1 byte int

the file structures the data in bytes in the following way:

header structure:
- total num bytes in file (4 bytes : 4294967295 bytes max [plenty])
- total num steps in sequence (2 byte : 65535 steps max)
* from this point the number of bytes in the file is variable 

step structure, this structure is variable length and repeats for each step:
- step beginning (4 bytes : 0x53544550[constant] aka STEP in ascii. this helps check that steps are the size they say they are, by providing a consistent anchor at the begining of each one)
- step size (2 bytes : the number of bytes for the step, including the step size, beginning and number of bytes in parameters) 
[ if step size is 0x6 that means their is no param data in the step, there should never be less than 6 ]
* from this point the number of bytes in the step is variable

parameter structure, this structure is variable length and repeats for each parameter in each step:
[ param size is not givin explicitly, but it is param name size + 4 ]
- param beginning (1 byte : 0x56[constant] aka V in ascii )
- param name size (2 bytes : the number of bytes in the param name, i.e. the number of ASCII characters)
[ if param name size is equal to 0 the param is invalid and should be ignored. the param size should be 4 in this case ]
* from this point the number of bytes in the parameter is variable

- param name (X bytes : string in ASCII)
- param value (1 byte : the value of the parameter, 0-255 int)

*/

public class SequenceFile {
	
	string sequenceDir;
	FileIO sequenceFile;
	6 => int fileHeadSize; // (4bytes of total size, 2bytes of num steps)
	
	fun void setDirectory(string path) {
		path+"/" => sequenceDir;
	}
	
	fun int loadSequence(string name) {
		sequenceFile.open( sequenceDir+name, FileIO.READ_WRITE | FileIO.BINARY );
		if(sequenceFile.size() < 1) {
			if(sequenceFile.isDir()) {
				<<< "you loaded a directory!" >>>;
				return 0;
			} else {
				<<< "you loaded an empty file!" >>>;
				return 0;
			}
		} else {
			return 1;
		}
	}
	
	fun int saveFileAs(string newName) {
		FileIO newFile;
		newFile.open( sequenceDir+newName, FileIO.READ_WRITE | FileIO.BINARY );
		if(newFile.size() > 0) {
			<<< "new file already exists!" >>>;
			return 0;
		} else {
			readAll(sequenceFile,0) => string oldFile;
			newFile.write(oldFile);
			return 1;
		}
	}
	
	fun int createNewFile(string newName, int numSteps) {
		sequenceFile.open( sequenceDir+newName, FileIO.READ_WRITE | FileIO.BINARY );
		if(sequenceFile.size() > 0) {
			<<< "new file already exists!" >>>;
			return 0;
		} else {
			initSequence( numSteps );
			return 1;
		}
	}
	
	//=======================================================
	//       FILE HEADER READING
	//=======================================================
	
	fun int getTotalFileSize() {
		sequenceFile.seek(0);
		return sequenceFile.readInt( FileIO.INT32 );
	}
	
	fun int getSequenceLength() {
		sequenceFile.seek(4);
		return sequenceFile.readInt( FileIO.INT16 );
	}
	
	//=======================================================
	//       STEP EDITING
	//=======================================================
	
	0x53544550 => int stepHeadID;
	6 => int stepHeaderSize; // (4bytes of header ID, 2bytes of size)
	
	0 => int lastStep;
	fileHeadSize => int lastStepHeadPos;
	
	fun void initSequence(int numSteps) {
		if(numSteps > 256) {
			<<< "too many steps..." >>>;
			return;
		}
		// create header for file
		sequenceFile.seek(0);
		sequenceFile.write( fileHeadSize, FileIO.INT32 ); // write fileHeadSize as the total size of file
		sequenceFile.write( 0, FileIO.INT16 ); // write no steps (yet..)
		
		for(int s; s<numSteps; s++) {
			addStep(s);
		}
	}
	
	fun int checkStepHeader(int pos) {
		sequenceFile.seek(pos);
		sequenceFile.readInt(FileIO.SINT32) => int check;
		sequenceFile.seek(pos);
		if(check == stepHeadID) {
			return 1;
		}
		return 0;
	}
	
	fun void seekToStep(int stepNum) {
		
		if(lastStep > stepNum) {
			0 => lastStep; // go to first step
			fileHeadSize => lastStepHeadPos; // go to head pos of first step
			sequenceFile.seek(lastStepHeadPos);
		} 
		
		if(lastStep == stepNum) {
			if(checkStepHeader(lastStepHeadPos)) {
				sequenceFile.seek(lastStepHeadPos);
			} else {
				0 => lastStep; // go to first step
				fileHeadSize => lastStepHeadPos; // go to head pos of first step
			}
		}
		
		// while less than walk towards the seeked step
		while(lastStep < stepNum) {
			if(checkStepHeader(lastStepHeadPos)) {
				// at head of lastStep
				sequenceFile.seek(lastStepHeadPos+4);
				sequenceFile.readInt(FileIO.INT16) => int stepSize; // get size
				lastStepHeadPos+stepSize => lastStepHeadPos; // get head of next step
				sequenceFile.seek(lastStepHeadPos); // seek to head of next step
				1 +=> lastStep;
				
			} else {
				// assuming somewhere inside of lastStep
				// search for next step head
				true => int searchingForHead;
				lastStepHeadPos+1 => int searchPos;
				while(searchingForHead) {
					if(checkStepHeader(searchPos)) {
						false => searchingForHead;
					} else {
						1 +=> searchPos;
					}
				}
				searchPos => lastStepHeadPos;
				1 +=> lastStep;
			}
		}
	}
	
	fun void addStep(int insPos) {
		// add a new empty step at an insert position in the sequence
		if(insPos >= getSequenceLength()) {
			insertInt32(sequenceFile, getTotalFileSize(), stepHeadID); // insert step header
			insertInt16(sequenceFile, getTotalFileSize(), stepHeaderSize); // insert step size
			addToInt8(sequenceFile, 4, 1); // add to sequence length
		} else {
			seekToStep(insPos); // move sequenceFile read/write pos to the beginning of a step
			insertInt32(sequenceFile, lastStepHeadPos, stepHeadID); // insert step header
			insertInt16(sequenceFile, lastStepHeadPos+4, stepHeaderSize); // insert step size
			addToInt8(sequenceFile, 4, 1); // add to sequence length
		}
	}
	
	fun void clearStep(int stepNum) {
		// remove all parameter data from a step
		if(stepNum < getSequenceLength()) {
			if(stepNum == getSequenceLength()-1) {
				seekToStep(stepNum);
				// copy the currnet step size
				sequenceFile.seek(lastStepHeadPos+4);
				sequenceFile.readInt(FileIO.INT16) => int currentStepSize;
				// take the difference of the step size and the step header size
				currentStepSize - stepHeaderSize => int numBytesToSubtract;
				// set step size to header only
				sequenceFile.seek(lastStepHeadPos+4);
				sequenceFile.write(0x6, FileIO.INT16);
			} else {
				seekToStep(stepNum);
				// copy the currnet step size
				sequenceFile.seek(lastStepHeadPos+4);
				sequenceFile.readInt(FileIO.INT16) => int currentStepSize;
				// take the difference of the step size and the step header size
				currentStepSize - stepHeaderSize => int numBytesToSubtract;
				// remove() from the end of step header to the end of step size
				remove(sequenceFile, lastStepHeadPos+stepHeaderSize, lastStepHeadPos+currentStepSize);
				// set step size to header only
				sequenceFile.seek(lastStepHeadPos+4);
				sequenceFile.write(0x6, FileIO.INT16);
			}
		} else {
			<<< "Trying to clear step that doesnt exist!" >>>;
		}
	}
	
	fun void removeStep(int stepNum) {
		// remove the step, shortening the sequence
		if(stepNum < getSequenceLength()) {
			if(stepNum == getSequenceLength()-1) {
				seekToStep(stepNum);
				// copy the currnet step size
				sequenceFile.seek(lastStepHeadPos+4);
				sequenceFile.readInt(FileIO.INT16) => int currentStepSize;
				// subtract 1 from the sequence length
				getSequenceLength() - 1 => int newSequenceLength;
				sequenceFile.seek(4);
				sequenceFile.write(newSequenceLength, FileIO.INT16);
			} else {
				seekToStep(stepNum);
				// copy the currnet step size
				sequenceFile.seek(lastStepHeadPos+4);
				sequenceFile.readInt(FileIO.INT16) => int currentStepSize;
				// remove() from the end of step header to the end of step size
				remove(sequenceFile, lastStepHeadPos, lastStepHeadPos+currentStepSize);
				// subtract 1 from the sequence length
				getSequenceLength() - 1 => int newSequenceLength;
				sequenceFile.seek(4);
				sequenceFile.write(newSequenceLength, FileIO.INT16);
			}
		} else {
			<<< "Trying to remove step that doesnt exist!" >>>;
		}
	}
	
	fun void copyStep(int copyStep, int replaceStep) {
		// copy the parameter data of a selected step and replace the parameter data of an existing step
	}
	
	fun void duplicateStep(int copyStep, int insPos) {
		// copy the parameter data of a selected step and addStep with the copied the parameter data
	}
	
	//=======================================================
	//       PARAMETER EDITING
	//=======================================================
	
	/*
	parameter structure, this structure is variable length and repeats for each parameter in each step:
	[ param size is know explicitly, but it is param name size + 4 ]
	- param beginning (1 byte : 0x56[constant] aka "V" in ascii )
	- param name size (2 bytes : the number of bytes in the param name, i.e. the number of ASCII characters of the param name)
	[ if param name size is equal to 0 the param is invalid and should be ignored. the param size should be 4 in this case ]
	* from this point the number of bytes in the parameter is variable
	
	- param name (X bytes : string in ASCII)
	- param value (1 byte : the value of the parameter, 0-255 int)
	*/
	
	0x56 => int paramHeadByte;
	3 => int paramHeaderSize;
	1 => int paramValueSize;
	
	0 => int lastParamHeadPos;
	0 => int lastParamNameSize;
	"" => string lastParamName;
	0 => int lastParamValue;
	
	fun int checkForParam(int stepNum, string paramName) {
		// this function checks if a param exist and returns 1 if it does
		// it also seeks to the head of the param if it exists aka lastParamHeadPos
		// if the param doesnt exist, it seeks to the end of the step where a param can be inserted aka lastParamHeadPos
		
		seekToStep(stepNum);
		sequenceFile.seek(lastStepHeadPos+4);
		sequenceFile.readInt(FileIO.INT16) => int stepSize;

		lastStepHeadPos+stepHeaderSize => lastParamHeadPos;
		0 => lastParamNameSize;
		"" => lastParamName;
		
		sequenceFile.seek(lastParamHeadPos);
		
		1 => int searchingParam;
		while(searchingParam) {
			
			if(sequenceFile.readInt(FileIO.INT8) != paramHeadByte) { // check if the next byte is not a valid byte of a param head 
				// if not valid, seek to "lastParamHeadPos" which is really just the end of the last param, and the head of the next step
				sequenceFile.seek(lastParamHeadPos);
				0 => searchingParam;
				return 0; 
			}
			
			sequenceFile.readInt(FileIO.INT16) => lastParamNameSize;
			sequenceFile.readLine().substring(0,lastParamNameSize) => lastParamName;
			sequenceFile.seek(lastParamHeadPos+paramHeaderSize+lastParamNameSize);
			sequenceFile.readInt(FileIO.INT8) => lastParamValue;
			// at this point sequenceFile.tell() should be at the end of the parameter
			
			if(lastParamName == paramName) { // check if the param read is the param you are seeking
				// if so seek back to param head
				sequenceFile.seek(lastParamHeadPos);
				0 => searchingParam;
				return 1;
			} else if(sequenceFile.tell() < lastStepHeadPos+stepSize) { // check if sequenceFile.tell() is within the step data
				// if so set sequenceFile.tell() as the next param head aka lastParamHeadPos in future reference;
				sequenceFile.tell() => lastParamHeadPos;
				
			} else { // if sequenceFile.tell() is at the end of the step, end the search
				lastStepHeadPos+stepSize => lastParamHeadPos;
				0 => searchingParam;
				return 0;
			}
		}
		return 0;
	}
	
	fun void setParam(int stepNum, string paramName, int paramVal) {
		if(paramVal > 255 || paramVal < 0) {
			<<<"Trying to set param out of range!">>>;
			return;
		}
		
		// this function either changes the value of an existing param if it exists for the step
		// or it adds the param to the step if it doesnt exist
		if(checkForParam(stepNum, paramName)) {
			//param exists
			sequenceFile.seek(lastParamHeadPos+paramHeaderSize+lastParamNameSize);
			sequenceFile.write(paramVal,FileIO.INT8);
		} else {
			//param doesn't exist
			insertInt8(sequenceFile, lastParamHeadPos, paramHeadByte); // insert param header
			insertInt16(sequenceFile, lastParamHeadPos+1, paramName.length()); // insert param name size
			insertString(sequenceFile, lastParamHeadPos+paramHeaderSize, paramName); // insert param name
			insertInt8(sequenceFile, lastParamHeadPos+paramHeaderSize+paramName.length(), paramVal); // insert param value
			paramHeaderSize+paramName.length()+1 => int paramSize;
			addToInt16(sequenceFile, lastStepHeadPos+4, paramSize); // add to step size
		}
	}
	
	fun int addToParam(int stepNum, string paramName, int addVal) {
		// this function either changes the value of an existing param if it exists for the step
		// or it adds the param to the step if it doesnt exist
		
		// this function also returns the value of the param
		if(checkForParam(stepNum, paramName)) {
			//param exists
			sequenceFile.seek(lastParamHeadPos+paramHeaderSize+lastParamNameSize);
			sequenceFile.readInt(FileIO.INT8) => int currentVal;
			sequenceFile.seek(lastParamHeadPos+paramHeaderSize+lastParamNameSize);
			currentVal+addVal => int newVal;
			if(newVal > 255) 255 => newVal;
			if(newVal < 0) 0 => newVal;
			sequenceFile.write(newVal,FileIO.INT8);
			return newVal;
		} else {
			//param doesn't exist
			insertInt8(sequenceFile, lastParamHeadPos, paramHeadByte); // insert param header
			insertInt16(sequenceFile, lastParamHeadPos+1, paramName.length()); // insert param name size
			insertString(sequenceFile, lastParamHeadPos+paramHeaderSize, paramName); // insert param name
			insertInt8(sequenceFile, lastParamHeadPos+paramHeaderSize+paramName.length(), addVal); // insert param value
			paramHeaderSize+paramName.length()+1 => int paramSize;
			addToInt16(sequenceFile, lastStepHeadPos+4, paramSize); // add to step size
			return addVal;
		}
	}
	
	fun void removeParam(int stepNum, string paramName) {
		// delete a parameter from a step
	}
	
	fun void copyParam(int targetStepNum, string targetParamName, int destinationStepNum) {
		// copy a parameter from a step and replace or add param to another step
	}
	
	fun void duplicateParam(int targetStepNum, string targetParamName, int destStepNum, string destParamName) {
		// copy a parameter from a step and add param to another step and give it to a new name
	}
	
	//=======================================================
	//       GET PARAMETERS
	//=======================================================
	
	0 => int lastStepParamCount;
	
	// x+++x+++x+++x+++x+++x+++x+++x+++x+++x+++x+++x+++x+++x+++x+++x+++
	// this is where the param values are stored, 
	// they are stored assosiatively e.g. paramValues["paramName"]
	// they are read whenever paramDump is called
	int paramValues[0]; 
	// x+++x+++x+++x+++x+++x+++x+++x+++x+++x+++x+++x+++x+++x+++x+++x+++
	
	fun int getParam(int stepNum, string paramName) {
		// this function either returns the value of an existing param if it exists for the step
		// or it returns -1 if it doesnt exist
		if(checkForParam(stepNum, paramName)) {
			//param exists
			sequenceFile.seek(lastParamHeadPos+paramHeaderSize+lastParamNameSize);
			return sequenceFile.readInt(FileIO.INT8);
		} else {
			return -1;
		}
	}
	
	fun void getStepParamCount(int stepNum) {
		seekToStep(stepNum);
		sequenceFile.seek(lastStepHeadPos+4);
		sequenceFile.readInt(FileIO.INT16) => int stepSize; // get size
		
		// count the number of params
		0 => int paramCount;
		while(sequenceFile.tell()<lastStepHeadPos+stepSize) {
			sequenceFile.readInt(FileIO.INT8) => int checkByte;
			if(checkByte != paramHeadByte) {
				return;
			}
			sequenceFile.readInt(FileIO.INT16) => int paramNameSize;
			sequenceFile.seek(sequenceFile.tell()+paramNameSize+1);
			1 +=> paramCount;
		}
		paramCount => lastStepParamCount;
	}
	
	fun string[] paramDump(int stepNum) {
		getStepParamCount(stepNum);
		
		lastStepHeadPos+stepHeaderSize => lastParamHeadPos;
		sequenceFile.seek(lastParamHeadPos);
		string outputParams[lastStepParamCount];
		
		for(int p; p<lastStepParamCount; p++) {
			sequenceFile.readInt(FileIO.INT8) => int checkByte;
			sequenceFile.readInt(FileIO.INT16) => lastParamNameSize;
			sequenceFile.readLine().substring(0,lastParamNameSize) => lastParamName;
			sequenceFile.seek(lastParamHeadPos+paramHeaderSize+lastParamNameSize);
			sequenceFile.readInt(FileIO.INT8) => int paramValue;
			sequenceFile.tell() => lastParamHeadPos;
			
			lastParamName => outputParams[p];
			paramValue => paramValues[lastParamName];
		}
		
		return outputParams;
	}
	
	//=======================================================
	//       FILE EDITING
	//=======================================================
	
	fun void addToInt8(FileIO f, int addPos, int addAmt) {
		f.seek(addPos);
		f.readInt(FileIO.INT8) => int val;
		addAmt +=> val;
		f.seek(addPos);
		f.write(val, FileIO.INT8);
	}
	
	fun void addToInt16(FileIO f, int addPos, int addAmt) {
		f.seek(addPos);
		f.readInt(FileIO.INT16) => int val;
		addAmt +=> val;
		f.seek(addPos);
		f.write(val, FileIO.INT16);
	}
	
	fun void addToInt32(FileIO f, int addPos, int addAmt) {
		f.seek(addPos);
		f.readInt(FileIO.INT32) => int val;
		addAmt +=> val;
		f.seek(addPos);
		f.write(val, FileIO.INT32);
	}
	
	fun string readAll(FileIO f, int fromPos) {
		f.seek(fromPos);
		"" => string out;
		while(f.more()) {
			// readLine will stop at a \n character, so we add a \n charater at the end 
			// so we dont lose that character where it is relevant (e.g. when this charater is an int value of 10)
			out+f.readLine()+"\n" => out; 
		}
		// the while looping to f.more() ends with f.tell() at -1, so f.seek(x) is necesary after this function
		getTotalFileSize() => int fileLen;
		if(out.length() > 0)
			out.substring(0, (fileLen-fromPos)) => out;
		return out;
	}
	
	// INSERT : this is how to insert new bytes between existing bytes, without overriding
	// ALWAYS INSERT THE BYTES FIRST THEN EDIT THE FILE SIZE! 
	
	fun void insertString(FileIO f, int insPos, string insData) {
		// insPos : the position of the byte to have data instered infront of
		// go to insert position
		// copy all bytes from there until the end, this moves the position
		readAll(f,insPos) => string str; 
		// move back to the insert position
		f.seek( insPos ); 
		// write the new data, overiding the existing data for the moment, this does not move the position
		f.write( insData ); 
		//f.seek( insPos+insData.length() ); 
		// rewrite the existing data at the end
		f.write( str ); 
		// add to total file size
		addToInt32(f, 0, insData.length()); 
	}
	
	fun void insertInt8(FileIO f, int insPos, int insData) {
		readAll(f,insPos) => string str; 
		f.seek( insPos ); 
		f.write( insData, FileIO.INT8 ); 
		f.write( str ); 
		// add to total file size
		addToInt32(f, 0, 1);
	}
	
	fun void insertInt16(FileIO f, int insPos, int insData) {
		readAll(f,insPos) => string str; 
		f.seek( insPos ); 
		f.write( insData, FileIO.INT16 ); 
		f.write( str ); 
		// add to total file size
		addToInt32(f, 0, 2);
	}
	
	fun void insertInt32(FileIO f, int insPos, int insData) {
		readAll(f,insPos) => string str; 
		f.seek( insPos ); 
		f.write( insData, FileIO.INT32 ); 
		f.write( str ); 
		// add to total file size
		addToInt32(f, 0, 4);
	}
	
	// REMOVE : this is how to remove bytes as if they were never existed
	// ALWAYS REMOVE THE BYTES FIRST THEN EDIT THE FILE SIZE! 
	
	fun void remove(FileIO f, int rmStart, int rmEnd) {
		// rmStart : the position of the first byte to be removed
		// rmEnd : the position of the byte after the last byte to be removed
		// move to the end of the remove
		// copy all bytes from there until the end, this moves the position
		readAll(f,rmEnd) => string str; 
		// move to the start of the remove
		f.seek( rmStart );
		// write the data that was copied, overiding the data that is removed
		f.write( str ); 
		// this methods may create junk or left over data at the end of the file
		// but it doesnt mater because the data thats relevant is counted in number of bytes
		// so the junk data, even if it exists, doesnt get read
		
		// add to total file size
		addToInt32(f, 0, -(rmEnd-rmStart));
	}
};




