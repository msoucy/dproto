/*******************************************************************************
 * Serialization/deserialization code
 *
 * Author: Matthew Soucy, msoucy@csh.rit.edu
 * Date: Oct 5, 2013
 * Version: 0.0.2
 */
module dproto.serialize;

import dproto.exception;
import dproto.compat;

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
bool isBuiltinType(string type) @safe pure nothrow {
	return ["int32" , "sint32", "int64", "sint64", "uint32", "uint64", "bool",
			"fixed64", "sfixed64", "double", "bytes", "string",
			"fixed32", "sfixed32", "float"].canFind(type);
}

unittest {
	assert(isBuiltinType("sfixed32") == true);
	assert(isBuiltinType("double") == true);
	assert(isBuiltinType("string") == true);
	assert(isBuiltinType("int128") == false);
	assert(isBuiltinType("quad") == false);
}

template PossiblyNullable(T) {
	static if(is(T == enum)) {
		alias PossiblyNullable = T;
	} else {
		import std.typecons : Nullable;
		alias PossiblyNullable = Nullable!T;
	}
}

template UnspecifiedDefaultValue(T) {
	static if(is(T == enum)) {
		import std.traits : EnumMembers;
		enum UnspecifiedDefaultValue = EnumMembers!(T)[0];
	} else {
		enum UnspecifiedDefaultValue = T.init;
	}
}

template SpecifiedDefaultValue(T, string value) {
	import std.conv : to;
	enum SpecifiedDefaultValue = to!T(value);
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
@nogc
auto msgType(string T) pure nothrow @safe {
	switch(T) {
		case "int32", "sint32", "uint32":
		case "int64", "sint64", "uint64":
		case "bool":
			return 0;
		case "fixed64", "sfixed64", "double":
			return 1;
		case "bytes", "string":
			return 2;
		case "fixed32", "sfixed32", "float":
			return 5;
		default:
			return 2;
	}
}

/*******************************************************************************
 * Encodes a number in its zigzag encoding
 *
 * Params:
 *  	src = The raw integer to encode
 * Returns: The zigzag-encoded value
 */
@nogc Unsigned!T toZigZag(T)(in T src) pure nothrow @safe @property
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
@nogc Signed!T fromZigZag(T)(in T src) pure nothrow @safe @property
	if(isIntegral!T && isUnsigned!T)
{
	return (src & 1) ?
		-(src >> 1) - 1 :
		src >> 1;
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
 * Encode an unsigned value into a VarInt-encoded series of bytes
 *
 * Params:
 *  	r = output range
 *  	src = The value to encode
 * Returns: The created VarInt
 */
void toVarint(R, T)(ref R r, T src) @safe @property
	if(isOutputRange!(R, ubyte) && isIntegral!T && isUnsigned!T)
{
	immutable ubyte maxMask = 0b_1000_0000;

	while( src >= maxMask )
	{
		r.put(cast(ubyte)(src | maxMask));
		src >>= 7;
	}

	r.put(cast(ubyte) src);
}

/*******************************************************************************
 * Encode a signed value into a VarInt-encoded series of bytes
 *
 * This function is useful for encode int32 and int64 value types
 * (Do not confuse it with signed values encoded by ZigZag!)
 *
 * Params:
 *  	r = output range
 *  	src = The value to encode
 * Returns: The created VarInt
 */
void toVarint(R)(ref R r, long src) @safe @property
	if(isOutputRange!(R, ubyte))
{
	ulong u = src;
	toVarint(r, u);
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
	assert(equal(toVarint(ubyte.max), [0xFF, 0x01]));
	assert(equal(toVarint(uint.max), [0xFF, 0xFF, 0xFF, 0xFF, 0xF]));
	assert(equal(toVarint(ulong.max), [0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x01]));
	assert(equal(toVarint(-1), [0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x01]));
	assert(toVarint(-12345).fromVarint!int == -12345);
	assert(toVarint(int.min).fromVarint!int == int.min);
}

/*******************************************************************************
 * Decode a VarInt-encoded series of bytes into an unsigned value
 *
 * Params:
 *  	src = The data stream
 * Returns: The decoded value
 */
T fromVarint(T = ulong, R)(R src) @property
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
				offset < T.sizeof * 8,
				"Varint value is too big for the type " ~ T.stringof
			);

		offset += 7;
	}

	return ret;
}

