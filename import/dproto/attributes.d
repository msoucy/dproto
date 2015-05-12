/*******************************************************************************
 * User-Defined Attributes used to tag fields as dproto-serializable
 *
 * Authors: Matthew Soucy, msoucy@csh.rit.edu
 * Date: May 6, 2015
 * Version: 1.3.0
 */
module dproto.attributes;

import dproto.serialize;

// nogc compat shim using UDAs (@nogc must appear as function prefix)
static if (__VERSION__ < 2066) enum nogc;


struct ProtoField
{
	string wireType;
	ubyte fieldNumber;
	string[string] options;
	@disable this();
	this(string w, ubyte f, string[string] opts) {
		wireType = w;
		fieldNumber = f;
	}
	@nogc auto header() {
		return (wireType.msgType | (fieldNumber << 3));
	}
}

struct Required {}
struct Packed {}

template hasValueAnnotation(alias f, Attr)
{
	static bool helper()
	{
		foreach(attr; __traits(getAttributes, f))
			static if(is(typeof(attr) == Attr))
				return true;
		return false;
	}
	enum hasValueAnnotation = helper();
}

template hasAnyValueAnnotation(alias f, Attr...)
{
	static bool helper()
	{
		foreach(annotation; Attr)
			static if(hasValueAnnotation!(f, annotation))
				return true;
		return false;
	}
	enum hasAnyAnnotation = helper();
}

template getAnnotation(alias f, Attr)
	if(hasValueAnnotation!(f, Attr))
{
	static auto helper()
	{
		foreach(attr; __traits(getAttributes, f))
			static if(is(typeof(attr) == Attr))
				return attr;
		assert(0);
	}
	enum getAnnotation = helper();
}

alias Id(alias T) = T;

template ProtoAccessors()
{

	static auto fromProto(R)(auto ref R data)
		if(isProtoInputRange!R)
	{
		auto ret = typeof(this)();
		ret.deserialize(data);
		return ret;
	}

	public this(R)(auto ref R __data)
		if(isProtoInputRange!R)
	{
		deserialize(__data);
	}

	ubyte[] serialize() const
	{
		import std.array : appender;
		auto __a = appender!(ubyte[]);
		serializeTo(__a);
		return __a.data;
	}

	void serializeTo(R)(ref R __r) const
		if(isProtoOutputRange!R)
	{
		import dproto.attributes;
		import std.traits;
		foreach(__member; FieldNameTuple!(typeof(this))) {
			alias __field = Id!(__traits(getMember, this, __member));
			static if(hasValueAnnotation!(__field, ProtoField)) {
				serializeField!__field(__r);
			}
		}
	}

}

template protoDefault(T) {
	static if(is(T == float) || is(T == double)) {
		enum protoDefault = 0.0;
	} else static if(is(T == string)) {
		enum protoDefault = "";
	} else static if(is(T == ubyte[])) {
		enum protoDefault = [];
	} else {
		enum protoDefault = T.init;
	}
}

void serializeField(alias field, R)(ref R r) const
	if(isProtoOutputRange!R)
{
	alias fieldType = typeof(field.opGet);
	enum fieldData = getAnnotation!(field, ProtoField);
	bool needsToSerialize = hasValueAnnotation!(field, Required);
	if(!needsToSerialize) {
		needsToSerialize = field != protoDefault!fieldType;
	}
	if(needsToSerialize) {
		serializeProto!fieldData(field.opGet, r);
	}
}

void serializeProto(ProtoField fieldData, T, R)(const T data, ref R r)
	if(isProtoOutputRange!R)
{
	static if(is(T : const string)) {
		r.toVarint(fieldData.header);
		r.writeProto!"string"(data);
	} else static if(is(T : const(ubyte)[])) {
		r.toVarint(fieldData.header);
		r.writeProto!"bytes"(data);
	} else static if(is(T : const(T)[], T)) {
		// TODO: implement packed
		foreach(val; data) {
			serializeProto!fieldData(val, r);
		}
	} else static if(fieldData.wireType.isBuiltinType) {
		r.toVarint(fieldData.header);
		enum wt = fieldData.wireType;
		r.writeProto!(wt)(data);
	} else static if(is(T == enum)) {
		r.toVarint(ENUM_SERIALIZATION.msgType | (fieldData.fieldNumber << 3));
		r.writeProto!ENUM_SERIALIZATION(data);
	} else static if(__traits(compiles, data.serialize())) {
		r.toVarint(fieldData.header);
		dproto.buffers.CntRange cnt;
		data.serializeTo(cnt);
		r.toVarint(cnt.cnt);
		data.serializeTo(r);
	} else {
		static assert(0, "Unknown serialization");
	}
}
