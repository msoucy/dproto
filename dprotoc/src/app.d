module dproto.app;

import std.range;
import std.algorithm;
import std.getopt;
import std.stdio;
import std.string;
import dproto.parse;
import dproto.intermediate;

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
    string fmt = "%d";
    auto helpInformation = getopt(
			args,
			"out|o", "Output filename (default stdout)", &outfile,
			"format|f", "Code generation format", &fmt,
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
    openFileComplex(outfile, "w").write(fmt.format(pack));
}
