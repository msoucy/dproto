/*******************************************************************************
 * User-Defined Attributes used to tag fields as dproto-serializable
 *
 * Authors: Matthew Soucy, msoucy@csh.rit.edu
 * Date: May 6, 2015
 * Version: 0.0.2
 */
module dproto.attributes;

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
