/*******************************************************************************
 * Exceptions used by the D protocol buffer system
 *
 * Authors: Matthew Soucy, dproto@msoucy.me
 */
module dproto.exception;
import std.exception : basicExceptionCtors;

/// Basic exception, something went wrong with creating a buffer struct
class DProtoException : Exception {
	///
	mixin basicExceptionCtors;
}

/// Proto file attempted to use a reserved word
class DProtoReservedWordException : DProtoException {
	///
	mixin basicExceptionCtors;
}

/// Proto file used invalid syntax
class DProtoSyntaxException : DProtoException {
	mixin basicExceptionCtors;
}
