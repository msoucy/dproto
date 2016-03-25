/*******************************************************************************
 * User-Defined Attributes used to tag fields as dproto-serializable
 *
 * Authors: Matthew Soucy, msoucy@csh.rit.edu
 * Date: May 6, 2015
 * Version: 1.3.0
 */
module dproto.attributes;

import dproto.serialize;
import painlesstraits : getAnnotation, hasValueAnnotation;
import dproto.compat;

import std.traits : Identity;
import std.typecons : Nullable;

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

template TagId(alias T)
	if(hasValueAnnotation!(T, ProtoField))
{
	enum TagId = getAnnotation!(T, ProtoField).fieldNumber;
}

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
			alias __field = Identity!(__traits(getMember, this, __member));
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
				alias __field = Identity!(__traits(getMember, this, __member));
				alias __fieldData = getAnnotation!(__field, ProtoField);
				if(__msgdata.msgNum == __fieldData.fieldNumber) {
					enum wt = __fieldData.wireType;
					__field.putProtoVal!wt(__r);
					__matched = true;
				}
			}
			if(!__matched) {
				defaultDecode(__msgdata, __r);
			}
		}
	}

	version(Have_painlessjson) {
		auto toJson() const {
			import painlessjson;
			import std.conv : to;
			return painlessjson.toJSON(this).to!string;
		}
	}
}

template ProtoFields(alias self)
{
	import std.typetuple : Filter, TypeTuple;

	alias Field(alias F) = Identity!(__traits(getMember, self, F));
	alias HasProtoField(alias F) = hasValueAnnotation!(Field!F, ProtoField);
	alias ProtoFields = Filter!(HasProtoField, TypeTuple!(__traits(allMembers, typeof(self))));
}

template protoDefault(T) {
	import std.traits : isFloatingPoint;
	static if(isFloatingPoint!T) {
		enum protoDefault = 0.0;
	} else static if(is(T : const string)) {
		enum protoDefault = "";
	} else static if(is(T : const ubyte[])) {
		enum protoDefault = [];
	} else {
		enum protoDefault = T.init;
	}
}

void serializeField(alias field, R)(ref R r) const
    if (isProtoOutputRange!R)
{
	alias fieldType = typeof(field);
	enum fieldData = getAnnotation!(field, ProtoField);
	// Serialize if required or if the value isn't the (proto) default
	enum isNullable = is(fieldType == Nullable!U, U);
	bool needsToSerialize;
	static if (isNullable) {
		needsToSerialize = ! field.isNull;
	} else {
		needsToSerialize = hasValueAnnotation!(field, Required)
		    || (field != protoDefault!fieldType);
	}

	// If we still don't need to serialize, we're done here
	if (!needsToSerialize)
	{
		return;
	}
	static if(isNullable) {
		const rawField = field.get;
	} else {
		const rawField = field;
	}

	enum isPacked = hasValueAnnotation!(field, Packed);
	enum isPackType = is(fieldType == enum) || fieldData.wireType.isBuiltinType;
	static if (isPacked && isArray!fieldType && isPackType)
		alias serializer = serializePackedProto;
	else
		alias serializer = serializeProto;
	serializer!fieldData(rawField, r);
}

void putProtoVal(string wireType, T, R)(ref T t, auto ref R r)
	if(isProtoInputRange!R)
{
	static if(is(T : U[], U) && !(is(T : string) || is(T : const(ubyte)[]))) {
		U u;
		u.putSingleProtoVal!wireType(r);
		t ~= u;
	} else {
		t.putSingleProtoVal!wireType(r);
	}
}

void putSingleProtoVal(string wireType, T, R)(ref T t, auto ref R r)
	if(isProtoInputRange!R)
{
	import std.conv : to;
	static if(is(T : Nullable!U, U)) {
		U t_tmp;
		t_tmp.putSingleProtoVal!wireType(r);
		t = t_tmp;
	} else static if(isOptionalField!T) {
		putSingleProtoVal!wireType(t.value, r);
	} else static if(wireType.isBuiltinType) {
		t = r.readProto!wireType().to!T();
	} else static if(is(T == enum)) {
		t = r.readProto!ENUM_SERIALIZATION().to!T();
	} else {
		auto myData = r.readProto!"bytes"();
		return t.deserialize(myData);
	}
}

bool isOptionalField(T)() {
	import std.traits : TemplateOf;

	static if(__traits(compiles, TemplateOf!T) &&
			__traits(isSame, TemplateOf!T, OptionalField))
		return true;
	else
		return false;
}

void serializeProto(alias fieldData, T, R)(const T data, ref R r)
	if(isProtoOutputRange!R)
{
	static if(isOptionalField!T) {
		serializeProto!(fieldData)(data.value, r);
	}
	else static if(is(T : const string)) {
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
		dproto.serialize.CntRange cnt;
		data.serializeTo(cnt);
		r.toVarint(cnt.cnt);
		data.serializeTo(r);
	} else {
		static assert(0, "Unknown serialization");
	}
}

void serializePackedProto(alias fieldData, T, R)(const T data, ref R r)
	if(isProtoOutputRange!R)
{
	static assert(fieldData.wireType.isBuiltinType,
			"Cannot have packed repeated message");
	if(data.length) {
		dproto.serialize.CntRange cnt;
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
