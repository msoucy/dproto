#!/usr/bin/env dub
/+ dub.sdl:
	name "dproto_simple"
	description "A simple dproto example"
	dependency "dproto" path=".."
	author "Bjarne Leif Bruhn"
	author "Matt Soucy"
+/

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
