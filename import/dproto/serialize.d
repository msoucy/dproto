/*******************************************************************************
 * Serialization/deserialization code
 *
 * Author: Matthew Soucy, msoucy@csh.rit.edu
 * Date: Oct 5, 2013
 * Version: 0.0.2
 */
module dproto.serialize;

import dproto.exception;

import std.algorithm;
import std.array;
import std.bitmanip;
import std.conv;
import std.exception;
import std.range;
import std.system : Endian;
import std.json;
import std.base64;

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
	assert(is(BuffType!"bytes" == ubyte[]) == true);
	assert(is(BuffType!"sfixed64" == int) == false);
}

/*******************************************************************************
 * Removes bytes from the range as if it were read in
 *
 * Params:
 *  	header = The data header
 *  	data   = The data to read from
 */
void defaultDecode(ulong header, ubyte[] data)
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
ulong toZigZag(long src) @safe @property pure nothrow {
	return (src << 1) ^ (src >> 63);
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
long fromZigZag(ulong src) @safe @property pure nothrow {
	return (cast(long)(src >> 1)) ^ (cast(long)(-(src & 1)));
}

unittest {
	assert(0.fromZigZag() == 0);
	assert(1.fromZigZag() == -1);
	assert(2.fromZigZag() == 1);
	assert(3.fromZigZag() == -2);
	assert(4294967294.fromZigZag() == 2147483647);
	assert(4294967295.fromZigZag() == -2147483648);
}

/*******************************************************************************
 * Get the wire type from the encoding value
 *
 * Params:
 *  	data = The data header
 * Returns: The wire type value
 */
ubyte wireType(ulong data) @safe @property pure nothrow {
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
ulong msgNum(ulong data) @safe @property pure nothrow {
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
long readVarint(ref ubyte[] src) {
	size_t i = src.countUntil!( a=>!(a&0x80) )();
	auto ret = src[0..i+1].fromVarint();
	src = src[i+1..$];
	return ret;
}

/*******************************************************************************
 * Encode a value into a VarInt-encoded series of bytes
 *
 * Params:
 *  	src = The value to encode
 * Returns: The created VarInt
 */
ubyte[] toVarint(long src) @property pure nothrow {
	ubyte[] ret;
	while(src&(~0x7FUL)) {
		ret ~= 0x80 | src&0x7F;
		src >>= 7;
	}
	ret ~= src&0x7F;
	return ret;
}

unittest {
	assert(150.toVarint == [0x96, 0x01]);
	assert(3.toVarint == [0x03]);
	assert(270.toVarint == [0x8E, 0x02]);
	assert(86942.toVarint == [0x9E, 0xA7, 0x05]);
}

/*******************************************************************************
 * Decode a VarInt-encoded series of bytes into a value
 *
 * Params:
 *  	src = The data stream
 * Returns: The decoded value
 */
long fromVarint(ubyte[] src) @property {
	return 0L.reduce!q{(a<<7)|(b&0x7F)}(src.retro());
}

unittest {
	assert([0x96, 0x01].fromVarint() == 150);
	assert([0x03].fromVarint() == 3);
	assert([0x8E, 0x02].fromVarint() == 270);
	assert([0x9E, 0xA7, 0x05].fromVarint() == 86942);
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
BuffType!T readProto(string T)(ref ubyte[] src)
	if(T == "int32" || T == "int64" || T == "uint32" || T == "uint64" || T == "bool")
{
	return src.readVarint().to!(BuffType!T)();
}

/// Ditto
BuffType!T readProto(string T)(ref ubyte[] src)
	if(T == "sint32" || T == "sint64")
{
	return src.readVarint().fromZigZag().to!(BuffType!T)();
}

/// Ditto
BuffType!T readProto(string T)(ref ubyte[] src)
	if(T == "double" || T == "fixed64" || T == "sfixed64" ||
		T == "float" || T == "fixed32" || T == "sfixed32")
{
	enforce(src.length >= BuffType!T.sizeof, new DProtoException("Not enough data in buffer"));
	return src.read!(BuffType!T, Endian.littleEndian)();
}

/// Ditto
BuffType!T readProto(string T)(ref ubyte[] src)
	if(T == "string" || T == "bytes")
{
	auto length = src.readProto!"int64"();
	enforce(src.length >= length, new DProtoException("Not enough data in buffer"));
	auto s = cast(BuffType!T)(src.take(length));
	src=src[length..$];
	return s;
}

/*******************************************************************************
 * convert value to a JSONValue
 *
 * Params:
 *      src = The raw data
 * Returns: The JSONValue
 */
JSONValue writeJSON(string T)(BuffType!T src)
    if(T == "fixed32" || T == "fixed64" || T == "int32" || T == "int64" || T == "uint32" || T == "uint64")
{
    JSONValue ret;
    ret.type = JSON_TYPE.UINTEGER;
    ret.uinteger = src;
    return ret;
}

/// Ditto
JSONValue writeJSON(string T)(BuffType!T src)
    if(T == "sint32" || T == "sint64" || T == "sfixed64" || T == "sfixed32")
{
    JSONValue ret;
    ret.type = JSON_TYPE.INTEGER;
    ret.integer = src;
    return ret;
}

/// Ditto
JSONValue writeJSON(string T)(BuffType!T src)
    if(T == "double" || T == "float")
{
    JSONValue ret;
    ret.type = JSON_TYPE.FLOAT;
    ret.floating = src;
    return ret;
}

/// Ditto
JSONValue writeJSON(string T)(BuffType!T src)
    if (T == "string")
{
    JSONValue ret;
    ret.type = JSON_TYPE.STRING;
    ret.str = src;
    return ret;
}

/// Ditto
JSONValue writeJSON(string T)(BuffType!T src)
    if (T == "bytes")
{
    JSONValue ret;
    ret.type = JSON_TYPE.STRING;
    ret.str = Base64.encode(src);
    return ret;
}

JSONValue writeJSON(string T)(BuffType!T src)
    if (T == "bool")
{
    JSONValue ret;
    if (src)
        ret.type = JSON_TYPE.TRUE;
    else
        ret.type = JSON_TYPE.FALSE;
    return ret;
}

/*******************************************************************************
 * Encode a value into a series of bytes
 *
 * Params:
 *  	src = The raw data
 * Returns: The encoded value
 */
ubyte[] writeProto(string T)(BuffType!T src)
	if(T == "int32" || T == "int64" || T == "uint32" || T == "uint64" || T == "bool")
{
	return src.toVarint().dup;
}

/// Ditto
ubyte[] writeProto(string T)(BuffType!T src)
	if(T == "sint32" || T == "sint64")
{
	return src.toZigZag().toVarint().dup;
}

/// Ditto
ubyte[] writeProto(string T)(BuffType!T src)
	if(T == "double" || T == "fixed64" || T == "sfixed64" ||
		T == "float" || T == "fixed32" || T == "sfixed32")
{
	return src.nativeToLittleEndian!(BuffType!T)().dup;
}

/// Ditto
ubyte[] writeProto(string T)(BuffType!T src)
	if(T == "string" || T == "bytes")
{
	return src.length.toVarint() ~ cast(ubyte[])(src);
}
