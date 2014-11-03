/*******************************************************************************
 * Intermediate structures used for generating class strings
 *
 * These are only used internally, so are not being exported
 *
 * Authors: Matthew Soucy, msoucy@csh.rit.edu
 * Date: Oct 5, 2013
 * Version: 0.0.2
 */
module dproto.intermediate;

import dproto.serialize;

import std.algorithm;
import std.conv;
import std.string;
import std.format;

package:

struct Options {
	string[string] raw;
	alias raw this;
	const void toString(scope void delegate(const(char)[]) sink, FormatSpec!char fmt)
	{
		if(!raw.length) return;
		sink.formattedWrite(" [%-(%s = %s%|, %)]", raw);
	}
}

struct MessageType {
	this(string name) {
		this.name = name;
	}
	string name;
	Options options;
	Field[] fields;
	EnumType[] enumTypes;
	MessageType[] messageTypes;

	const void toString(scope void delegate(const(char)[]) sink, FormatSpec!char fmt)
	{
		if(fmt.spec == 'p') {
			sink.formattedWrite("message %s { ", name);
			foreach(opt, val; options) {
				sink.formattedWrite("option %s = %s; ", opt, val);
			}
		} else {
			sink.formattedWrite("struct %s { ", name);
		}
		foreach(et; enumTypes) sink.formatValue(et, fmt);
		foreach(mt; messageTypes) sink.formatValue(mt, fmt);
		foreach(field; fields) sink.formatValue(field, fmt);
		if(fmt.spec != 'p') {
			// Serialize function
			sink("ubyte[] serialize() { return ");
			sink.formattedWrite("%-(%s.serialize()%| ~ %)", fields.map!(a=>a.name));
			sink("; } ");
			// Deserialize function
			sink("void deserialize(ubyte[] data) {");
			foreach(f; fields.filter!(a=>a.requirement==Field.Requirement.REQUIRED)) {
				sink.formattedWrite("bool %s_isset = false; ", f.name);
			}
			sink("while(data.length) { auto msgdata = data.readVarint(); switch(msgdata.msgNum()) {");
			foreach(f; fields) { f.getCase(sink); }
			/// @todo: Safely ignore unrecognized messages
			sink("default: { defaultDecode(msgdata, data); break; } ");
			// Close the while and switch
			sink("} } ");
			// Check the required flags
			foreach(f; fields.filter!(a=>a.requirement==Field.Requirement.REQUIRED)) {
				f.getCheck(sink);
			}
			sink("} this(ubyte[] data) { deserialize(data); }");
		}
		sink("} ");
	}

	string toProto() @property const { return "%p".format(this); }
	string toD() @property const { return "%s".format(this); }
}

struct EnumType {
	this(string name) {
		this.name = name.idup;
	}
	string name;
	Options options;
	int[string] values;

	const void toString(scope void delegate(const(char)[]) sink, FormatSpec!char fmt)
	{
		sink.formattedWrite("enum %s {", name);
		switch(fmt.spec) {
			case 'p':
				foreach(opt, val; options) {
					sink.formattedWrite("option %s = %s; ", opt, val);
				}
				foreach(key, val; values) {
					sink.formattedWrite("%s = %s; ", key, val);
				}
				sink("}");
				break;
			default:
				foreach(key, val; values) {
					sink.formattedWrite("%s = %s, ", key, val);
				}
				sink("} ");
				sink(name);
				sink(` readProto(string T)(ref ubyte[] src) `);
				sink.formattedWrite(`if(T == "%s")`, name);
				sink.formattedWrite(`{ return src.readVarint().to!(%s)(); }`, name);
				sink.formattedWrite(`ubyte[] serialize(%s src) `, name);
				sink(`{ return src.toVarint().dup; }`);
				break;
		}
	}

	string toProto() @property const { return "%p".format(this); }
	string toD() @property const { return "%s".format(this); }
}

struct Option {
	this(string name, string value) {
		this.name = name.idup;
		this.value = value.idup;
	}
	string name;
	string value;
}

struct Extension {
	ulong minVal = 0;
	ulong maxVal = ulong.max;
}

struct ProtoPackage {
	this(string fileName) {
		this.fileName = fileName.idup;
	}
	string fileName;
	string packageName;
	string[] dependencies;
	EnumType[] enumTypes;
	MessageType[] messageTypes;
	Options options;

	const void toString(scope void delegate(const(char)[]) sink, FormatSpec!char fmt)
	{
		if(fmt.spec == 'p') {
			if(packageName) {
				sink.formattedWrite("package %s; ", packageName);
			}
			foreach(dep; dependencies) {
				sink.formattedWrite("import %s; ");
			}
		} else {
			foreach(dep;dependencies) {
				sink.formattedWrite(`mixin ProtocolBuffer!"%s";`, dep);
			}
		}
		foreach(e; enumTypes) sink.formatValue(e, fmt);
		foreach(m; messageTypes) sink.formatValue(m, fmt);
		if(fmt.spec == 'p') {
			foreach(opt, val; options) {
				sink.formattedWrite("option %s = %s; ", opt, val);
			}
		}
	}

	string toProto() @property const { return "%p".format(this); }
	string toD() @property const { return "%s".format(this); }
}

struct Field {
	enum Requirement {
		OPTIONAL,
		REPEATED,
		REQUIRED
	}
	this(Requirement labelEnum, string type, string name, uint tag, Options options) {
		this.requirement = labelEnum;
		this.type = type;
		this.name = name;
		this.id = tag;
		this.options = options;
	}
	Requirement requirement;
	string type;
	string name;
	uint id;
	Options options;

	const void toString(scope void delegate(const(char)[]) sink, FormatSpec!char fmt)
	{
		switch(fmt.spec) {
			case 'p':
				sink.formattedWrite("%s %s %s = %s%p; ",
						requirement.to!string.toLower(),
						type, name, id, options);
				break;
			default:
				getDeclaration(sink);
				break;
		}
	}

	string toProto() @property const { return "%p".format(this); }
	void getDeclaration(scope void delegate(const(char)[]) sink) const {
		sink(requirement.to!string.capitalize());
		sink.formattedWrite(`Buffer!(%s, "%s", `, id, type);
		if(IsBuiltinType(type)) {
			sink.formattedWrite(`BuffType!"%s"`, type);
		} else {
			sink(type);
		}
		sink(", ");
		sink(options.get("deprecated", "false"));
		if(requirement == Requirement.OPTIONAL) {
			sink(", ");
			if(auto dV = "default" in options) {
				if(!IsBuiltinType(type)) {
					sink.formattedWrite("%s.", type);
				}
				sink(*dV);
			} else {
				if(IsBuiltinType(type)) {
					sink.formattedWrite(`(BuffType!"%s")`, type);
				} else {
					sink.formattedWrite("%s", type);
				}
				sink(".init");
			}
		} else if(requirement == Requirement.REPEATED) {
			sink(", ");
			sink(options.get("packed", "true"));
		}
		sink.formattedWrite(") %s; ", name);
	}
	void getCase(scope void delegate(const(char)[]) sink) const {
		sink.formattedWrite("case %s: { %s.deserialize(msgdata, data); ", id, name);
		if(requirement == Requirement.REQUIRED) {
			sink.formattedWrite("%s_isset = true; ", name);
		}
		sink("break; } ");
	}

	void getCheck(scope void delegate(const(char)[]) sink) const {
		sink.formattedWrite(
				`enforce(%s_isset, new DProtoException(`
				`"Did not receive expected input %s"));`, name, name);
	}
}
