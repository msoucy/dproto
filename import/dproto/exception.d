/*******************************************************************************
 * Exceptions used by the D protocol buffer system
 *
 * Authors: Matthew Soucy, dproto@msoucy.me
 */
module dproto.exception;
import std.exception;

/// Basic exception, something went wrong with creating a buffer struct
class DProtoException : Exception {
	static if (__traits(compiles, {mixin basicExceptionCtors;})) {
		///
		mixin basicExceptionCtors;
	} else {
		this(string msg, string file = __FILE__, size_t line = __LINE__,
			 Throwable next = null) @safe pure nothrow {
			super(msg, file, line, next);
		}

		this(string msg, Throwable next, string file = __FILE__,
			 size_t line = __LINE__) @safe pure nothrow {
			super(msg, file, line, next);
		}
	}
}

/// Proto file attempted to use a reserved word
class DProtoReservedWordException : DProtoException {
	static if (__traits(compiles, {mixin basicExceptionCtors;})) {
		///
		mixin basicExceptionCtors;
	} else {
		this(string msg, string file = __FILE__, size_t line = __LINE__,
			 Throwable next = null) @safe pure nothrow {
			super(msg, file, line, next);
		}

		this(string msg, Throwable next, string file = __FILE__,
			 size_t line = __LINE__) @safe pure nothrow {
			super(msg, file, line, next);
		}
	}
}

/// Proto file used invalid syntax
class DProtoSyntaxException : DProtoException {
	static if (__traits(compiles, {mixin basicExceptionCtors;})) {
		///
		mixin basicExceptionCtors;
	} else {
		this(string msg, string file = __FILE__, size_t line = __LINE__,
			 Throwable next = null) @safe pure nothrow {
			super(msg, file, line, next);
		}

		this(string msg, Throwable next, string file = __FILE__,
			 size_t line = __LINE__) @safe pure nothrow {
			super(msg, file, line, next);
		}
	}
}
