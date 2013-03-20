/**
 * @file exception.d
 * @brief Exceptions used by the D protocol buffer system
 * @author Matthew Soucy <msoucy@csh.rit.edu>
 * @date Mar 5, 2013
 * @version 0.0.1
 */
/// D protocol buffer exceptions
module metus.dproto.exception;

class DProtoException : Exception {
	this(string msg, string file=__FILE__, int line=__LINE__) {
    	super(msg, file, line);
	}
}
