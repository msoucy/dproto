package persion; 

import std.range;
import dproto.serialize;

static struct Person {
	static import dproto.attributes;
	mixin dproto.attributes.ProtoAccessors;

enum PhoneType {
	WORK = 2,  
	HOME = 0,  
	MOBILE = 0,  
}

static struct PhoneNumber {
	static import dproto.attributes;
	mixin dproto.attributes.ProtoAccessors;

	@(dproto.attributes.Required())
	@(dproto.attributes.ProtoField("string", 1))
	BuffType!"string" number= UnspecifiedDefaultValue!(BuffType!"string");


	@(dproto.attributes.ProtoField("PhoneType", 2))
	dproto.serialize.PossiblyNullable!(PhoneType) type= SpecifiedDefaultValue!(PhoneType, "MOBILE");

}

	@(dproto.attributes.Required())
	@(dproto.attributes.ProtoField("string", 1))
	BuffType!"string" name= UnspecifiedDefaultValue!(BuffType!"string");


	@(dproto.attributes.Required())
	@(dproto.attributes.ProtoField("int32", 2))
	BuffType!"int32" id= UnspecifiedDefaultValue!(BuffType!"int32");


	@(dproto.attributes.ProtoField("string", 3))
	BuffType!"string" email= UnspecifiedDefaultValue!(BuffType!"string");


	@(dproto.attributes.ProtoField("PhoneNumber", 4))
	PhoneNumber[] phone;

}

static struct ServiceRequest {
	static import dproto.attributes;
	mixin dproto.attributes.ProtoAccessors;

	@(dproto.attributes.ProtoField("string", 1))
	BuffType!"string" request= UnspecifiedDefaultValue!(BuffType!"string");

}

static struct ServiceResponse {
	static import dproto.attributes;
	mixin dproto.attributes.ProtoAccessors;

	@(dproto.attributes.ProtoField("string", 1))
	BuffType!"string" response= UnspecifiedDefaultValue!(BuffType!"string");

}

interface TestService {
	ServiceResponse TestMethod (ServiceRequest);
}

