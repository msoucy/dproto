/*******************************************************************************
 * User-Defined Attributes used to tag fields as dproto-serializable
 *
 * Authors: Matthew Soucy, msoucy@csh.rit.edu
 * Date: May 6, 2015
 * Version: 1.3.0
 */
module dproto.attributes;

import std.traits;

struct ProtoField
{
	string wireType;
	uint fieldNumber;
	@disable this();
	this(string w, uint f) {
		wireType = w;
		fieldNumber = f;
	}
}

enum ProtoRequired;
