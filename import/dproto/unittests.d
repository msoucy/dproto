/*******************************************************************************
 * Main library import for dproto
 *
 * Provides accessors for D string and D structs from proto files/data
 *
 * Authors: Matthew Soucy, msoucy@csh.rit.edu
 * Date: Apr 1, 2015
 * Version: 0.0.3
 */
module dproto.unittests;

import dproto.dproto;

unittest
{
	assert(__traits(compiles, ProtocolBufferFromString!"message Test
		{
			optional string verySimple = 1;
		}"));
}

unittest
{
	assert(__traits(compiles, ProtocolBufferFromString!"
		message Test
		{
			optional string verySimple = 1;
			enum TestEnum
			{
				ONE = 1;
				UNO = 1;
				TOW = 2;
			}
		}"));
}

unittest
{
	mixin ProtocolBufferFromString!"
		message Test
		{
			required int32 id = 1;
			optional string verySimple = 2;
			enum TestEnum
			{
				ONE = 1;
				UNO = 1;
				TOW = 2;
			}
			optional TestEnum testValue = 3;
		}";
}

unittest
{
	assert(__traits(compiles, ProtocolBufferFromString!"message Test
		{
			optional string verySimple = 1;
			enum TestEnum
			{
				ONE = 1;
				UNO = 1;
				TOW = 2;
			}

			optional string testValue = 2;
		}"));
}

unittest
{
	assert(__traits(compiles, ProtocolBufferFromString!"
	message Test
	{
		optional string verySimple = 1;
		message NestedTest
		{
			optional string verySimple = 1;
		}

		optional NestedTest value = 2;
	}"));
}

unittest
{
	assert(__traits(compiles, ProtocolBufferFromString!"
	message Test
	{
		optional string verySimple = 1;
		message NestedTest
		{
			optional string verySimple2 = 1;
		}

		optional NestedTest value = 2;
	}"));
}

unittest
{
	assert(__traits(compiles, ProtocolBufferFromString!"
	message Test
	{
		optional string verySimple = 1;
		message NestedTest
		{
			optional string verySimple = 1;
		}

		repeated NestedTest value = 2;
	}"));
}

unittest
{
	assert(__traits(compiles, ProtocolBufferFromString!"
	message Test
	{
		required int32 id = 3;
		optional string verySimple = 1;
		message NestedTest
		{
			required string verySimple = 1;
		}

		required NestedTest value = 2;
	}"));
}

unittest
{
	assert(__traits(compiles, ProtocolBufferFromString!"
	message Test
	{
		required int32 id = 3;
		optional string verySimple = 1;
		message NestedTest
		{
			required string verySimple = 1;
		}

		repeated NestedTest value = 2;
	}"));
}

unittest
{
	assert(__traits(compiles, ProtocolBufferFromString!"
	message Test
	{
		required int32 id = 3;
		optional string verySimple = 1;
		message NestedTest
		{
			required string verySimple = 1;
		}

		optional NestedTest value = 2;
	}"));
}

unittest
{
	assert(__traits(compiles, ProtocolBufferFromString!"
	message Test
	{
		required int32 id = 3;
		optional string verySimple = 1;
		message NestedTest
		{
			required string verySimple = 1;
		}

		repeated NestedTest value = 2;
	}"));
}

unittest
{
	enum serviceDefinition = "
	message ServiceRequest {
		string request = 1;
	}
	message ServiceResponse {
		string response = 1;
	}
	service TestService {
		rpc TestMethod (ServiceRequest) returns (ServiceResponse);
	}
	";

	// Force code coverage in doveralls
	import std.string;
	import std.format;
	import dproto.parse;

	auto normalizedServiceDefinition = "%3.3p".format(ParseProtoSchema("<none>", serviceDefinition));

	assert(__traits(compiles, ProtocolBufferFromString!serviceDefinition));
	assert(__traits(compiles, ProtocolBufferInterface!serviceDefinition));
	assert(__traits(compiles, ProtocolBufferRpc!serviceDefinition));
	assert(__traits(compiles, ProtocolBufferImpl!serviceDefinition));
	assert(__traits(compiles, ProtocolBufferStruct!serviceDefinition));

	// Example from README.md.
	mixin ProtocolBufferInterface!serviceDefinition;

	class ServiceImplementation : TestService
	{
		ServiceResponse TestMethod(ServiceRequest input)
		{
			ServiceResponse output;
			output.response = "received: " ~ input.request;
			return output;
		}
	}

	auto serviceTest = new ServiceImplementation;
	ServiceRequest input;
	input.request = "message";
	assert(serviceTest.TestMethod(input).response == "received: message");

}

unittest
{
	mixin ProtocolBufferFromString!"
	enum PhoneType {
		MOBILE = 0;
		HOME = 0;
		WORK = 2;
	}

	message Person {
		required string name = 1;
		required int32 id = 2;
		optional string email = 3;

		message PhoneNumber {
			required string number = 1;
			optional PhoneType type = 2 [default = HOME];
		}

		repeated PhoneNumber phone = 4;
	}
	";

	Person t;
	assert(t.name == "");
	assert(t.id == 0);
	assert(t.phone.length == 0);
	version (Have_painlessjson)
	{
		assert(t.toJson() == `{"email":"","id":0,"name":"","phone":[]}`);
	}

	t.name = "Max Musterman";
	assert(t.name == "Max Musterman");

	t.id = 3;
	assert(t.id == 3);

	t.email = "Max.Musterman@example.com";
	assert(t.email);
	assert(t.email == "Max.Musterman@example.com");

	Person.PhoneNumber pn1;
	pn1.number = "0123456789";
	assert(pn1.number == "0123456789");
	assert(pn1.type == PhoneType.HOME);
	assert(pn1.type == PhoneType.MOBILE);

	pn1.type = PhoneType.WORK;
	assert(pn1.type == PhoneType.WORK);
	assert(pn1.type);
	assert(pn1.type == 2);

	t.phone ~= pn1;
	assert(t.phone[0] == pn1);
	assert(t.phone.length == 1);

	version (Have_painlessjson)
	{
		assert(
			t.toJson() == `{"email":"Max.Musterman@example.com","id":3,"name":"Max Musterman","phone":[{"number":"0123456789","type":2}]}`);
	}

	pn1.type = pn1.type.init;
	assert(pn1.type == PhoneType.HOME);

	t.phone = t.phone.init;
	assert(t.phone.length == 0);

	t.email = t.email.init;
	assert(t.email == "");
}

unittest
{
	mixin ProtocolBufferFromString!"
	message Person {
		required string name = 1;
		required int32 id = 2;
		optional string email = 3;

		enum PhoneType {
			MOBILE = 0;
			HOME = 0;
			WORK = 2;
		}

		message PhoneNumber {
			required string number = 1;
			optional PhoneType type = 2 [default = HOME];
		}

		repeated PhoneNumber phone = 4;
	}

	message AddressBook {
		repeated Person person = 1;
	}
	";

	Person t;
	assert(t.name == "");
	assert(t.id == 0);
	assert(t.phone.length == 0);

	t.name = "Max Musterman";
	assert(t.name == "Max Musterman");

	t.id = 3;
	assert(t.id == 3);

	t.email = "Max.Musterman@example.com";
	assert(t.email);
	assert(t.email == "Max.Musterman@example.com");

	Person.PhoneNumber pn1;
	pn1.number = "0123456789";
	assert(pn1.number == "0123456789");

	t.phone ~= pn1;
	assert(t.phone[0] == pn1);
	assert(t.phone.length == 1);

	t.phone = t.phone.init;
	assert(t.phone.length == 0);

	t.email = t.email.init;
	assert(t.email == "");

	AddressBook addressbook;
	assert(addressbook.person.length == 0);
	addressbook.person ~= t;
	addressbook.person ~= t;
	assert(addressbook.person[0] == t);
	assert(addressbook.person[0] == addressbook.person[1]);
	assert(addressbook.person.length == 2);
}

unittest
{
	mixin ProtocolBufferFromString!"
	enum PhoneType {
		MOBILE = 0;
		HOME = 0;
		WORK = 2;
	}

	message Person {
		required string name = 1;
		required int32 id = 2;
		optional string email = 3;

		message PhoneNumber {
			required string number = 1;
			optional PhoneType type = 2 [default = HOME];
		}

		repeated PhoneNumber phone = 4;
	}

	message AddressBook {
		repeated Person person = 1;
	}
	";

	Person t;
	t.name = "Max Musterman";
	t.id = 3;
	t.email = "test@example.com";

	Person.PhoneNumber pn1;
	pn1.number = "0123456789";
	pn1.type = PhoneType.WORK;

	Person.PhoneNumber pn2;
	pn2.number = "0123456789";

	t.phone = [pn1, pn2];
	AddressBook addressbook;
	addressbook.person ~= t;
	addressbook.person ~= t;

	ubyte[] serializedObject = addressbook.serialize();

	AddressBook addressbook2 = AddressBook.fromProto(serializedObject);
	assert(addressbook2.person.length == 2);
	foreach (t2; addressbook2.person[0 .. 1])
	{
		assert(t2.name == "Max Musterman");
		assert(t2.id == 3);
		assert(t2.email);
		assert(t2.email == "test@example.com");
		assert(t2.phone[0].number == "0123456789");
		assert(t2.phone[0].type == PhoneType.WORK);
		assert(t2.phone[1].number == "0123456789");
		assert(t2.phone[1].type == PhoneType.HOME);
		assert(t2.phone[1].type == PhoneType.MOBILE);
		assert(t2.phone.length == 2);
	}
	//the gdc-4.8 evaluates false here. Maybe an compiler bug.
	version (DigitalMars)
	{
		assert(addressbook2.person[0] == addressbook.person[1]);
	}
}

unittest
{
	mixin ProtocolBufferFromString!"
	message Person {
		required string name = 1;
		required int32 id = 2;
		optional string email = 3;

		enum PhoneType {
			MOBILE = 0;
			HOME = 0;
			WORK = 2;
		}

		message PhoneNumber {
			required string number = 1;
			optional PhoneType type = 2 [default = HOME];
		}

		repeated PhoneNumber phone = 4;
	}

	message AddressBook {
		repeated Person person = 1;
	}
	";

	Person t;
	assert(t.name == "");
	assert(t.id == 0);
	assert(t.phone.length == 0);

	t.name = "Max Musterman";
	assert(t.name == "Max Musterman");

	t.id = 3;
	assert(t.id == 3);

	t.email = "Max.Musterman@example.com";
	assert(t.email);
	assert(t.email == "Max.Musterman@example.com");

	Person.PhoneNumber pn1;
	pn1.number = "0123456789";
	assert(pn1.number == "0123456789");
	assert(pn1.type == Person.PhoneType.HOME);
	assert(pn1.type == Person.PhoneType.MOBILE);

	pn1.type = Person.PhoneType.WORK;
	assert(pn1.type == Person.PhoneType.WORK);
	assert(pn1.type == 2);
	assert(pn1.type);

	t.phone ~= pn1;
	assert(t.phone[0] == pn1);
	assert(t.phone.length == 1);

	pn1.type = pn1.type.init;
	assert(pn1.type == Person.PhoneType.HOME);

	t.phone = t.phone.init;
	assert(t.phone.length == 0);

	t.email = t.email.init;
	assert(t.email == "");

	AddressBook addressbook;
	assert(addressbook.person.length == 0);
	addressbook.person ~= t;
	addressbook.person ~= t;
	assert(addressbook.person[0] == t);
	assert(addressbook.person[0] == addressbook.person[1]);
	assert(addressbook.person.length == 2);

	static struct OutBuf
	{
	@nogc:
	@safe:
		void put(in ubyte)
		{
		}

		void put(in ubyte[])
		{
		}
	}

	@nogc void testNoGC()
	{
		OutBuf buf;
		addressbook.serializeTo(buf);
	}

	testNoGC();
}

unittest
{
	mixin ProtocolBufferFromString!"
	message Person {
		required string name = 1;
	}
	";

	static auto rvalue(in ubyte[] val)
	{
		return val;
	}

	enum data = cast(ubyte[])[1 << 3 | 2, "abc".length] ~ cast(ubyte[]) "abc";
	const(ubyte)[] val = data;
	assert(val.length == 5);
	assert(Person(rvalue(val)).name == "abc");
	assert(val.length == 5);
	assert(Person(val).name == "abc");
	assert(val.length == 0);
	Person p;
	val = data;
	assert(val.length == 5);
	p.deserialize(rvalue(val));
	assert(val.length == 5);
	assert(p.name == "abc");
	p.name = null;
	p.deserialize(val);
	assert(val.length == 0);
	assert(p.name == "abc");
}

unittest
{
	mixin ProtocolBufferFromString!"
	message Field_Name_Equals_Internal_Variable_Name {
		required int32 r = 1;
		required int32 data = 2;
		required int32 msgdata = 3;
	}
	";
}

unittest
{
	import dproto.exception;
	import dproto.serialize;
	import dproto.parse;
	import std.string : strip;

	auto proto_src = `import "foo/baz.proto";`;
	auto proto_struct = ParseProtoSchema("<none>", proto_src);
	auto d_src = proto_struct.toD;
	assert(`mixin ProtocolBuffer!"foo/baz.proto";` == d_src,
		"Mixin string should not have two double quotes " ~ d_src);
	assert(proto_src == proto_struct.toProto.strip,
		"Round tripping to protobuf source should yield starting text " ~ proto_struct.toProto);
}

unittest
{
	mixin ProtocolBufferFromString!`
	enum RecordFlags
	{
		Announce = 1;
		Cancel = 2;
		SomeAnotherFlag = 4; // look at the enumeration!
	}
	message KeyValue
	{
		required bytes key = 1;
		optional RecordFlags flags = 2;
		optional bytes payload = 3;
	}
	message ECDSASignature
	{
		required bytes signature = 1;
		required bytes pubKey = 2;
	}
	message Signed
	{
		required ECDSASignature esignature = 1;
		required KeyValue keyValue = 2;
	}`;

	Signed d1;
	d1.keyValue.key = cast(ubyte[]) "key data";
	d1.keyValue.payload = cast(ubyte[]) "value data";
	auto ser = d1.serialize();
	Signed d2 = ser;
	assert(d1.keyValue.key == d2.keyValue.key);
	assert(d1.keyValue.payload == d2.keyValue.payload);
}

unittest
{

	mixin ProtocolBufferFromString!`
		message DNSPayload
		{
			repeated bytes assignOwnerPubKeys = 1;
			repeated bytes assignManagersPubKeys = 2;

			repeated bytes ns = 3;
		}
	`;

	DNSPayload p1;
	p1.ns ~= [1, 2, 3];
	auto buf = p1.serialize();

	DNSPayload p2;
	p2.deserialize(buf);
	assert(p1 == p2);
}

unittest
{
	mixin ProtocolBufferFromString!"
		message Person {
			required uint32 id = 1;
		}";
}

unittest
{
	mixin ProtocolBufferFromString!`
		message TestStructure
		{
			optional string optional_string = 1;
			required string required_string = 2;
			repeated string repeated_string = 3;
		}
	`;
	import dproto.attributes : TagId;

	assert(TagId!(TestStructure.optional_string) == 1);
	assert(TagId!(TestStructure.required_string) == 2);
	assert(TagId!(TestStructure.repeated_string) == 3);
}

unittest
{
	mixin ProtocolBufferFromString!"
        message Stats {
            optional int32 agility = 1;
            optional int32 stamina = 2;
        }
        message Character {
            optional string name = 1;
            optional Stats stats = 2;
        }
        message Account {
            optional string owner = 1;
            optional Character main = 2;
        }
    ";
	const int agility = 200;
	auto acct = Account();
	auto main = Character();
	main.name = "Hogan";
	main.stats = Stats();
	main.stats.agility = agility;
	acct.main = main;
	auto ser = acct.serialize();
	Account acct_rx;
	acct_rx.deserialize(ser);
	import std.string : format;

	assert(acct_rx.main.stats.agility == agility, format("Expected %d, got %d",
		agility, acct_rx.main.stats.agility));

}

unittest
{
	enum pbstring = q{
		enum Enum {
			A = 0;
			B = 1;
			C = 2;
		}

		message Msg {
			optional Enum unset = 1;
			optional Enum isset_first = 2 [default = A];
			optional Enum isset_last = 3 [default = C];
			required Enum unset_required = 4;
			required Enum isset_required = 5 [default = B];
			optional int32 i1 = 6 [default = 42];
			optional int32 i2 = 7;
			required int32 i3 = 8 [default = 24];
			required int32 i4 = 9;
		}
	};

	// Force code coverage in doveralls
	import std.string;
	import std.format;
	import dproto.parse;

	auto normalizedServiceDefinition = "%3.3p".format(ParseProtoSchema("<none>", pbstring));

	mixin ProtocolBufferFromString!pbstring;

	Msg msg;
	assert(msg.unset == Enum.A);
	assert(msg.isset_first == Enum.A);
	assert(msg.isset_last == Enum.C);
	assert(msg.unset_required == Enum.A);
	assert(msg.isset_required == Enum.B);
	assert(msg.i1 == 42);
	assert(msg.i2 == typeof(msg.i2).init);
	assert(msg.i3 == 24);
	assert(msg.i4 == typeof(msg.i4).init);
}

unittest
{
	import dproto.parse;
	import dproto.exception;
	import std.exception;

	enum pbstring = q{
message Info {
   optional int32 version = 1 [default = -1];
}
	};
	assertThrown!DProtoReservedWordException(ParseProtoSchema(
				"<none>",
				`option dproto_reserved_fmt = "%s"; ` ~ pbstring));
	assertNotThrown!DProtoReservedWordException(ParseProtoSchema(
				"<none>",
				`option dproto_reserved_fmt = "%s_"; ` ~ pbstring));
	assertNotThrown!DProtoReservedWordException(ParseProtoSchema(
				"<none>", pbstring));
}

unittest
{
	mixin ProtocolBufferFromString!`
message HeaderBBox {
    required sint64 left = 1;
    required sint64 right = 2;
    required sint64 top = 3;
    required sint64 bottom = 4;
}`;
	HeaderBBox headerBBox;

	headerBBox.left = 10;
	headerBBox.right = 5;
	headerBBox.top = -32;
	headerBBox.bottom = -24;

	auto hbb = headerBBox.serialize();
	headerBBox = HeaderBBox(hbb); // Error occurred here

	assert(headerBBox.left == 10);
	assert(headerBBox.right == 5);
	assert(headerBBox.top == -32);
	assert(headerBBox.bottom == -24);
}

unittest
{
	assert(!__traits(compiles, mixin(`mixin ProtocolBufferFromString!q{
    message One {
        required string a;
        required int32 b;
    }
};`)),
		"Malformed proto structure accepted");
}

unittest
{
	import std.algorithm;

	mixin ProtocolBufferFromString!`
	message Foo {
		repeated uint32 arr = 1 [packed=true];
	}
`;

	Foo foo;
	foo.arr = [1];

	auto serialized_foo = foo.serialize();

	auto foo2 = Foo(serialized_foo);

	assert(equal(foo.arr, foo2.arr));
}

unittest
{
	// Issue #86
	import dproto.parse;
	import dproto.exception;
	enum pbstring = q{
    message ReservedWordTest {
        required bool notReservedWord = 1;
    }
};
	mixin ProtocolBufferFromString!pbstring;
	assert(ParseProtoSchema("<none>", pbstring).toD());
}

unittest
{
	import std.algorithm;

	mixin ProtocolBufferFromString!`
	message FooA {
		repeated uint32 arr = 1 [packed=true];
	}
	message FooB {
		repeated uint32 arr = 1;
	}
`;

	FooA foo;
	foo.arr = [1, 3, 5, 7, 2, 4, 6, 8];

	auto serialized_foo = foo.serialize();
	auto foo2 = FooB(serialized_foo);
	assert(equal(foo.arr, foo2.arr));
	auto foo3 = FooA(foo2.serialize());
	assert(equal(foo2.arr, foo3.arr));
}

unittest
{
	// Issue #86
	import dproto.parse;
	import dproto.exception;
	import std.exception;

	enum pbstring = q{
    message ReservedWordTest {
        required bool notReservedWord;
    }
};
	assertThrown!DProtoSyntaxException(ParseProtoSchema("<none>", pbstring));
}

unittest
{
	// Issue #89
	import dproto.dproto;

	mixin ProtocolBufferFromString!q{
		message Test {
			repeated double id = 1 [packed = true];
		}

	};

    Test t;

    t.id = [123];

    auto s = t.serialize();
    t = Test(s);

    assert(t.id == [123]);
}

unittest
{
    // Issue #92
    import dproto.dproto : ProtocolBufferFromString;
    import dproto.parse : ParseProtoSchema;

    enum syntaxProto2 = `
        syntax = "proto2";
    `;
	static assert(__traits(compiles, ProtocolBufferFromString!syntaxProto2));

    enum schemaProto2 = ParseProtoSchema("<none>", syntaxProto2);
    static assert(schemaProto2.syntax == `"proto2"`);

    enum syntaxProto3 = `
        syntax = "proto3";
    `;
	static assert(__traits(compiles, ProtocolBufferFromString!syntaxProto3));

    enum schemaProto3 = ParseProtoSchema("<none>", syntaxProto3);
    static assert(schemaProto3.syntax == `"proto3"`);

    enum syntaxNoEquals = `
        syntax "proto2";
    `;
	static assert(!__traits(compiles, ProtocolBufferFromString!syntaxNoEquals));

    enum syntaxNoQuotes = `
        syntax = proto2;
    `;
	static assert(!__traits(compiles, ProtocolBufferFromString!syntaxNoQuotes));

    enum syntaxNoLQuote = `
        syntax = proto2";
    `;
	static assert(!__traits(compiles, ProtocolBufferFromString!syntaxNoLQuote));

    enum syntaxNoRQuote = `
        syntax = "proto2;
    `;
	static assert(!__traits(compiles, ProtocolBufferFromString!syntaxNoRQuote));

    enum syntaxNoSemicolon = `
        syntax = "proto2"
    `;
	static assert(!__traits(compiles, ProtocolBufferFromString!syntaxNoSemicolon));
}

unittest
{
	// Issue #26
	import dproto.parse;
	import dproto.exception;
	import std.exception;

	enum pbstring = q{
	import public;
};
	mixin ProtocolBufferFromString!pbstring;
}

unittest
{
	// Issue #26
	import dproto.parse;
	import dproto.exception;
	import std.exception;

	enum pbstring = q{
	import public "proto/example.proto";
};
	assert(ParseProtoSchema("<none>", pbstring).toD());
}

unittest
{
	import dproto.parse;
	import dproto.exception;
	import std.exception;

	enum pbstring = q{
	enum Foo {
		option allow_alias = false;
		ONE = 1;
		TWO = 1;
		THREE = 3;
	}
};
	assertThrown!DProtoSyntaxException(ParseProtoSchema("<none>", pbstring));

	enum pbstring2 = q{
	enum Foo {
		ONE = 1;
		TWO = 1;
		THREE = 3;
	}
};
	assertNotThrown!DProtoSyntaxException(ParseProtoSchema("<none>", pbstring2));
}

unittest
{
	// Issue #92

	import dproto.parse;
	import dproto.exception;
	import std.exception;

	enum pbstring = `
		syntax = "proto3";
	`;
	assertNotThrown!DProtoSyntaxException(ParseProtoSchema("<none>", pbstring));
}

