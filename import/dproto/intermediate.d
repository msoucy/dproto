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

struct ProtoConfig{
	enum Type{
		Proto,
		Dcode,
		Dfile
	}
	Type type = Type.Dcode;
	int rpc = 1;
}

struct ProtoPackage {
	this(string fileName) {
		this.fileName = fileName.idup;
	}
	string fileName;
	string packageName;
	Dependency[] dependencies;
	EnumType[] enumTypes;
	MessageType[] messageTypes;
	Options options;
	Service[] rpcServices;
	string syntax = "proto2";
	
	const void toString(scope void delegate(const(char)[]) sink,ProtoConfig fmt = ProtoConfig())
	{
		if(fmt.type  == ProtoConfig.Type.Proto) {
			if(packageName) {
				sink.formattedWrite("package %s; \n\n", packageName);
			}
			if(syntax != "proto2") {
				sink.formattedWrite(`syntax = %s; \n`, syntax);
			}
		}else if(fmt.type  == ProtoConfig.Type.Dfile){
			if(packageName) {
				sink.formattedWrite("module %s; \n\n", packageName);
			}
			sink("import std.range;\nimport dproto.serialize;\n");
		}
		foreach(dep; dependencies) {
			dep.toString(sink, fmt);
			sink("\n");
		}
		sink("\n");
		foreach(e; enumTypes){ e.toString(sink, fmt);sink("\n");}
		foreach(m; messageTypes){ m.toString(sink, fmt); sink("\n");}
		foreach(r; rpcServices){r.toString(sink, fmt);sink("\n");}
		if(fmt.type  == ProtoConfig.Type.Proto) {
			foreach(opt, val; options) {
				sink.formattedWrite("option %s = %s; \n", opt, val);
			}
		}
	}
	
	string toProto() @property const { 
		import std.array;
		Appender!string data = appender!string();
		ProtoConfig fmt;
		fmt.type = ProtoConfig.Type.Proto;
		toString((const(char)[] str){data.put(str);},fmt);
		return data.data;
	}
	string toD() @property const { 
		import std.array;
		Appender!string data = appender!string();
		toString((const(char)[] str){data.put(str);});
		return data.data;
	}
}


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
			sink.formattedWrite(`["dproto_generated": "true"%(, %s : %s%)]`, raw);
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

	const void toString(scope void delegate(const(char)[]) sink, ref ProtoConfig fmt)
	{
		if(fmt.type  == ProtoConfig.Type.Proto) {
			sink.formattedWrite("message %s { ", name);
			foreach(opt, val; options) {
				sink.formattedWrite("\toption %s = %s; ", opt, val);
			}
		} else {
			sink.formattedWrite("static struct %s {\n", name);

			// Methods for serialization and deserialization.
			sink("\tstatic import dproto.attributes;\n\t");
			sink(`mixin dproto.attributes.ProtoAccessors;`);
			sink("\n");
		}
		foreach(et; enumTypes){sink("\n");et.toString(sink, fmt);}
		foreach(mt; messageTypes){sink("\n"); mt.toString(sink, fmt);}
		foreach(field; fields){sink("\n"); field.toString(sink, fmt);}
		sink("}\n");
	}

	string toD() @property const {return "%s".format(this); }
}

struct EnumType {
	this(string name) {
		this.name = name.idup;
	}
	string name;
	Options options;
	int[string] values;

	const void toString(scope void delegate(const(char)[]) sink, ref ProtoConfig  fmt)
	{
		sink.formattedWrite("enum %s {\n", name);
		string suffix = ", ";
		if(fmt.type  == ProtoConfig.Type.Proto) {
			foreach(opt, val; options) {
				sink.formattedWrite("\toption %s = %s; \n", opt, val);
			}
			suffix = "; ";
		}
		foreach(key, val; values) {
			sink.formattedWrite("\t%s = %s%s \n", key, val, suffix);
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

struct Dependency {
	this(string depname, bool isPublic = false) {
		this.name = depname;
		this.isPublic = isPublic;
	}
	string name;
	bool isPublic;

	const void toString(scope void delegate(const(char)[]) sink,ref ProtoConfig fmt)
	{
		if(fmt.type  == ProtoConfig.Type.Proto) {
			sink("import ");
			if(isPublic) {
				sink("public ");
			}
		   sink.formattedWrite(`"%s"; `, name);
		} else if(fmt.type  == ProtoConfig.Type.Dfile){
			sink("\n//NOTE: please change your import module.\n");
			if(isPublic) {
				sink("public ");
			}
			sink.formattedWrite(`import "%s"; `, name);
		} else {
			sink.formattedWrite(`mixin ProtocolBuffer!"%s";`, name);
		}
	}

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

	const void toString(scope void delegate(const(char)[]) sink, ref ProtoConfig fmt)
	{
		if(fmt.type  == ProtoConfig.Type.Proto){
			sink.formattedWrite("\t%s %s %s = %s%p; \n",
			requirement.to!string.toLower(),
			type, name, id, options);
		} else {
			getDeclaration(sink);
		}
	}

	void getDeclaration(scope void delegate(const(char)[]) sink) const {
		if(requirement == Requirement.REQUIRED) {
			sink("\t@(dproto.attributes.Required())\n");
		} else if(requirement == Requirement.REPEATED) {
			if(options.get("packed", "false") != "false") {
				sink("\t@(dproto.attributes.Packed())\n");
			}
		}
		sink("\t@(dproto.attributes.ProtoField");
		sink.formattedWrite(`("%s", %s)`, type, id);
		sink(")\n");

		bool wrap_with_nullable =
			requirement == Requirement.OPTIONAL &&
			! type.isBuiltinType();

		if(wrap_with_nullable) {
			sink("\t");
			sink(`dproto.serialize.PossiblyNullable!(`);
		}
		string typestr = type;
		if(type.isBuiltinType) {
			typestr = format(`BuffType!"%s"`, type);
		}
		if(!wrap_with_nullable)
			sink("\t");
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

		const void toString(scope void delegate(const(char)[]) sink, ref ProtoConfig  fmt)
		{
			if(fmt.type  == ProtoConfig.Type.Proto){
				sink.formattedWrite("\trpc %s (%s) returns (%s)", name, requestType, responseType);
				if(options.length > 0) {
					sink(" {\n");
					foreach(opt, val; options) {
						sink.formattedWrite("\toption %s = %s;\n", opt, val);
					}
					sink("}\n");
				} else {
					sink(";\n");
				}
			} else {
				if(fmt.rpc == 3) {
					sink.formattedWrite("\t%s %s (%s) { %s res; return res; }\n", responseType, name, requestType, responseType);
				} else if(fmt.rpc == 2) {
					sink.formattedWrite("\tvoid %s (const %s, ref %s);\n", name, requestType, responseType);
				} else if(fmt.rpc == 1) {
					sink.formattedWrite("\t%s %s (%s);\n", responseType, name, requestType);
				}
			}
		}
	}

	const void toString(scope void delegate(const(char)[]) sink, ref ProtoConfig fmt)
	{
		if(fmt.type  == ProtoConfig.Type.Proto){
				sink.formattedWrite("service %s {\n", name);
		} else {
			if(fmt.rpc == 3) {
					sink.formattedWrite("class %s {\n", name);
			} else if(fmt.rpc == 2 || fmt.rpc == 1) {
				sink.formattedWrite("interface %s {\n", name);
			} else {
				return;
			}
		}
		foreach(m; rpc) m.toString(sink, fmt);
		sink("}\n");
	}
}
