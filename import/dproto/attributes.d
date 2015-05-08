/*******************************************************************************
 * User-Defined Attributes used to tag fields as dproto-serializable
 *
 * Authors: Matthew Soucy, msoucy@csh.rit.edu
 * Date: May 6, 2015
 * Version: 1.3.0
 */
module dproto.attributes;

import dproto.serialize;
import std.traits;

// nogc compat shim using UDAs (@nogc must appear as function prefix)
static if (__VERSION__ < 2066) enum nogc;


struct ProtoField
{
	string wireType;
	uint fieldNumber;
	@disable this();
	this(string w, uint f) {
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
	ubyte[] toProto()
	{
		import std.array : appender;
		auto a = appender!(ubyte[]);
		toProto(a);
		return a.data;
	}

	void toProto(R)(R r)
		if(isOutputRange!(R, ubyte))
	{
		import dproto.attributes;
		import std.traits;
		foreach(member; FieldNameTuple!(typeof(this))) {
			static if(hasValueAnnotation!(__traits(getMember, typeof(this), member), ProtoField)) {
				toProtoField!member(r);
			}
		}
	}

	private void toProtoField(string f, R)(R r)
		if(isOutputRange!(R, ubyte))
	{
		import dproto.attributes;
		alias field = Id!(__traits(getMember, typeof(this), f));
		alias fieldType = typeof(field.opGet);
		enum fieldData = getAnnotation!(field, ProtoField);
		bool needsToSerialize = hasValueAnnotation!(field, Required);
		if(!needsToSerialize) {
			static if(is(fieldType == float) || is(fieldType == double)) {
				needsToSerialize |= (field.opGet != 0.0);
			} else static if(is(fieldType == string)) {
				needsToSerialize |= (field.opGet != "");
			} else static if(is(fieldType == ubyte[])) {
				needsToSerialize |= (field.opGet != []);
			} else {
				needsToSerialize |= (field.opGet != fieldType.init);
			}
		}
		if(needsToSerialize) {
			auto data = __traits(getMember, typeof(this), f).opGet;
			serializeProto!fieldData(data, r);
		}
	}

	void serializeProto(dproto.attributes.ProtoField fieldData, T, R)(T data, R r)
		if(isOutputRange!(R, ubyte))
	{
		static if(is(T : const string)) {
			r.toVarint(fieldData.header);
			r.writeProto!"string"(data);
		}
		else static if(is(T : const(ubyte)[])) {
			r.toVarint(fieldData.header);
			r.writeProto!"bytes"(data);
		}
		else static if(is(T : const(T)[], T)) {
			// TODO: implement packed
			foreach(val; data) {
				serializeProto!fieldData(val, r);
			}
		}
		else {
			r.toVarint(fieldData.header);
			static if(fieldData.wireType.isBuiltinType) {
				enum wt = fieldData.wireType;
				r.writeProto!(wt)(data);
			} else {
				CntRange cnt;
				static if(is(T == enum)) {
					cnt.writeProto!ENUM_SERIALIZATION(data);
					r.toVarint(cnt.cnt);
					r.writeProto!ENUM_SERIALIZATION(data);
				} else {
					data.toProto(cnt);
					r.toVarint(cnt.cnt);
					data.toProto(r);
				}
			}
		}
	}
}

