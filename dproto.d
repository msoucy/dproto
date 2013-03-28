/**
 * @file dproto.d
 * @brief Main library import for dproto
 * @author Matthew Soucy <msoucy@csh.rit.edu>
 * @date Mar 19, 2013
 * @version 0.0.1
 */
/// D Protocol Buffer bindings
module metus.dproto.dproto;

public import metus.dproto.buffers;
public import metus.dproto.exception;
public import metus.dproto.parse;
public import metus.dproto.serialize;

import std.string : endsWith;
import std.exception : enforce;

template ProtocolBuffer(string s) {
	static if(s.endsWith(".proto")) {
		mixin(ProtoSchemaParser.parse(s,import(s)).toD());
	} else {
		mixin(ProtoSchemaParser.parse("<none>",s).toD());
	}
}
