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
	mixin(ParseProtoSchema("<none>",s).toD());
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
    optional PhoneType type = 2 [default = PhoneType.HOME];
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
    optional PhoneType type = 2 [default = PhoneType.HOME];
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
    assert(addressbook2.person[0] == addressbook.person[1]);
    Person t2 = addressbook2.person[0];
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

    AddressBook addressbook;
    assert(addressbook.person.length == 0);
    addressbook.person ~= t;
    addressbook.person ~= t;
    assert(addressbook.person[0] == t);
    assert(addressbook.person[0] == addressbook.person[1]);
    assert(addressbook.person.length == 2);
}
