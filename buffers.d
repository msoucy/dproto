/**
 * @file buffers.d
 * @brief Holds the Buffer types used in created classes
 * @author Matthew Soucy <msoucy@csh.rit.edu>
 * @date Mar 19, 2013
 * @version 0.0.1
 */
/// Protocol buffer structs
module metus.dproto.buffers;

//import std.conv;
import std.algorithm;
import std.array;
import std.exception;
import std.stdio;

import metus.dproto.serialize;
import metus.dproto.exception;

// TODO: Support enums

struct OptionalBuffer(ulong id, string TypeString, RealType, bool isDeprecated=false) {
	private {
		alias BufferType = TypeString;
		alias ValueType = RealType;

		bool isset=false;
		ValueType raw;
	}


	bool exists() const @property {
		return isset;
	}
	void clean() @property {
		isset = false;
		raw = ValueType.init;
	}

	this(ValueType val = ValueType.init) {
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

	ubyte[] serialize() {
		static if(IsBuiltinType(BufferType)) {
			return (MsgType!BufferType | (id << 3)).toVarint() ~ raw.writeProto!BufferType();
		} else {
			auto tmp = raw.serialize();
			return (MsgType!BufferType | (id << 3)).toVarint() ~ tmp.length.toVarint() ~ tmp;
		}
	}
	void deserialize(long msgdata, ref ubyte[] data) {
		enforce(msgdata.msgNum() == id, new DProtoException("Incorrect message number"));
		enforce(msgdata.wireType() == MsgType!BufferType, new DProtoException("Type mismatch"));
		static if(IsBuiltinType(BufferType)) {
			raw = data.readProto!BufferType(); // Changes data by ref
		} else {
			auto length = data.readProto!"int32"();
			auto myData = data[0 .. length];
			data = data[length .. $];
			raw = RealType(myData);
		}
	}

}

struct RequiredBuffer(ulong id, string TypeString, RealType, bool isDeprecated=false) {
	private {
		alias BufferType = TypeString;
		alias ValueType = RealType;

		ValueType raw;
	}

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


	ubyte[] serialize() {
		static if(IsBuiltinType(BufferType)) {
			return (MsgType!BufferType | (id << 3)).toVarint() ~ raw.writeProto!BufferType();
		} else {
			auto tmp = raw.serialize();
			return (MsgType!BufferType | (id << 3)).toVarint() ~ tmp.length.toVarint() ~ tmp;
		}
	}
	void deserialize(long msgdata, ref ubyte[] data) {
		enforce(msgdata.msgNum() == id, new DProtoException("Incorrect message number"));
		enforce(msgdata.wireType() == MsgType!BufferType, new DProtoException("Type mismatch"));
		static if(IsBuiltinType(BufferType)) {
			raw = data.readProto!BufferType(); // Changes data by ref
		} else {
			auto length = data.readProto!"int32"();
			auto myData = data[0 .. length];
			data = data[length .. $];
			raw = RealType(myData);
		}
	}

}

struct RepeatedBuffer(ulong id, string TypeString, RealType, bool isDeprecated=false, bool packed=false) {
	private {
		alias BufferType = TypeString;
		alias ValueType = RealType;

		ValueType[] raw = [];
	}

	void clean() @property {
		raw.length = 0;
	}

	this(ValueType[] val ...) {
		raw = val;
	}

	static if(isDeprecated) {
		deprecated auto opAssign(ValueType[] val ...) {
			raw = val;
		}
		deprecated ref ValueType[] opGet() @property {
			return raw;
		}
	} else {
		auto opAssign(ValueType[] val ...) {
			raw = val;
		}
		ref ValueType[] opGet() @property {
			return raw;
		}
	}
	alias opGet this;

	ubyte[] serialize() {
		// @TODO: Support nested repeated types
		static if(packed) {
			return (2 | (id << 3)).toVarint() ~ raw.length.toZigZag().toVarint() ~ raw.map!(a=>a.writeProto!BufferType())().joiner().array();
		} else {
			return raw.map!(a=>(MsgType!BufferType | (id << 3)).toVarint() ~ a.writeProto!BufferType())().joiner().array();
		}
	}
	void deserialize(long msgdata, ref ubyte[] data) {
		// @TODO: Support nested repeated types
		enforce(msgdata.msgNum() == id, new DProtoException("Incorrect message number"));
		if(packed && msgdata.wireType() == 2) {
			auto length = data.readProto!"int32"();
			auto myData = data[0 .. length];
			data = data[length .. $];
			while(myData.length) {
				raw ~= myData.readProto!BufferType();
			}
		} else {
			enforce(msgdata.wireType() == MsgType!BufferType, new DProtoException("Type mismatch"));
			raw ~= data.readProto!BufferType(); // Changes data by ref
		}
	}

}
