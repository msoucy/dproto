/*******************************************************************************
 * Serialization/deserialization code
 *
 * Author: Matthew Soucy, msoucy@csh.rit.edu
 * Date: Oct 5, 2013
 * Version: 0.0.2
 */
module dproto.serialize;

import dproto.exception;

// nogc compat shim using UDAs (@nogc must appear as function prefix)
static if (__VERSION__ < 2066) enum nogc;

import std.algorithm;
import std.array;
import std.bitmanip;
import std.conv;
import std.exception;
import std.range;
import std.system : Endian;
import std.traits;

/*******************************************************************************
 * Returns whether the given string is a protocol buffer primitive
 *
 * Params:
 *  	type = The type to check for
 * Returns: True if the type is a protocol buffer primitive
 */
bool IsBuiltinType(string type) @safe pure nothrow {
	return ["int32" , "sint32", "int64", "sint64", "uint32", "uint64", "bool",
			"fixed64", "sfixed64", "double", "bytes", "string",
			"fixed32", "sfixed32", "float"].canFind(type);
}

unittest {
	assert(IsBuiltinType("sfixed32") == true);
	assert(IsBuiltinType("double") == true);
	assert(IsBuiltinType("string") == true);
	assert(IsBuiltinType("int128") == false);
	assert(IsBuiltinType("quad") == false);
}

/*******************************************************************************
 * Maps the given type string to the data type it represents
 */
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

unittest {
	assert(is(BuffType!"sfixed32" == int) == true);
	assert(is(BuffType!"double" == double) == true);
	assert(is(BuffType!"string" == string) == true);
	assert(is(BuffType!"bytes" : const ubyte[]) == true);
	assert(is(BuffType!"sfixed64" == int) == false);
}

/*******************************************************************************
 * Removes bytes from the range as if it were read in
 *
 * Params:
 *  	header = The data header
 *  	data   = The data to read from
 */
void defaultDecode(R)(ulong header, ref R data)
	if(isInputRange!R && is(ElementType!R : const ubyte))
{
	switch(header.wireType) {
		case 0:
			data.readProto!"int32"();
			break;
		case 1:
			data.readProto!"fixed64"();
			break;
		case 2:
			data.readProto!"bytes"();
			break;
		case 5:
			data.readProto!"fixed32"();
			break;
		default:
			break;
	}
}

/*******************************************************************************
 * Maps the given type string to the wire type number
 */
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

/*******************************************************************************
 * Encodes a number in its zigzag encoding
 *
 * Params:
 *  	src = The raw integer to encode
 * Returns: The zigzag-encoded value
 */
Unsigned!T toZigZag(T)(in T src) pure nothrow @safe @nogc @property
	if(isIntegral!T && isSigned!T)
{
	return cast(Unsigned!T)(
			src >= 0 ?
				src * 2 :
				-src * 2 - 1
		);
}

unittest {
	assert(0.toZigZag() == 0);
	assert((-1).toZigZag() == 1);
	assert(1.toZigZag() == 2);
	assert((-2).toZigZag() == 3);
	assert(2147483647.toZigZag() == 4294967294);
	assert((-2147483648).toZigZag() == 4294967295);
}

/*******************************************************************************
 * Decodes a number from its zigzag encoding
 *
 * Params:
 *  	src = The zigzag-encoded value to decode
 * Returns: The raw integer
 */
Signed!T fromZigZag(T)(inout T src) pure nothrow @safe @nogc @property
	if(isIntegral!T && isUnsigned!T)
{
	Signed!T res = (src & 1)
		?
			-(src >> 1) - 1
		:
			src >> 1;
	
	return res;
}

unittest {
	assert(0U.fromZigZag() == 0);
	assert(1U.fromZigZag() == -1);
	assert(2U.fromZigZag() == 1);
	assert(3U.fromZigZag() == -2);
	assert(4294967294U.fromZigZag() == 2147483647);
	assert(4294967295U.fromZigZag() == -2147483648);
}

/*******************************************************************************
 * Get the wire type from the encoding value
 *
 * Params:
 *  	data = The data header
 * Returns: The wire type value
 */
@nogc ubyte wireType(ulong data) @safe @property pure nothrow {
	return data&7;
}

unittest {
	assert((0x08).wireType() == 0); // Test for varints
	assert((0x09).wireType() == 1); // Test 64-bit
	assert((0x12).wireType() == 2); // Test length-delimited
}

/*******************************************************************************
 * Get the message number from the encoding value
 *
 * Params:
 *  	data = The data header
 * Returns: The message number
 */
@nogc ulong msgNum(ulong data) @safe @property pure nothrow {
	return data>>3;
}

unittest {
	assert((0x08).msgNum() == 1);
	assert((0x11).msgNum() == 2);
	assert((0x1a).msgNum() == 3);
	assert((0x22).msgNum() == 4);
}

/*******************************************************************************
 * Read a VarInt-encoded value from a data stream
 *
 * Removes the bytes that represent the data from the stream
 *
 * Params:
 *  	src = The data stream
 * Returns: The decoded value
 */
long readVarint(R)(ref R src)
	if(isInputRange!R && is(ElementType!R : const ubyte))
{
	auto i = src.countUntil!( a=>!(a&0x80) )() + 1;
	auto ret = src.take(i);
	src.popFrontExactly(i);
	return ret.fromVarint();
}

/*******************************************************************************
 * Encode a value into a VarInt-encoded series of bytes
 *
 * Params:
 *  	r = output range
 *  	src = The value to encode
 * Returns: The created VarInt
 */
