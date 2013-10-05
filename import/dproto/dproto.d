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

/*******************************************************************************
 * Create structures from proto data
 *
 * Creates all required structs given a valid proto file/data string
 */
template ProtocolBuffer(string s)
{
	import std.exception : enforce;
	import dproto.buffers;
	import dproto.exception;
	import dproto.serialize;

	mixin(ProtocolBufferString!s);
}

/*******************************************************************************
 * Create D structure strings from proto data
 *
 * Creates the code for all structs given a valid proto file/data string
 */
template ProtocolBufferString(string s)
{
	import std.string : endsWith;
	import dproto.parse;

	static if(s.endsWith(".proto"))
		enum ProtocolBufferString = ParseProtoSchema(s,import(s)).toD();
	else
		enum ProtocolBufferString = ParseProtoSchema("<none>",s).toD();
}
