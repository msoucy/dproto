/*******************************************************************************
 * Main library import for dproto
 *
 * Provides accessors for D string and D structs from proto files/data
 *
 * Authors: Matthew Soucy, msoucy@csh.rit.edu
 * Date: Oct 5, 2013
 * Version: 0.0.2
 */
module dproto.dproto;

import std.exception : enforce;
import std.array;
import std.range;

/*******************************************************************************
 * Create D structures from proto file
 *
 * Creates all required structs given a valid proto file
 *
 * Assumes that the file can be found in the string imports
 */
template ProtocolBuffer(string s)
{
	import dproto.buffers;
	import dproto.exception;
	import dproto.serialize;
	import dproto.parse;
	import std.range;
	mixin(ParseProtoSchema(s,import(s)).toD());
}

/*******************************************************************************
 * Create D structure strings from proto data
 *
 * Creates all required structs given a valid proto definition as a string
 */
template ProtocolBufferFromString(string s)
{
	import dproto.buffers;
	import dproto.exception;
	import dproto.serialize;
	import dproto.parse;
	import std.range;
	mixin(ParseProtoSchema("<none>",s).toD());
}

unittest
{
    assert(__traits(compiles,ProtocolBufferFromString!"message Test
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

    t.name = "Max Musterman";
    assert(t.name == "Max Musterman");

    t.id = 3;
    assert(t.id == 3);

    t.email = "Max.Musterman@example.com";
    assert(t.email == "Max.Musterman@example.com");
    assert(t.email.exists());

    Person.PhoneNumber pn1;
    pn1.number = "0123456789";
    assert(pn1.number == "0123456789");
    assert(pn1.type == PhoneType.HOME);
    assert(pn1.type == PhoneType.MOBILE);

    pn1.type = PhoneType.WORK;
    assert(pn1.type == PhoneType.WORK);
    assert(pn1.type == 2);
    assert(pn1.type.exists());

    t.phone ~= pn1;
    assert(t.phone[0] == pn1);
    assert(t.phone.length == 1);

    pn1.type.clean();
    assert(pn1.type == PhoneType.HOME);

    t.phone.clean();
    assert(t.phone.length == 0);

    t.email.clean();
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
	assert(t.email == "Max.Musterman@example.com");
	assert(t.email.exists());

	Person.PhoneNumber pn1;
	pn1.number = "0123456789";
	assert(pn1.number == "0123456789");

	t.phone ~= pn1;
	assert(t.phone[0] == pn1);
	assert(t.phone.length == 1);

	t.phone.clean();
	assert(t.phone.length == 0);

	t.email.clean();
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

	AddressBook addressbook2 = AddressBook(serializedObject);
	assert(addressbook2.person.length == 2);
	foreach (t2; addressbook2.person[0..1])
	{
		assert(t2.name == "Max Musterman");
		assert(t2.id == 3);
		assert(t2.email == "test@example.com");
		assert(t2.email.exists());
		assert(t2.phone[0].number == "0123456789");
		assert(t2.phone[0].type == PhoneType.WORK);
		assert(t2.phone[1].number == "0123456789");
		assert(t2.phone[1].type == PhoneType.HOME);
		assert(t2.phone[1].type == PhoneType.MOBILE);
		assert(t2.phone.length == 2);
	}
	//the gdc-4.8 evaluates false here. Maybe an compiler bug.
	version(DigitalMars)
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
	assert(t.email == "Max.Musterman@example.com");
	assert(t.email.exists());

	Person.PhoneNumber pn1;
	pn1.number = "0123456789";
	assert(pn1.number == "0123456789");
	assert(pn1.type == Person.PhoneType.HOME);
	assert(pn1.type == Person.PhoneType.MOBILE);

	pn1.type = Person.PhoneType.WORK;
	assert(pn1.type == Person.PhoneType.WORK);
	assert(pn1.type == 2);
	assert(pn1.type.exists());

	t.phone ~= pn1;
	assert(t.phone[0] == pn1);
	assert(t.phone.length == 1);

	pn1.type.clean();
	assert(pn1.type == Person.PhoneType.HOME);

	t.phone.clean();
	assert(t.phone.length == 0);

	t.email.clean();
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
		void put(in ubyte) {}
		void put(in ubyte[]) {}
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

	static auto rvalue(in ubyte[] val) { return val; }

	enum data = cast(ubyte[])[1 << 3 | 2, "abc".length] ~ cast(ubyte[])"abc";
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
	import dproto.buffers;
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
}
