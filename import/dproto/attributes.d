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
	@disable this();
	this(string w, ubyte f) {
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
		foreach(__member; ProtoFields!this) {
			alias __field = Id!(__traits(getMember, this, __member));
			serializeField!__field(__r);
		}
	}

	void deserialize(R)(auto ref R __r)
		if(isProtoInputRange!R)
	{
		import dproto.attributes;
		import std.traits;
		while(!__r.empty()) {
			auto __msgdata = __r.readVarint();
			bool __matched = false;
			foreach(__member; ProtoFields!this) {
				alias __field = Id!(__traits(getMember, this, __member));
				alias __fieldData = getAnnotation!(__field, ProtoField);
				if(__msgdata.msgNum == __fieldData.fieldNumber) {
					__field.deserialize(__msgdata, __r);
					__matched = true;
				}
			}
			if(!__matched) {
				defaultDecode(__msgdata, __r);
			}
		}
	}

}

template ProtoFields(alias self) {
	import std.traits;
	import std.typetuple;
	alias T = typeof(self);
	template HasProtoField(alias F) {
		alias __field = Id!(__traits(getMember, self, F));
		alias HasProtoField = hasValueAnnotation!(__field, ProtoField);
	}
	alias ProtoFields = Filter!(HasProtoField, FieldNameTuple!T);
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
		static if(hasValueAnnotation!(field, Packed) && is(fieldType : T[], T)
				&& (is(T == enum) || fieldData.wireType.isBuiltinType)) {
			serializePackedProto!fieldData(field.opGet, r);
		} else {
			serializeProto!fieldData(field.opGet, r);
		}
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

void serializePackedProto(ProtoField fieldData, T, R)(const T data, ref R r)
	if(isProtoOutputRange!R)
{
	static assert(fieldData.wireType.isBuiltinType,
			"Cannot have packed repeated message");
	if(data.length) {
		dproto.buffers.CntRange cnt;
		static if(is(T == enum)) {
			enum wt = ENUM_SERIALIZATION.msgType;
		} else {
			enum wt = fieldData.wireType;
		}
		foreach (ref e; data)
			cnt.writeProto!wt(e);
		toVarint(r, PACKED_MSG_TYPE | (fieldData.fieldNumber << 3));
		toVarint(r, cnt.cnt);
		foreach (ref e; data)
			r.writeProto!wt(e);
	}
}
