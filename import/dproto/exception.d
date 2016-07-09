/*******************************************************************************
 * Exceptions used by the D protocol buffer system
 *
 * Authors: Matthew Soucy, msoucy@csh.rit.edu
 * Date: Oct 5, 2013
 * Version: 0.0.2
 */
module dproto.exception;

/*******************************************************************************
 * Basic exception, something went wrong with creating a buffer struct
 */
class DProtoException : Exception {
	this(string msg, string file=__FILE__, int line=__LINE__) {
		super(msg, file, line);
	}
}

class DProtoReservedWordException : DProtoException {
	this(string word, string file=__FILE__, int line=__LINE__) {
		super("Reserved word: "~word, file, line);
		keyword = word;
	}
	string keyword;
}
