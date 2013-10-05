/*******************************************************************************
 * Main library import for dproto
 *
 * Provides accessors for D string and D structs from proto files/data
 *
 * Authors: Matthew Soucy, msoucy@csh.rit.edu
 * Date: Mar 19, 2013
 * Version: 0.0.1
 */
module metus.dproto.dproto;

public import metus.dproto.buffers;
public import metus.dproto.exception;
public import metus.dproto.parse;
public import metus.dproto.serialize;

import std.string : endsWith;
import std.exception : enforce;

/*******************************************************************************
 * Create structures from proto data
 *
 * Creates all required structs given a valid proto file/data string
 */
template ProtocolBuffer(string s) {
	mixin(ProtocolBufferString!s);
}

/*******************************************************************************
 * Create D structure strings from proto data
 *
 * Creates the code for all structs given a valid proto file/data string
 */
template ProtocolBufferString(string s) {
	static if(s.endsWith(".proto")) {
		enum ProtocolBufferString = ParseProtoSchema(s,import(s)).toD();
	} else {
		enum ProtocolBufferString = ParseProtoSchema("<none>",s).toD();
	}
}