void toVarint(R, T)(ref R r, T src) @trusted @property
	if(isOutputRange!(R, ubyte)) // FIXME: && isIntegral!T && isUnsigned!T)
{
	immutable ubyte maxMask = 0b_1000_0000;
	
	while( src >= maxMask )
	{
		r.put(cast( ubyte )( src | maxMask ));
		src >>= 7;
	}
	
	r.put(cast(ubyte) src);
}

unittest {
	static ubyte[] toVarint(ulong val) @property
	{
		auto r = appender!(ubyte[])();
		.toVarint(r, val);
		return r.data;
	}
	assert(equal(toVarint(150), [0x96, 0x01]));
	assert(equal(toVarint(3), [0x03]));
	assert(equal(toVarint(270), [0x8E, 0x02]));
	assert(equal(toVarint(86942), [0x9E, 0xA7, 0x05]));
	assert(equal(toVarint(uint.max), [0xFF, 0xFF, 0xFF, 0xFF, 0xF]));
	assert(equal(toVarint(ulong.max), [0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x01]));
	assert(equal(toVarint(-1), [0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x01]));
}

/*******************************************************************************
 * Decode a VarInt-encoded series of bytes into a value
 *
 * Params:
 *  	src = The data stream
 * Returns: The decoded value
 */
T fromVarint(R, T = ulong)(R src) @property
	if(isInputRange!R && is(ElementType!R : const ubyte) &&
		isIntegral!T && isUnsigned!T)
{
	immutable ubyte mask = 0b_0111_1111;
	T ret;
	
	size_t offset;
	foreach(val; src)
	{
		ret |= cast(T)(val & mask) << offset;
		
		enforce(
				offset + 7 <= T.sizeof * 8,
				"Varint is too big for type " ~ T.stringof
			);
		
		offset+=7;
	}
	
	return ret;
}

unittest {
	ubyte[] ubs(ubyte[] vals...) {
		return vals.dup;
	}

	assert(ubs(0x96, 0x01).fromVarint() == 150);
	assert(ubs(0x03).fromVarint() == 3);
	assert(ubs(0x8E, 0x02).fromVarint() == 270);
	assert(ubs(0x9E, 0xA7, 0x05).fromVarint() == 86942);
	
	bool overflow = false;
	try
		ubs(0x9E, 0x9E, 0x9E, 0x9E, 0x9E, 0x9E, 0x9E, 0x9E, 0xA7, 0x05).fromVarint();
	catch(Exception)
		overflow = true;
	finally
		assert(overflow);
}

/// The type to encode an enum as
enum ENUM_SERIALIZATION = "int32";
/// The message type to encode a packed message as
enum PACKED_MSG_TYPE = 2;

/*******************************************************************************
 * Decode a series of bytes into a value
 *
 * Params:
 *  	src = The data stream
 * Returns: The decoded value
 */
BuffType!T readProto(string T, R)(ref R src)
	if((T == "int32" || T == "int64" || T == "uint32" || T == "uint64" || T == "bool")
	   && (isInputRange!R && is(ElementType!R : const ubyte)))
{
	return src.readVarint().to!(BuffType!T)();
}

/// Ditto
BuffType!T readProto(string T, R)(ref R src)
	if((T == "sint32" || T == "sint64")
	   && (isInputRange!R && is(ElementType!R : const ubyte)))
{
	return src.readVarint().fromZigZag().to!(BuffType!T)();
}

/// Ditto
BuffType!T readProto(string T, R)(ref R src)
	if((T == "double" || T == "fixed64" || T == "sfixed64" ||
		T == "float" || T == "fixed32" || T == "sfixed32")
	   && (isInputRange!R && is(ElementType!R : const ubyte)))
{
	return src.read!(BuffType!T, Endian.littleEndian)();
}

/// Ditto
BuffType!T readProto(string T, R)(ref R src)
	if((T == "string" || T == "bytes")
	   && (isInputRange!R && is(ElementType!R : const ubyte)))
{
	BuffType!T ret;
	auto len = src.readProto!"uint32"();
	ret.reserve(len);
	foreach(i; 0..len) {
		ret ~= src.front;
		src.popFront();
	}
	return ret;
}

/*******************************************************************************
 * Encode a value into a series of bytes
 *
 * Params:
 *     r = output range
 *  	src = The raw data
 * Returns: The encoded value
 */
void writeProto(string T, R)(ref R r, BuffType!T src)
	if(isOutputRange!(R, ubyte) &&
	   (T == "int32" || T == "int64" || T == "uint32" || T == "uint64" || T == "bool"))
{
	toVarint(r, src);
}

/// Ditto
void writeProto(string T, R)(ref R r, BuffType!T src)
	if(isOutputRange!(R, ubyte) &&
	   (T == "sint32" || T == "sint64"))
{
	toVarint(r, src.toZigZag);
}

/// Ditto
void writeProto(string T, R)(ref R r, BuffType!T src)
	if(isOutputRange!(R, ubyte) &&
	   (T == "double" || T == "fixed64" || T == "sfixed64" ||
		T == "float" || T == "fixed32" || T == "sfixed32"))
{
	r.put(src.nativeToLittleEndian!(BuffType!T)[]);
}

/// Ditto
void writeProto(string T, R)(ref R r, BuffType!T src)
	if(isOutputRange!(R, ubyte) &&
	   (T == "string" || T == "bytes"))
{
	toVarint(r, src.length);
	r.put(cast(ubyte[])src);
}
