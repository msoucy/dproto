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
import std.exception;

import metus.dproto.serialize;
import metus.dproto.exception;

struct OptionalBuffer(ulong id, string T) {
	private {
		alias BufferType = T;
		alias ValueType = BuffType!T;

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
	auto opAssign(ValueType val) {
		isset = true;
		raw = val;
		return this;
	}
	ref ValueType opGet() @property {
		return raw;
	}

	alias opGet this;
	ubyte[] opCast(T:ubyte[])() {
		return serialize();
	}

	ubyte[] serialize() {
		return (MsgType!T | (id << 3)).toVarint() ~ raw.writeProto!T();
	}
	void deserialize(long msgdata, ref ubyte[] data) {
		enforce(msgdata.msgNum() == id, new DProtoException("Incorrect message number"));
		enforce(msgdata.wireType() == MsgType!BufferType, new DProtoException("Type mismatch"));
		raw = data.readProto!BufferType(); // Changes data by ref
	}

}

struct RequiredBuffer(ulong id, string T) {
	private {
		alias BufferType = T;
		alias ValueType = BuffType!T;

		ValueType raw;
	}

	this(ValueType val) {
		raw = val;
	}

	ref ValueType opGet() @property {
		return raw;
	}

	alias opGet this;
	ubyte[] opCast(T:ubyte[])() {
		return serialize();
	}

	ubyte[] serialize() {
		return (MsgType!T | (id << 3)).toVarint() ~ raw.writeProto!T();
	}
	void deserialize(long msgdata, ref ubyte[] data) {
		enforce(msgdata.msgNum() == id, new DProtoException("Incorrect message number"));
		enforce(msgdata.wireType() == MsgType!BufferType, new DProtoException("Type mismatch"));
		raw = data.readProto!BufferType(); // Changes data by ref
	}

}

struct RepeatedBuffer(ulong id, string T) {
	private {
		alias BufferType = T;
		alias ValueType = BuffType!T;

		ValueType[] raw = [];
	}

	void clean() @property {
		raw.length = 0;
	}

	this(ValueType[] val ...) {
		raw = val;
	}
	auto opAssign(ValueType[] val ...) {
		raw = val;
	}

	ref ValueType[] opGet() @property {
		return raw;
	}

	alias opGet this;
	ubyte[] opCast(T:ubyte[])() {
		return serialize();
	}

	ubyte[] serialize() {
		return (MsgType!T | (id << 3)).toVarint() ~ raw.writeProto!T();
	}
	void deserialize(long msgdata, ref ubyte[] data) {
		enforce(msgdata.msgNum() == id, new DProtoException("Incorrect message number"));
		enforce(msgdata.wireType() == MsgType!BufferType, new DProtoException("Type mismatch"));
		raw ~= data.readProto!BufferType(); // Changes data by ref
	}

}
