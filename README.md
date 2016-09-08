# D Protocol Buffers

----

[![Build Status](https://travis-ci.org/msoucy/dproto.svg?branch=master)](https://travis-ci.org/msoucy/dproto)
[![Coverage Status](https://coveralls.io/repos/msoucy/dproto/badge.svg?branch=master)](https://coveralls.io/r/msoucy/dproto)
[![DUB](https://img.shields.io/dub/dt/dproto/latest.svg)](http://code.dlang.org/packages/dproto)
[![DUB license](https://img.shields.io/dub/l/dproto.svg)](http://code.dlang.org/packages/dproto)
[![Stories in progress](https://badge.waffle.io/msoucy/dproto.png?label=in%20progress&title=In%20Progress)](https://waffle.io/msoucy/dproto)

Protocol buffers are a language-agnostic way of specifying message structures to allow communication and serialization.

`dproto` is designed to enable mixing protocol buffer files into your D code at compile time.

Inspiration and a good portion of the original parser is adapted from [square/protoparser](http://github.com/square/protoparser)

----

# Options

`dproto` supports altering behavior via `protobuf` options:

| Option                | Meaning                                                | Example                                      | Default |
|-----------------------|--------------------------------------------------------|----------------------------------------------|---------|
| `dproto_reserved_fmt` | The format for renaming reserved D keywords as fields. | `"%s_"` will convert `version` to `version_` | `"%s_"` |

----

# Examples

[Further info](https://developers.google.com/protocol-buffers/docs/overview)

Examples can be found in `import/dproto/dproto.d` and in `examples/`.

## Simple Example

```d
import std.stdio;
import dproto.dproto;

mixin ProtocolBufferFromString!"
	message Person {
	  required string name = 1;
	  required int32 id = 2;
	  optional string email = 3;

	  enum PhoneType {
		MOBILE = 0;
		HOME = 1;
		WORK = 2;
	  }

	  message PhoneNumber {
		required string number = 1;
		optional PhoneType type = 2 [default = HOME];
	  }

	  repeated PhoneNumber phone = 4;
	}
";


int main()
{
	Person person;
	person.name = "John Doe";
	person.id = 1234;
	person.email = "jdoe@example.com";

	ubyte[] serializedObject = person.serialize();

	Person person2 = Person(serializedObject);
	writeln("Name: ", person2.name);
	writeln("E-mail: ", person2.email);
	return 0;
}
```

## More Complex Example

```d
import dproto.dproto;

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


int main()
{
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
	foreach(t2; addressbook2.person)
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
	version(DigitalMars)
	{
		assert(addressbook2.person[0] == addressbook.person[1]);
	}
	return 0;
}
```


## Services

Generate interfaces for service definitions.

```d
import dproto.dproto;

mixin ProtocolBufferInterface!"
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

class ServiceImplementation : TestService {
	ServiceResponse TestMethod(ServiceRequest input) {
		ServiceResponse output;
		output.response = "received: " ~ input.request;
		return output;
	}
}
```
