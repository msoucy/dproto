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

package:

alias Options = string[string];

struct MessageType {
	this(string name) {
		this.name = name;
	}
	string name;
	Options options;
	Field[] fields;
	EnumType[] enumTypes;
	MessageType[] messageTypes;

	string toProto() @property {
		string ret;
		ret ~= "message %s {".format(name);
		foreach(opt, val;options) {
			ret ~= "option %s = %s;".format(opt, val);
		}
		if(fields) {
			ret ~= fields.map!(a=>a.toProto())().join();
		}
		ret ~= enumTypes.map!(a=>a.toProto())().join("\n");
		ret ~= messageTypes.map!(a=>a.toProto())().join("\n");
		ret ~= "}";
		return ret;
	}

	string toD() {
        string enumTypeD;
        string messageTypesD;
        string fieldsD;
        string fieldsIssetValueD;
        string fieldsSerializeD;
        string fieldsSerializeJsonD;
        string fieldsCheckValueD;
        string fieldsCaseD;
        version(GNU)
        {
            foreach(a; enumTypes)
            {
                enumTypeD ~= a.toD();
            }

            foreach(a; messageTypes)
            {
                messageTypesD ~= a.toD();
            }

            string[] fieldsArrD;
            string[] fieldsIssetValueArrD;
            string[] fieldsSerializeArrD;
            string[] fieldsSerializeJsonArrD;
            string[] fieldsCheckValueArrD;
            string[] fieldsCaseArrD;
            foreach(a; fields)
            {
                fieldsArrD ~= a.getDeclaration();
                fieldsSerializeArrD ~= a.name~".serialize()";
                fieldsSerializeJsonArrD ~= "ret.object[\""~a.name~"\"] = "~a.name~".serializeToJson();";
                if (a.requirement == Field.Requirement.REQUIRED)
                {
                    fieldsIssetValueArrD ~= "bool "~a.name~"_isset = false;";
                    fieldsCheckValueArrD ~= a.getCheck();
                }
                fieldsCaseArrD ~= a.getCase();
            }
            fieldsD = fieldsArrD.join("\n\t");
            fieldsSerializeJsonD = fieldsSerializeJsonArrD.join("\n\t\t");
            fieldsSerializeD = fieldsSerializeArrD.join(" ~ ");
            fieldsIssetValueD = fieldsIssetValueArrD.join("\n\t\t");
            fieldsCheckValueD = fieldsCheckValueArrD.join("\n\t\t");
            fieldsCaseD = fieldsCaseArrD.join("\n\t\t\t\t");
        } 
        else 
        {
            enumTypeD = enumTypes.map!(a=>a.toD())().join();
            messageTypesD = messageTypes.map!(a=>a.toD())().join();
            fieldsD = fields.map!(a=>a.getDeclaration())().join("\n\t");
            fieldsSerializeD = fields.map!(a=>a.name~".serialize()")().join(" ~ ");
            fieldsIssetValueD = fields.filter!(a=>a.requirement==Field.Requirement.REQUIRED)().map!(a=>"bool "~a.name~"_isset = false;")().join("\n\t\t");
            fieldsCheckValueD = fields.filter!(a=>a.requirement==Field.Requirement.REQUIRED)().map!(a=>a.getCheck())().join("\n\t\t");
            fieldsCaseD = fields.map!(a=>a.getCase())().join("\n\t\t\t\t");
            fieldsSerializeJsonD = fields.map!(a=> "ret.object[\""~a.name~"\"] = "~a.name~".serializeToJson();")().join("\n\t\t");
        }
        return `struct %s {
	%s
	%s
    %s

	ubyte[] serialize() {
		return %s;
	}

    JSONValue serializeToJson() {
        JSONValue ret;
        ret.type = JSON_TYPE.OBJECT;
        %s
        return ret;
    }

	void deserialize(ubyte[] data) {
		// Required flags
		%s

		while(data.length) {
			auto msgdata = data.readVarint();
			switch(msgdata.msgNum()) {
				%s
				default: {
					/// @todo: Safely ignore unrecognized messages
					defaultDecode(msgdata, data);
					break;
				}
			}
		}

		// Check required flags
		%s
	}

	this(ubyte[] data) {
		deserialize(data);
	}
}`.format(
			name,            
            enumTypeD,
            messageTypesD,
            fieldsD,
            fieldsSerializeD,
            fieldsSerializeJsonD,
            fieldsIssetValueD,
            fieldsCaseD,
            fieldsCheckValueD
		);
	}
}

