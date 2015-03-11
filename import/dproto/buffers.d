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

	/***************************************************************************
	 * Serialize the buffer
	 *
	 * Returns: The proto-encoded data, or an empty array if the buffer is not set
	 */
	ubyte[] serialize() {
		auto a = appender!(ubyte[]);
		serializeTo(a);
		return a.data;
	}
	void serializeTo(R)(ref R r)
		if(isOutputRange!(R, ubyte))
	{
		if(isset) {
			toVarint(r, MsgType!BufferType | (id << 3));
			static if(IsBuiltinType(BufferType)) {
				r.writeProto!BufferType(raw);
			} else {
				CntRange cnt;
				raw.serializeTo(cnt);
				toVarint(r, cnt.cnt);
				raw.serializeTo(r);
			}
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
	void deserialize(R)(long msgdata, ref R data)
		if(isInputRange!R && is(ElementType!R : const ubyte))
	{
		enforce(msgdata.msgNum() == id,
				new DProtoException("Incorrect message number"));
		enforce(msgdata.wireType() == MsgType!BufferType,
				new DProtoException("Type mismatch"));
		static if(IsBuiltinType(BufferType)) {
			raw = data.readProto!BufferType().to!RealType();
		} else {
			auto myData = data.readProto!"bytes"();
			raw.deserialize(myData);
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
		deprecated ref inout(ValueType) opGet() @property inout {
			return raw;
		}
	} else {
		ref inout(ValueType) opGet() @property inout {
			return raw;
		}
	}
	alias opGet this;


	/***************************************************************************
	 * Serialize the buffer
	 *
	 * Returns: The proto-encoded data
	 */
	ubyte[] serialize() {
		auto a = appender!(ubyte[]);
		serializeTo(a);
		return a.data;
	}
	void serializeTo(R)(ref R r)
		if(isOutputRange!(R, ubyte))
	{
		toVarint(r, MsgType!BufferType | (id << 3));
		static if(IsBuiltinType(BufferType)) {
			r.writeProto!BufferType(raw);
		} else {
			CntRange cnt;
			raw.serializeTo(cnt);
			toVarint(r, cnt.cnt);
			raw.serializeTo(r);
		}
	}
	/***************************************************************************
	 * Deserialize data into a buffer
	 *
	 * Params:
	 *  	msgdata = The message's ID and type
	 *  	data    = The data to decode
	 */
	void deserialize(R)(long msgdata, ref R data)
		if(isInputRange!R && is(ElementType!R : const ubyte))
	{
		enforce(msgdata.msgNum() == id,
				new DProtoException("Incorrect message number"));
		enforce(msgdata.wireType() == MsgType!BufferType,
				new DProtoException("Type mismatch"));
		static if(IsBuiltinType(BufferType)) {
			raw = data.readProto!BufferType().to!RealType();
		} else {
			auto myData = data.readProto!"bytes"();
			raw.deserialize(myData);
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

	/***************************************************************************
	 * Serialize the buffer
	 *
	 * If the buffer is marked as packed and the type is primitive,
	 * then it will attempt to pack the data.
	 *
	 * Returns: The proto-encoded data
	 */
	ubyte[] serialize() {
		auto a = appender!(ubyte[]);
		serializeTo(a);
		return a.data;
	}
	void serializeTo(R)(ref R r)
		if(isOutputRange!(R, ubyte))
	{
		static if(packed) {
			static assert(IsBuiltinType(BufferType),
					"Cannot have packed repeated message member");
			if(raw.length) {
				CntRange cnt;
				foreach (ref e; raw)
					cnt.writeProto!BufferType(e);
				toVarint(r, PACKED_MSG_TYPE | (id << 3));
				toVarint(r, cnt.cnt);
				foreach (ref e; raw)
					r.writeProto!BufferType(e);
			}
		} else {
			foreach(val; raw) {
				toVarint(r, MsgType!BufferType | (id << 3));
				static if(IsBuiltinType(BufferType)) {
					r.writeProto!BufferType(val);
				} else {
					CntRange cnt;
					val.serializeTo(cnt);
					toVarint(r, cnt.cnt);
					val.serializeTo(r);
				}
			}
		}
	}
	/***************************************************************************
	 * Deserialize data into a buffer
	 *
	 * Received data is appended to the array.
	 *
	 * Params:
	 *  	msgdata = The message's ID and type
	 *  	data    = The data to decode
	 */
	void deserialize(R)(long msgdata, ref R data)
		if(isInputRange!R && is(ElementType!R : const ubyte))
	{
		enforce(msgdata.msgNum() == id,
				new DProtoException("Incorrect message number"));
		static if(IsBuiltinType(BufferType)) {
			if(msgdata.wireType == PACKED_MSG_TYPE && MsgType!BufferType != 2) {
				auto myData = data.readProto!"bytes"();
				while(myData.length) {
					raw ~= myData.readProto!BufferType().to!RealType();
				}
			} else {
				raw ~= data.readProto!BufferType().to!RealType();
			}
		} else {
			enforce(msgdata.wireType == MsgType!BufferType,
					new DProtoException("Cannot have packed repeated message member"));
			raw ~= ValueType(data.readProto!"bytes"());
		}
	}

}

private struct CntRange
{
@nogc:
	size_t cnt;
	void put(in ubyte) { ++cnt; }
	void put(in ubyte[] ary) { cnt += ary.length; }
	alias cnt this;
}
