/*******************************************************************************
 * Main library import for dproto
 *
 * Provides accessors for D string and D structs from proto files/data
 *
 * Authors: Matthew Soucy, dproto@msoucy.me
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
	import dproto.imports;
	mixin(ParseProtoSchema(s,import(s)).toD());
}

/*******************************************************************************
 * Create D structure strings from proto data
 *
 * Creates all required structs given a valid proto definition as a string
 */
template ProtocolBufferFromString(string s)
{
	import dproto.imports;
	mixin(ParseProtoSchema("<none>",s).toD());
}

template ProtocolBufferInterface(string s) {
	import dproto.imports;
	mixin("%3.1s".format(ParseProtoSchema("<none>",s)));
}

template ProtocolBufferRpc(string s) {
	import dproto.imports;
	mixin("%3.2s".format(ParseProtoSchema("<none>",s)));
}

template ProtocolBufferImpl(string s) {
	import dproto.imports;
	mixin("%3.3s".format(ParseProtoSchema("<none>",s)));
}

template ProtocolBufferStruct(string s) {
	import dproto.imports;
	mixin("%-3.1s".format(ParseProtoSchema("<none>",s)));
}

