import std.range;
import std.algorithm;
import std.getopt;
import std.stdio;
import dproto.parse;

auto openFileComplex(string fn, string mode) {
	if(fn == "-") {
		return (mode=="r") ? stdin : stdout;
	} else {
		return File(fn, mode);
	}
}

void main(string[] args)
{
	string infile = "-";
	string outfile = "-";
	getopt(args,
			"in", &infile,
			"out", &outfile);
	auto inf = openFileComplex(infile, "r");
	auto of = openFileComplex(outfile, "w");
	of.write(ParseProtoSchema(infile, inf.byLine.join("").idup));
	inf.close();
	of.close();
}
