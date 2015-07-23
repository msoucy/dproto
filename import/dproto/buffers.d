/*******************************************************************************
 * Holds the Buffer types used in created classes
 *
 * Authors: Matthew Soucy, msoucy@csh.rit.edu
 * Date: Oct 5, 2013
 * Version: 0.0.2
 */
module dproto.buffers;

import std.algorithm;
import std.array;
import std.range;
import std.conv;
import std.exception;

import dproto.serialize;
import dproto.exception;

/*******************************************************************************
 * Optional buffers can be optionally not sent/received.
 *
 * If this type is not set, then it does not send the default value.
 *
 * Params:
 *  	id           = The numeric ID for the message
 *  	TypeString   = The encoding type of the data
 *  	RealType     = The type the data is stored as internally
 *  	isDeprecated = Deprecates the accessors if true
 *  	defaultValue = The default value for the internal storage
 */
struct OptionalBuffer(ulong id, string TypeString, RealType, bool isDeprecated=false, alias defaultValue=RealType.init) {
	private {
		alias ValueType = RealType;
		static if(is(ValueType == enum)) {
			alias BufferType = ENUM_SERIALIZATION;
		} else {
			alias BufferType = TypeString;
		}

		bool isset=false;
		ValueType raw = defaultValue;
	}


	/***************************************************************************
	 * Test the existence of a value
	 */
	bool exists() const @property nothrow {
		return isset;
	}
	/***************************************************************************
	 * Clears the value, marks as not set
	 */
	void clean() nothrow {
		isset = false;
		raw = defaultValue;
	}

	/***************************************************************************
	 * Create a Buffer
	 *
	 * Params:
	 *  	val = The value to populate with
	 */
	this(ValueType val) {
		isset = true;
		raw = val;
	}

	static if(isDeprecated) {
		deprecated auto opAssign(ValueType val) {
			isset = true;
			raw = val;
			return this;
		}
		deprecated ref inout(ValueType) opGet() @property inout {
			return raw;
		}
	} else {
		auto opAssign(ValueType val) {
			isset = true;
			raw = val;
			return this;
		}
		ref inout(ValueType) opGet() @property inout {
			return raw;
		}
	}
	alias opGet this;

	/** serialize as JSON */
	import std.json : JSONValue;
	string toJson() {
		if(isset) {
			static if(isBuiltinType(BufferType)) {
				return JSONValue(raw).toString();
			} else {
				return raw.toJson();
			}
		} else {
			return "null";
		}
	}
}

/*******************************************************************************
 * Required buffers must be both sent and received
 *
 * Params:
 *  	id           = The numeric ID for the message
 *  	TypeString   = The encoding type of the data
 *  	RealType     = The type the data is stored as internally
 *  	isDeprecated = Deprecates the accessors if true
 */
struct RequiredBuffer(ulong id, string TypeString, RealType, bool isDeprecated=false) {
	private {
		alias ValueType = RealType;
		static if(is(ValueType == enum)) {
			alias BufferType = ENUM_SERIALIZATION;
		} else {
			alias BufferType = TypeString;
		}

		ValueType raw;
	}

	/***************************************************************************
	 * Create a Buffer
	 *
	 * Params:
	 *     val = The value to populate with
	 */
	this(ValueType val) {
		raw = val;
	}

	static if(isDeprecated) {
		deprecated ref inout(ValueType) opGet() @property inout {
			return raw;
		}
	} else {
		ref inout(ValueType) opGet() @property inout {
			return raw;
		}
	}
	alias opGet this;


	/** serialize as JSON */
	import std.json : JSONValue;
	string toJson() {
		static if(isBuiltinType(BufferType)) {
			return JSONValue(raw).toString();
		} else {
			return raw.toJson();
		}
	}
}

/*******************************************************************************
 * Repeated buffers can store multiple values
 *
 * They also support Packed data for primitives,
 * which is a more efficient encoding method.
 *
 * Params:
 *  	id           = The numeric ID for the message
 *  	TypeString   = The encoding type of the data
 *  	RealType     = The type the data is stored as internally
 *  	isDeprecated = Deprecates the accessors if true
 *  	packed       = The default value for the internal storage
 */
struct RepeatedBuffer(ulong id, string TypeString, RealType, bool isDeprecated=false, bool packed=false) {
	private {
		alias ValueType = RealType;
		static if(is(ValueType == enum)) {
			alias BufferType = ENUM_SERIALIZATION;
		} else {
			alias BufferType = TypeString;
		}

		ValueType[] raw;
	}

	/***************************************************************************
	 * Clears the stored values
	 */
	void clean() nothrow {
		raw.length = 0;
	}

	/***************************************************************************
	 * Create a Buffer
	 *
	 * Params:
	 *  	val = The value to populate with
	 */
	this(inout(ValueType)[] val ...) inout @safe {
		raw = val;
	}

	static if(isDeprecated) {
		deprecated auto opAssign(ValueType[] val) {
			raw = val;
			return this;
		}
		deprecated ref inout(ValueType[]) opGet() @property inout {
			return raw;
		}
	} else {
		auto opAssign(ValueType[] val) {
			raw = val;
			return this;
		}
		ref inout(ValueType[]) opGet() @property inout {
			return raw;
		}
	}
	alias opGet this;

	inout(RepeatedBuffer) save() @property inout
	{
		 return this;
	}

	inout(RepeatedBuffer) opSlice(size_t i, size_t j) @property inout
	{
		return inout(RepeatedBuffer)(raw[i .. j]);
	}

	size_t length() @property const
	{
		return raw.length;
	}

	/** serialize as JSON */
	string toJson() {
		string ret = "[";
		if(raw.length) {
			if(ret.length > 1) {
				ret ~= ",";
			}
			foreach(val; raw) {
				static if(isBuiltinType(BufferType)) {
					ret ~= std.json.JSONValue(val).toString();
				} else {
					ret ~= val.toJson();
				}
			}
		}
		ret ~= "]";
		return ret;
	}
}

struct CntRange
{
@nogc:
	size_t cnt;
	void put(in ubyte) { ++cnt; }
	void put(in ubyte[] ary) { cnt += ary.length; }
}
