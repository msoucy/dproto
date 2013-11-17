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
