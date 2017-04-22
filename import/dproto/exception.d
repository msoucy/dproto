/*******************************************************************************
 * Exceptions used by the D protocol buffer system
 *
 * Authors: Matthew Soucy, dproto@msoucy.me
 */
module dproto.exception;
import std.exception;

/// Basic exception, something went wrong with creating a buffer struct
class DProtoException : Exception {
	this(string msg, string file=__FILE__, size_t line=__LINE__, Throwable next=null) {
		super(msg, file, line, next);
	}
}

/// Proto file attempted to use a reserved word
class DProtoReservedWordException : DProtoException {
	this(string word, string file=__FILE__, size_t line=__LINE__, Throwable next=null) {
		super("Reserved word: "~word, file, line, next);
		keyword = word;
	}
	string keyword;
}

/// Proto file used invalid syntax
class DProtoSyntaxException : DProtoException {
	this(string msg, string file=__FILE__, size_t line=__LINE__, Throwable next=null) {
		super(msg, file, line, next);
	}
}
