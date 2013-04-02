/**
 * @file serialize.d
 * @brief Serialization/deserialization code
 * @author Matthew Soucy <msoucy@csh.rit.edu>
 * @date Mar 5, 2013
 * @version 0.0.1
 */
/// D protobuf serialization/deserialization
module metus.dproto.serialize;

import metus.dproto.exception;

import std.algorithm;
import std.bitmanip;
import std.conv;
import std.exception;
import std.range;
import std.stdio;
import std.system;

////////////////////////////////////////////////////////////////////////////////
// Utilities

bool IsBuiltinType(string T) {
	return ["int32" , "sint32", "int64", "sint64", "uint32", "uint64", "bool",
			"enum", "fixed64", "sfixed64", "double", "bytes", "string",
			"fixed32", "sfixed32", "float"].canFind(T);
}

template BuffType(string T) {
	// Msg type 0
	static if(T == "int32"  || T == "sint32") alias BuffType = int;
	else static if(T == "int64" || T == "sint64") alias BuffType = long;
	else static if(T == "uint32") alias BuffType = uint;
	else static if(T == "uint64") alias BuffType = ulong;
	else static if(T == "bool") alias BuffType = bool;
	// Msg type 1
	else static if(T == "fixed64") alias BuffType = ulong;
	else static if(T == "sfixed64") alias BuffType = long;
	else static if(T == "double") alias BuffType = double;
	// Msg type 2
	else static if(T == "bytes") alias BuffType = ubyte[];
	else static if(T == "string") alias BuffType = string;
	// Msg type 3,4 deprecated. Will not support.
	// Msg type 5
	else static if(T == "fixed32") alias BuffType = uint;
	else static if(T == "sfixed32") alias BuffType = int;
	else static if(T == "float") alias BuffType = float;
}

template MsgType(string T) {
	static if(T == "int32"  || T == "sint32" || T == "int64" || T == "sint64" ||
			T == "uint32" || T == "uint64" || T == "bool") {
		enum MsgType = 0;
	} else static if(T == "fixed64" || T == "sfixed64" || T == "double") {
		enum MsgType = 1;
	} else static if(T == "bytes" || T == "string") {
		enum MsgType = 2;
	} else static if(T == "fixed32" || T == "sfixed32" || T == "float") {
		enum MsgType = 5;
	} else {
		enum MsgType = 2;
	}
}

ulong toZigZag(long src) @property pure nothrow {
	return (src << 1) ^ (src >> 63);
}

long fromZigZag(ulong src) @property pure nothrow {
	return (cast(long)(src >> 1)) ^ (cast(long)(-(src & 1)));
}

ubyte wireType(ulong data) @property pure nothrow {
	return data&7;
}

ulong msgNum(ulong data) @property pure nothrow {
	return data>>3;
}

long readMsgData(ref ubyte[] src) {
	size_t i = src.countUntil!q{!(a&0x80)}();
	auto ret = src[0..i+1].fromVarint();
	src = src[i+1..$];
	return ret;
}

ubyte[] readVarint(ref ubyte[] src) {
	size_t i = src.countUntil!q{!(a&0x80)}();
	auto ret = src[0..i+1];
	src = src[i+1..$];
	return ret;
}

ubyte[] toVarint(long src) @property pure nothrow {
	ubyte[] ret;
	while(src&(~0x7FUL)) {
		ret ~= 0x80 | src&0x7F;
		src >>= 7;
	}
	ret ~= src&0x7F;
	return ret;
}

long fromVarint(ubyte[] src) @property {
	return 0L.reduce!q{(a<<7)|(b&0x7F)}(src.retro());
}

alias concat = reduce!((a,b)=>a~b);

enum ENUM_SERIALIZATION = "sint32";
enum PACKED_MSG_TYPE = 2;

////////////////////////////////////////////////////////////////////////////////
// Type 0

BuffType!T readProto(string T)(ref ubyte[] src)
	if(T == "int32" || T == "int64" || T == "uint32" || T == "uint64" || T == "bool")
{
	return src.readVarint().fromVarint().to!(BuffType!T)();
}

BuffType!T readProto(string T)(ref ubyte[] src)
	if(T == "sint32" || T == "sint64")
{
	return src.readVarint().fromVarint().fromZigZag().to!(BuffType!T)();
}

ubyte[] writeProto(string T)(BuffType!T src)
	if(T == "int32" || T == "int64" || T == "uint32" || T == "uint64" || T == "bool")
{
	return src.toVarint().dup;
}

ubyte[] writeProto(string T)(BuffType!T src)
	if(T == "sint32" || T == "sint64")
{
	return src.toZigZag().toVarint().dup;
}

////////////////////////////////////////////////////////////////////////////////
// Types 1 and 5 - the fixed-width types

BuffType!T readProto(string T)(ref ubyte[] src)
	if(T == "double" || T == "fixed64" || T == "sfixed64" ||
		T == "float" || T == "fixed32" || T == "sfixed32")
{
	enforce(src.length >= BuffType!T.sizeof, new DProtoException("Not enough data in buffer"));
	return src.read!(BuffType!T, Endian.littleEndian)();
}

ubyte[] writeProto(string T)(BuffType!T src)
	if(T == "double" || T == "fixed64" || T == "sfixed64" ||
		T == "float" || T == "fixed32" || T == "sfixed32")
{
	return src.nativeToLittleEndian!(BuffType!T)().dup;
}

////////////////////////////////////////////////////////////////////////////////
// Type 2

BuffType!T readProto(string T)(ref ubyte[] src)
	if(T == "string" || T == "bytes")
{
	auto length = src.readProto!"int64"();
	enforce(src.length >= length, new DProtoException("Not enough data in buffer"));
	auto s = cast(BuffType!T)(src.take(length));
	src=src[length..$];
	return s;
}

ubyte[] writeProto(string T)(BuffType!T src)
	if(T == "string" || T == "bytes")
{
	return src.length.toVarint() ~ cast(ubyte[])(src);
}