struct EnumType {
	this(string name) {
		this.name = name.idup;
	}
	string name;
	Options options;
	int[string] values;

	string toProto() @property {
		string ret;
		ret ~= "enum %s {".format(name);
		ret ~= "%(%s%)".format(options);
		foreach(key, val;values) {
			ret ~= "%s = %s;".format(key, val);
		}
		ret ~= "}";
		return ret;
	}
	string toD() @property {
		string members;
		foreach(key, val; values) {
			members ~= "%s = %s, ".format(key, val);
		}
		string ret = `enum %s {%s}
%s readProto(string T)(ref ubyte[] src) if(T == "%s") { return src.readVarint().to!(%s)(); }
JSONValue serializeToJson(%s src) { JSONValue ret; ret.type = JSON_TYPE.INTEGER; ret.integer = src; return ret; }
ubyte[] serialize(%s src) { return src.toVarint().dup; }`.format(name, members, name, name, name, name, name);
		return ret;
	}
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
	string toProto() @property {
		string ret;
		if(packageName) {
			ret ~= "package %s;".format(packageName);
		}
		foreach(dep;dependencies) {
			ret ~= `import "%s";`.format(dep);
		}
		foreach(e;enumTypes) {
			ret ~= e.toProto();
		}
		foreach(msg;messageTypes) {
			ret ~= msg.toProto();
		}
		if(options) {
			ret ~= "%(%s%)".format(options);
		}
		return ret;
	}
	string toD() @property {
		string ret;
		foreach(dep;dependencies) {
			ret ~= "mixin ProtocolBuffer!\"%s\";\n".format(dep);
		}
		foreach(e;enumTypes) {
			ret ~= e.toD()~'\n';
		}
		foreach(msg;messageTypes) {
			ret ~= msg.toD()~'\n';
		}
		return ret;
	}
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
	string toProto() @property {
		return "%s %s %s = %s%s;".format(requirement.to!string().toLower(), type, name, id, options.length?" ["~options.to!string()~']':"");
	}
	string getDeclaration() {
		string ret;
		with(Requirement) final switch(requirement) {
			case OPTIONAL: ret ~= "Optional"; break;
			case REPEATED: ret ~= "Repeated"; break;
			case REQUIRED: ret ~= "Required"; break;
		}
		ret ~= `Buffer!(%s, "%s", `.format(id,type);
		if(IsBuiltinType(type)) {
			ret ~= `BuffType!"`~type~`"`;
		} else {
			ret ~= type;
		}
		if(auto dep = "deprecated" in options) {
			ret ~= ", "~(*dep);
		} else {
			ret ~= ", false";
		}
		if(requirement == Requirement.OPTIONAL) {
			if(auto dV = "default" in options) {
                string dVprefix;
                if (!IsBuiltinType(type)) {
                    //only enums
                    dVprefix = type~".";
                }

    			ret ~= ", "~(dVprefix)~(*dV);
			} else if (IsBuiltinType(type)) {
				ret ~= `, (BuffType!"%s").init`.format(type);
            } else {
                ret ~= `, %s.init`.format(type);
            }
		} else if(requirement == Requirement.REPEATED) {
			auto packed = "packed" in options;
			if(packed !is null && *packed == "true") {
				ret ~= ", true";
			} else {
				ret ~= ", false";
			}
		}
		ret ~= `) %s;`.format(name);
		return ret;
	}
	string getCase() {
		if(requirement == Requirement.REQUIRED) {
			return "case %s: {%s.deserialize(msgdata, data);%s_isset = true;break;}".format(id.to!string(), name, name);
		} else {
			return "case %s: {%s.deserialize(msgdata, data);break;}".format(id.to!string(), name);
		}
	}

	string getCheck() {
		return `enforce(%s_isset, new DProtoException("Did not receive expected input %s"));`.format(name, name);
	}
}