/*******************************************************************************
 * Decode a VarInt-encoded series of bytes into a signed value
 *
 * Params:
 *  	src = The data stream
 * Returns: The decoded value
 */
T fromVarint(T, R)(R src) @property
	if(isInputRange!R && is(ElementType!R : const ubyte) &&
		isIntegral!T && isSigned!T)
{
	long r = fromVarint!ulong(src);
	return r.to!T;
}

unittest {
	ubyte[] ubs(ubyte[] vals...) {
		return vals.dup;
	}

	assert(ubs(0x96, 0x01).fromVarint() == 150);
	assert(ubs(0x03).fromVarint() == 3);
	assert(ubs(0x8E, 0x02).fromVarint() == 270);
	assert(ubs(0x9E, 0xA7, 0x05).fromVarint() == 86942);
	assert(ubs(0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x01).fromVarint!int() == -1);

	bool overflow = false;
	try
		ubs(0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x01).fromVarint();
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
 * Test a range for being a valid ProtoBuf input range
 *
 * Params:
 *     R = type to test
 * Returns: The value
 */

enum isProtoInputRange(R) = isInputRange!R && is(ElementType!R : const ubyte);

/*******************************************************************************
 * Decode a series of bytes into a value
 *
 * Params:
 *  	src = The data stream
 * Returns: The decoded value
 */
BuffType!T readProto(string T, R)(ref R src)
	if(isProtoInputRange!R && (T == "sint32" || T == "sint64"))
{
	return src.readVarint().fromZigZag().to!(BuffType!T)();
}

/// Ditto
BuffType!T readProto(string T, R)(ref R src)
	if(isProtoInputRange!R && T.msgType == "int32".msgType)
{
	return src.readVarint().to!(BuffType!T)();
}

/// Ditto
BuffType!T readProto(string T, R)(ref R src)
	if(isProtoInputRange!R &&
	  (T.msgType == "double".msgType || T.msgType == "float".msgType))
{
	return src.read!(BuffType!T, Endian.littleEndian)();
}

/// Ditto
BuffType!T readProto(string T, R)(ref R src)
	if(isProtoInputRange!R && T.msgType == "string".msgType)
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
 * Test a range for being a valid ProtoBuf output range
 *
 * Params:
 *     R = type to test
 * Returns: The value
 */

enum isProtoOutputRange(R) = isOutputRange!(R, ubyte);

/*******************************************************************************
 * Encode a value into a series of bytes
 *
 * Params:
 *     r = output range
 *     src = The raw data
 * Returns: The encoded value
 */
void writeProto(string T, R)(ref R r, const BuffType!T src)
	if(isProtoOutputRange!R && (T == "sint32" || T == "sint64"))
{
	toVarint(r, src.toZigZag);
}

/// Ditto
void writeProto(string T, R)(ref R r, BuffType!T src)
	if(isProtoOutputRange!R && T.msgType == "int32".msgType)
{
	toVarint(r, src);
}

/// Ditto
void writeProto(string T, R)(ref R r, const BuffType!T src)
	if(isProtoOutputRange!R &&
	  (T.msgType == "double".msgType || T.msgType == "float".msgType))
{
	r.put(src.nativeToLittleEndian!(BuffType!T)[]);
}

/// Ditto
void writeProto(string T, R)(ref R r, const BuffType!T src)
	if(isProtoOutputRange!R && T.msgType == "string".msgType)
{
	toVarint(r, src.length);
	r.put(cast(ubyte[])src);
}

/*******************************************************************************
 * Simple range that ignores data but counts the length
 */
struct CntRange
{
@nogc:
	size_t cnt;
	void put(in ubyte) @safe { ++cnt; }
	void put(in ubyte[] ary) @safe { cnt += ary.length; }
	alias cnt this;
}
