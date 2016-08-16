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

import dproto.attributes;
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
		if(fmt.spec == 'p') {
			if(!raw.length) return;
			sink.formattedWrite(" [%-(%s = %s%|, %)]", raw);
		} else {
			sink.formattedWrite(`["dprotoGenerated": "true"%(, %s : %s%)]`, raw);
		}
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
			sink.formattedWrite("static struct %s {\n", name);

			// Methods for serialization and deserialization.
			sink("static import dproto.attributes;\n");
			sink(`mixin dproto.attributes.ProtoAccessors;`);
		}
		foreach(et; enumTypes) et.toString(sink, fmt);
		foreach(mt; messageTypes) mt.toString(sink, fmt);
		foreach(field; fields) field.toString(sink, fmt);
		sink("}\n");
	}

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
		sink.formattedWrite("enum %s {\n", name);
		string suffix = ", ";
		if(fmt.spec == 'p') {
			foreach(opt, val; options) {
				sink.formattedWrite("option %s = %s; ", opt, val);
			}
			suffix = "; ";
		}
		foreach(key, val; values) {
			sink.formattedWrite("%s = %s%s", key, val, suffix);
		}
		sink("}\n");
	}

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
	string syntax;
	string[] dependencies;
	EnumType[] enumTypes;
	MessageType[] messageTypes;
	Options options;
	Service[] rpcServices;

	const void toString(scope void delegate(const(char)[]) sink, FormatSpec!char fmt)
	{
		if(fmt.spec == 'p') {
			if(packageName) {
				sink.formattedWrite("package %s; ", packageName);
			}
			foreach(dep; dependencies) {
                               sink.formattedWrite(`import "%s"; `, dep);
			}
		} else {
			foreach(dep;dependencies) {
				sink.formattedWrite(`mixin ProtocolBuffer!"%s";`, dep);
			}
		}
		foreach(e; enumTypes) e.toString(sink, fmt);
		foreach(m; messageTypes) m.toString(sink, fmt);
		foreach(r; rpcServices) r.toString(sink, fmt);
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

	const bool hasDefaultValue() {
		return null != ("default" in options);
	}
	const string defaultValue() {
		return options["default"];
	}

	const void toString(scope void delegate(const(char)[]) sink, FormatSpec!char fmt)
	{
		switch(fmt.spec) {
			case 'p':
				if(fmt.width == 3 && requirement != Requirement.REPEATED) {
					sink.formattedWrite("%s %s = %s%p; ",
						type, name, id, options);
				}
				else {
					sink.formattedWrite("%s %s %s = %s%p; ",
						requirement.to!string.toLower(),
						type, name, id, options);
				}
				break;
			default:
				if(!fmt.flDash) {
					getDeclaration(sink);
				} else {
					sink.formattedWrite("%s %s;\n",
						type, name);
				}
				break;
		}
	}

	void getDeclaration(scope void delegate(const(char)[]) sink) const {
		if(requirement == Requirement.REQUIRED) {
			sink("@(dproto.attributes.Required())\n");
		} else if(requirement == Requirement.REPEATED) {
			if(options.get("packed", "false") != "false") {
				sink("@(dproto.attributes.Packed())\n");
			}
		}
		sink("@(dproto.attributes.ProtoField");
		sink.formattedWrite(`("%s", %s)`, type, id);
		sink(")\n");

		bool wrap_with_nullable =
			requirement == Requirement.OPTIONAL &&
			! type.isBuiltinType();

		if(wrap_with_nullable) {
			sink(`dproto.serialize.PossiblyNullable!(`);
		}
		string typestr = type;
		if(type.isBuiltinType) {
			typestr = format(`BuffType!"%s"`, type);
		}

		sink(typestr);

		if(wrap_with_nullable) {
			sink(`)`);
		}
		if(requirement == Requirement.REPEATED) {
			sink("[]");
		}
		sink.formattedWrite(" %s", name);
		if (requirement != Requirement.REPEATED) {
			if (hasDefaultValue) {
				sink.formattedWrite(`= SpecifiedDefaultValue!(%s, "%s")`, typestr, defaultValue);
			} else if(type.isBuiltinType || ! wrap_with_nullable) {
				sink.formattedWrite("= UnspecifiedDefaultValue!(%s)", typestr);
			}
		}
		sink(";\n\n");
	}
	void getCase(scope void delegate(const(char)[]) sink) const {
		sink.formattedWrite("case %s:\n", id);
		sink.formattedWrite("%s.deserialize(__msgdata, __data);\n", name);
		if(requirement == Requirement.REQUIRED) {
			sink.formattedWrite("%s_isset = true;\n", name);
		}
		sink("break;\n");
	}
}


struct Service {
	this(string name) {
		this.name = name.idup;
	}
	string name;
	Options options;
	Method[] rpc;

	struct Method {
		this(string name, string documentation, string requestType, string responseType) {
			this.name = name.idup;
			this.documentation = documentation.idup;
			this.requestType = requestType.idup;
			this.responseType = responseType.idup;
		}
		string name;
		string documentation;
		string requestType;
		string responseType;
		Options options;

		const void toString(scope void delegate(const(char)[]) sink, FormatSpec!char fmt)
		{
			switch(fmt.spec) {
				case 'p':
					sink.formattedWrite("rpc %s (%s) returns (%s)", name, requestType, responseType);
					if(options.length > 0) {
						sink(" {\n");
						foreach(opt, val; options) {
							sink.formattedWrite("option %s = %s;\n", opt, val);
						}
						sink("}\n");
					} else {
						sink(";\n");
					}
					break;
				default:
					if(fmt.precision == 3) {
						sink.formattedWrite("%s %s (%s) { %s res; return res; }\n", responseType, name, requestType, responseType);
					} else if(fmt.precision == 2) {
						sink.formattedWrite("void %s (const %s, ref %s);\n", name, requestType, responseType);
					} else if(fmt.precision == 1) {
						sink.formattedWrite("%s %s (%s);\n", responseType, name, requestType);
					}
					break;
			}
		}
	}

	const void toString(scope void delegate(const(char)[]) sink, FormatSpec!char fmt)
	{
		switch(fmt.spec) {
			case 'p':
				sink.formattedWrite("service %s {\n", name);
				break;
			default:
				if(fmt.precision == 3) {
					sink.formattedWrite("class %s {\n", name);
				} else if(fmt.precision == 2 || fmt.precision == 1) {
					sink.formattedWrite("interface %s {\n", name);
				} else {
					return;
				}
				break;
		}
		foreach(m; rpc) m.toString(sink, fmt);
		sink("}\n");
	}
}
