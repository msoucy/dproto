#!/usr/bin/env dub
/+ dub.sdl:
	name "dproto_simple"
	description "A simple dproto example with proto file support"
	dependency "dproto" path=".."
	author "Bjarne Leif Bruhn"
	author "Matt Soucy"
	stringImportPaths "proto"
+/

/*******************************************************************************
 * An simple example for dproto
 *
 * Authors: Bjarne Leif Bruhn
 * Date: Nov 24, 2013
 * Version: 1.0.0
 */

import std.stdio;
import dproto.dproto;

mixin ProtocolBuffer!"person.proto";


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
