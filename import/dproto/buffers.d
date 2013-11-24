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
import std.conv;
import std.exception;
import std.json;

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
		deprecated ref ValueType opGet() @property {
			return raw;
		}
	} else {
		auto opAssign(ValueType val) {
			isset = true;
			raw = val;
			return this;
		}
		ref ValueType opGet() @property {
			return raw;
		}
	}
	alias opGet this;

    /***************************************************************************
     * Serialize the buffer
     *
     * Returns: The json-encoded data, or an null JSONValue if the object is not set
     */
    JSONValue serializeToJson() {
        if (isset)
        {
            static if (IsBuiltinType(BufferType))
            {
                return raw.writeJSON!BufferType();
            }
            else
            {
                return raw.serializeToJson();
            }
        }
        else
        {
            JSONValue ret;
            ret.type = JSON_TYPE.NULL;
            return ret;
        }
    }

	/***************************************************************************
	 * Serialize the buffer
	 *
	 * Returns: The proto-encoded data, or an empty array if the buffer is not set
	 */
	ubyte[] serialize() {
		if(isset) {
			static if(IsBuiltinType(BufferType)) {
				return (MsgType!BufferType | (id << 3)).toVarint() ~ raw.writeProto!BufferType();
			} else {
				auto tmp = raw.serialize();
				return (MsgType!BufferType | (id << 3)).toVarint() ~ tmp.length.toVarint() ~ tmp;
			}
		} else {
			return [];
		}
	}
	/***************************************************************************
	 * Deserialize data into a buffer
	 *
	 * This marks the buffer as being set.
	 *
	 * Params:
	 * 		msgdata	=	The message's ID and type
	 * 		data	=	The data to decode
	 */
	void deserialize(long msgdata, ref ubyte[] data) {
		enforce(msgdata.msgNum() == id, new DProtoException("Incorrect message number"));
		enforce(msgdata.wireType() == MsgType!BufferType, new DProtoException("Type mismatch"));
		static if(IsBuiltinType(BufferType)) {
			raw = data.readProto!BufferType().to!RealType(); // Changes data by ref
		} else {
			raw.deserialize(data.readProto!"bytes"());
		}
		isset = true;
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
		deprecated ref ValueType opGet() @property {
			return raw;
		}
	} else {
		ref ValueType opGet() @property {
			return raw;
		}
	}
	alias opGet this;

    /***************************************************************************
     * Serialize the buffer
     *
     * Returns: The json-encoded data, or an null JSONValue if the object is not set
     */
    JSONValue serializeToJson() 
    {
        static if(IsBuiltinType(BufferType))
        {
            return raw.writeJSON!BufferType();
        }
        else
        {
            return raw.serializeToJson();
        }
    }

	/***************************************************************************
	 * Serialize the buffer
	 *
	 * Returns: The proto-encoded data
	 */
	ubyte[] serialize() {
		static if(IsBuiltinType(BufferType)) {
			return (MsgType!BufferType | (id << 3)).toVarint() ~ raw.writeProto!BufferType();
		} else {
			auto tmp = raw.serialize();
			return (MsgType!BufferType | (id << 3)).toVarint() ~ tmp.length.toVarint() ~ tmp;
		}
	}
	/***************************************************************************
	 * Deserialize data into a buffer
	 *
	 * Params:
	 *  	msgdata = The message's ID and type
	 *  	data    = The data to decode
	 */
	void deserialize(long msgdata, ref ubyte[] data) {
		enforce(msgdata.msgNum() == id, new DProtoException("Incorrect message number"));
		enforce(msgdata.wireType() == MsgType!BufferType, new DProtoException("Type mismatch"));
		static if(IsBuiltinType(BufferType)) {
			raw = data.readProto!BufferType().to!RealType(); // Changes data by ref
		} else {
			raw.deserialize(data.readProto!"bytes"());
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

		ValueType[] raw = [];
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
	this(ValueType[] val ...) {
		raw = val;
	}

	static if(isDeprecated) {
		deprecated auto opAssign(ValueType[] val) {
			raw = val;
			return this;
		}
		deprecated ref ValueType[] opGet() @property {
			return raw;
		}
	} else {
		auto opAssign(ValueType[] val) {
			raw = val;
			return this;
		}
		ref ValueType[] opGet() @property {
			return raw;
		}
	}
	alias opGet this;

    /***************************************************************************
     * Serialize the buffer
     *
     * Returns: The json-encoded data, or an null JSONValue if the object is not set
     */
    JSONValue serializeToJson() 
    {
        static if (IsBuiltinType(BufferType))
        {
            JSONValue ret;
            ret.type = JSON_TYPE.ARRAY;
            foreach(value; raw)
                ret.array ~= value.writeJSON!BufferType();
            return ret;
        }
        else
        {
            JSONValue ret;
            ret.type = JSON_TYPE.ARRAY;
            foreach(value; raw)
                ret.array ~= value.serializeToJson();
            return ret;
        }
    }

        
	/***************************************************************************
	 * Serialize the buffer
	 *
	 * If the buffer is marked as packed and the type is primitive,
	 * then it will attempt to pack the data.
	 *
	 * Returns: The proto-encoded data
	 */
	ubyte[] serialize() {
		static if(packed) {
			static if(IsBuiltinType(BufferType)) {
				auto msg = raw.map!(writeProto!BufferType)().join();
				return (PACKED_MSG_TYPE | (id << 3)).toVarint() ~ msg.length.toVarint() ~ msg;
			} else {
				static assert(0, "Cannot have packed repeated message member");
			}
		} else {
			static if(IsBuiltinType(BufferType)) {
				return raw.map!(a=>(MsgType!BufferType | (id << 3)).toVarint() ~ a.writeProto!BufferType())().join();
			} else {
				return raw.map!((RealType a) {
					auto msg = a.serialize();
					return (MsgType!BufferType | (id << 3)).toVarint() ~ msg.length.toVarint() ~ msg;
				})().join();
			}
		}
	}
	/***************************************************************************
	 * Deserialize data into a buffer
	 *
	 * Received data is appended to the array.
	 *
	 * If the buffer is marked as packed, then it will attempt to parse the data
	 * as a packed buffer. Otherwise, it unpacks an individual element.
	 *
	 * Params:
	 *  	msgdata = The message's ID and type
	 *  	data    = The data to decode
	 */
	void deserialize(long msgdata, ref ubyte[] data) {
		enforce(msgdata.msgNum() == id, new DProtoException("Incorrect message number"));
		static if(packed) {
			enforce(msgdata.wireType() == PACKED_MSG_TYPE, new DProtoException("Type mismatch"));
			static if(IsBuiltinType(BufferType)) {
				auto myData = data.readProto!"bytes"();
				while(myData.length) {
					raw ~= myData.readProto!BufferType().to!RealType();
				}
			} else {
				static assert(0, "Cannot have packed repeated message member");
			}
		} else {
			enforce(msgdata.wireType() == MsgType!BufferType, new DProtoException("Type mismatch"));
			static if(IsBuiltinType(BufferType)) {
				raw ~= data.readProto!BufferType().to!RealType(); // Changes data by ref
			} else {
				raw ~= ValueType(data.readProto!"bytes"());
			}
		}
	}

}
