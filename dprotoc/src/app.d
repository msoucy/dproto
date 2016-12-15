import std.range;
import std.algorithm;
import std.getopt;
import std.stdio;
import std.string;
import dproto.parse;
import dproto.intermediate;
import std.format;

auto openFileComplex(string fn, string mode)
{
    if (fn == "-")
    {
        return (mode == "r") ? stdin : stdout;
    }
    else
    {
        return File(fn, mode);
    }
}

void main(string[] args)
{
    string infile = "-";
    string outfile = "-";
	char syntx = 'd';
	int  servicetype = 1;
    auto helpInformation = getopt(
			args,
			"out|o", "Output filename (default stdout)", &outfile,
			"syntx|s", "code generation syntx. it should be : \n\t\t\td : dlang file; \n\t\t\ts : dlang code string;\n\t\t\tp : protobuf file.",&syntx,
			"type|t", "what dlang file or code string will create service to. it should be :\n\t\t\t1 : interface N { R metond(P);}\n\t\t\t2 : interface N { void metond(const P, ref R);}\n\t\t\t3 : class N { R metond(P){R res;return res;}}",&servicetype
	);
    if (helpInformation.helpWanted)
    {
        defaultGetoptPrinter(
				"Protocol Buffer D generator",
				helpInformation.options);
		return;
    }
    ProtoPackage pack;
	{
		File inf;
		if(args.length == 2) {
			inf = openFileComplex(args[1], "r");
		} else {
			inf = openFileComplex(infile, "r");
		}
		pack = ParseProtoSchema(infile, inf.byLine.join("\n").idup);
	}
	auto file = openFileComplex(outfile, "w");

	ProtoConfig fmt;
	fmt.rpc = servicetype;
	final switch(syntx){
		case 'p':
			fmt.type = ProtoConfig.Type.Proto;
			break;
		case 's' :
			fmt.type = ProtoConfig.Type.Dcode;
			break;
		case 'd' :
			fmt.type = ProtoConfig.Type.Dfile;
			break;
	}

	Appender!string buffer;
	pack.toString((const(char)[] data){buffer.put(data);},fmt);
	file.write(buffer.data);
}
