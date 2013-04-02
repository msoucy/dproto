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
import std.conv;
import std.exception;
import std.stdio;

import metus.dproto.serialize;
import metus.dproto.exception;

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
		} else static if(is(RealType == enum)) {
			return (MsgType!BufferType | (id << 3)).toVarint() ~ raw.writeProto!ENUM_SERIALIZATION();
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
		} else static if(is(RealType == enum)) {
			raw = data.readProto!ENUM_SERIALIZATION().to!RealType();
		} else {
			auto myData = data.readProto!"bytes"();
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
		} else static if(is(RealType == enum)) {
			return (MsgType!BufferType | (id << 3)).toVarint() ~ raw.writeProto!ENUM_SERIALIZATION();
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
		} else static if(is(RealType == enum)) {
			raw = data.readProto!ENUM_SERIALIZATION().to!RealType();
		} else {
			auto myData = data.readProto!"bytes"();
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
			return this;
		}
		deprecated ref ValueType[] opGet() @property {
			return raw;
		}
	} else {
		auto opAssign(ValueType[] val ...) {
			raw = val;
			return this;
		}
		ref ValueType[] opGet() @property {
			return raw;
		}
	}
	alias opGet this;

	ubyte[] serialize() {
		static if(packed) {
			static if(IsBuiltinType(BufferType)) {
				auto msg = raw.map!(writeProto!BufferType)().concat();
				return (PACKED_MSG_TYPE | (id << 3)).toVarint() ~ msg.length.toVarint() ~ msg;
			} else static if(is(RealType == enum)) {
				auto msg = raw.map!(writeProto!ENUM_SERIALIZATION)().concat();
				return (PACKED_MSG_TYPE | (id << 3)).toVarint() ~ msg.length.toVarint() ~ msg;
			} else {
				static assert(0, "Cannot have packed repeated message member");
			}
		} else {
			static if(IsBuiltinType(BufferType)) {
				return raw.map!(a=>(MsgType!BufferType | (id << 3)).toVarint() ~ a.writeProto!BufferType())().concat();
			} else static if(is(RealType == enum)) {
				return raw.map!(a=>(MsgType!BufferType | (id << 3)).toVarint() ~ a.writeProto!ENUM_SERIALIZATION())().concat();
			} else {
				return raw.map!((RealType a) {
					auto msg = a.serialize();
					return (MsgType!BufferType | (id << 3)).toVarint() ~ msg.length.toVarint() ~ msg;
				})().concat();
			}
		}
	}
	void deserialize(long msgdata, ref ubyte[] data) {
		enforce(msgdata.msgNum() == id, new DProtoException("Incorrect message number"));
		static if(packed) {
			enforce(msgdata.wireType() == PACKED_MSG_TYPE, new DProtoException("Type mismatch"));
			static if(IsBuiltinType(BufferType)) {
				auto myData = data.readProto!"bytes"();
				while(myData.length) {
					raw ~= myData.readProto!BufferType();
				}
			} else static if(is(RealType == enum)) {
				auto myData = data.readProto!"bytes"();
				while(myData.length) {
					raw ~= myData.readProto!ENUM_SERIALIZATION();
				}
			} else {
				static assert(0, "Cannot have packed repeated message member");
			}
		} else {
			enforce(msgdata.wireType() == MsgType!BufferType, new DProtoException("Type mismatch"));
			static if(IsBuiltinType(BufferType)) {
				raw ~= data.readProto!BufferType(); // Changes data by ref
			} else static if(is(RealType == enum)) {
				raw ~= data.readProto!ENUM_SERIALIZATION(); // Changes data by ref
			} else {
				auto myData = data.readProto!"bytes"(); // Changes data by ref
				raw.deserialize(myData);
			}
		}
	}

}
