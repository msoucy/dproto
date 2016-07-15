/*******************************************************************************
 * Convert a .proto file into a string representing the class
 *
 * Author: Matthew Soucy, msoucy@csh.rit.edu
 * Date: Oct 5, 2013
 * Version: 0.0.2
 */
module dproto.parse;

import dproto.exception;
import dproto.intermediate;
static import dproto.serialize;

import std.algorithm;
import std.array;
import std.conv;
import std.exception;
import std.stdio;
import std.string;
import std.format;
import std.traits;

/**
 * Basic parser for {@code .proto} schema declarations.
 *
 * <p>This parser throws away data that it doesn't care about. In particular,
 * unrecognized options, and extensions are discarded. It doesn't retain nesting
 * within types.
 */
ProtoPackage ParseProtoSchema(const string name_, string data_) {

	struct ProtoSchemaParser {

		/** The path to the {@code .proto} file. */
		string fileName;

		/** The entire document. */
		const char[] data;

		/** Our cursor within the document. {@code data[pos]} is the next character to be read. */
		int pos;

		/** The number of newline characters encountered thus far. */
		int line;

		/** The index of the most recent newline character. */
		int lineStart;


		ProtoPackage readProtoPackage() {
			auto ret = ProtoPackage(fileName);
			while (true) {
				readDocumentation();
				if (pos == data.length) {
					return ret;
				}
				readDeclaration(ret);
			}
		}

		this(string _fileName, string _data)
		{
			fileName = _fileName;
			data = _data;
		}

	private:

		void readDeclaration(Context, string ContextName = Context.stringof)(ref Context context) {
			// Skip unnecessary semicolons, occasionally used after a nested message declaration.
			if (peekChar() == ';') {
				pos++;
				return;
			}

			string label = readWord();

			switch(label) {
				case "package": {
					static if(is(Context==ProtoPackage)) {
						unexpected(context.packageName == null, "too many package names");
						context.packageName = readSymbolName();
						unexpected(readChar() == ';', "Expected ';'");
						return;
					} else {
						throw new DProtoSyntaxException("package in " ~ ContextName);
					}
				}
				case "import": {
					static if(is(Context==ProtoPackage)) {
						context.dependencies ~= readQuotedPath ();
						unexpected(readChar() == ';', "Expected ';'");
						return;
					} else {
						throw new DProtoSyntaxException("import in " ~ ContextName);
					}
				}
				case "option": {
					Option result = readOption('=');
					unexpected(readChar() == ';', "Expected ';'");
					context.options[result.name] = result.value;
					return;
				}
				case "message": {
					static if(hasMember!(Context, "messageTypes")) {
						context.messageTypes ~= readMessage();
						return;
					} else {
						throw new DProtoSyntaxException("message in " ~ ContextName);
					}
				}
				case "enum": {
					static if(hasMember!(Context, "enumTypes")) {
						context.enumTypes ~= readEnumType();
						return;
					} else {
						throw new DProtoSyntaxException("enum in " ~ ContextName);
					}
				}
				case "extend": {
					readExtend();
					return;
				}
				case "service": {
					static if(hasMember!(Context, "rpcServices")) {
						context.rpcServices ~= readService();
						return;
					} else {
						throw new DProtoSyntaxException("service in " ~ ContextName);
					}
				}
				case "rpc": {
					static if( hasMember!(Context, "rpc")) {
						context.rpc ~= readRpc();
						return;
					} else {
						throw new DProtoSyntaxException("rpc in " ~ ContextName);
					}
				}
				case "required":
				case "optional":
				case "repeated": {
					static if( hasMember!(Context, "fields") ) {
						string type = readSymbolName();
						context.fields ~= readField(label, type);
						return;
					} else {
						throw new DProtoSyntaxException("Fields must be nested");
					}
				}
				case "extensions": {
					static if(!is(Context==ProtoPackage)) {
						readExtensions();
						return;
					} else {
						throw new DProtoSyntaxException("Extensions must be nested");
					}
				}
				default: {
					static if(is(Context==EnumType)) {
						unexpected(readChar() == '=', "Expected '='");
						int tag = readInt();
						unexpected(readChar() == ';', "Expected ';'");
						context.values[label] = tag;
						return;
					} else {
						static if( hasMember!(Context, "fields") ) {
							if(dproto.serialize.isBuiltinType(label)) {
								context.fields ~= readField("optional", label);
								return;
							}
						}
						throw new DProtoSyntaxException("unexpected label: " ~ label);
					}
				}
			}
		}

		/** Reads a message declaration. */
		MessageType readMessage() {
			auto ret = MessageType(readSymbolName());
			unexpected(readChar() == '{', "Expected '{'");
			while (true) {
				readDocumentation();
				if (peekChar() == '}') {
					pos++;
					break;
				}
				readDeclaration(ret);
			}
			return ret;
		}

		/** Reads an extend declaration (just ignores the content).
			@todo */
		void readExtend() {
			readName(); // Ignore this for now
			unexpected(readChar() == '{', "Expected '{'");
			while (true) {
				readDocumentation();
				if (peekChar() == '}') {
					pos++;
					break;
				}
				//readDeclaration();
			}
			return;
		}

		/** Reads a service declaration and returns it. */
		Service readService() {
			string name = readSymbolName();
			auto ret = Service(name);

			Service.Method[] methods = [];
			unexpected(readChar() == '{', "Expected '{'");
			while (true) {
				readDocumentation();
				if (peekChar() == '}') {
					pos++;
					break;
				}
				readDeclaration(ret);
			}
			return ret;
		}


		/** Reads an rpc method and returns it. */
		Service.Method readRpc() {
			string documentation = "";
			string name = readSymbolName();

			unexpected(readChar() == '(', "Expected '('");
			string requestType = readSymbolName();
			unexpected(readChar() == ')', "Expected ')'");

			unexpected(readWord() == "returns", "Expected 'returns'");

			unexpected(readChar() == '(', "Expected '('");
			string responseType = readSymbolName();
			// @todo check for option prefixes, responseType is the last in the white spaced list
			unexpected(readChar() == ')', "Expected ')'");

			auto ret = Service.Method(name, documentation, requestType, responseType);

			/* process service options and documentation */
			if (peekChar() == '{') {
				pos++;
				while (true) {
					readDocumentation();
					if (peekChar() == '}') {
						pos++;
						break;
					}
					readDeclaration(ret);
				}
			}
			else if (readChar() != ';') {
				throw new DProtoSyntaxException("Expected ';'");
			}
			return ret;
		}

		/** Reads an enumerated type declaration and returns it. */
		EnumType readEnumType() {
			auto ret = EnumType(readSymbolName());
			unexpected(readChar() == '{', "Expected '{'");
			while (true) {
				readDocumentation();
				if (peekChar() == '}') {
					pos++;
					break;
				}
				readDeclaration(ret);
			}
			return ret;
		}

		/** Reads a field declaration and returns it. */
		Field readField(string label, string type) {
			Field.Requirement labelEnum = label.toUpper().to!(Field.Requirement)();
			string name = readSymbolName();
			unexpected(readChar() == '=', "Expected '='");
			int tag = readInt();
			enforce((0 < tag && tag < 19000) || (19999 < tag && tag < 2^^29),
					new DProtoSyntaxException(
						"Invalid tag number: "~tag.to!string()));
			char c = peekChar();
			Options options;
			if (c == '[') {
				options = readMap('[', ']', '=');
				c = peekChar();
			}
			if (c == ';') {
				pos++;
				return Field(labelEnum, type, name, tag, options);
			}
			throw new DProtoSyntaxException("Expected ';'");
		}

		/** Reads extensions like "extensions 101;" or "extensions 101 to max;".
			@todo */
		Extension readExtensions() {
			Extension ret;
			int minVal = readInt(); // Range start.
			if (peekChar() != ';') {
				readWord(); // Literal 'to'
				string maxVal = readWord(); // Range end.
				if(maxVal != "max") {
					if(maxVal[0..2] == "0x") {
						ret.maxVal = maxVal[2..$].to!uint(16);
					} else {
						ret.maxVal = maxVal.to!uint();
					}
				}
			} else {
				ret.minVal = minVal;
				ret.maxVal = minVal;
			}
			unexpected(readChar() == ';', "Expected ';'");
			return ret;
		}

		/** Reads a option containing a name, an '=' or ':', and a value. */
		Option readOption(char keyValueSeparator) {
			string name = readName(); // Option name.
			unexpected(readChar() == keyValueSeparator, "Expected '" ~ keyValueSeparator ~ "' in option");
			string value = (peekChar() == '{') ? readMap('{', '}', ':').to!string() : readString();
			return Option(name, value);
		}

		/**
		 * Returns a map of string keys and values. This is similar to a JSON object,
		 * with '{' and '}' surrounding the map, ':' separating keys from values, and
		 * ',' separating entries.
		 */
		Options readMap(char openBrace, char closeBrace, char keyValueSeparator) {
			unexpected(readChar() == openBrace, openBrace ~ " to begin map");
			Options result;
			while (peekChar() != closeBrace) {

				Option option = readOption(keyValueSeparator);
				result[option.name] = option.value;

				char c = peekChar();
				if (c == ',') {
					pos++;
				} else if (c != closeBrace) {
					throw new DProtoSyntaxException("Expected ',' or '" ~ closeBrace ~ "'");
				}
			}

			// If we see the close brace, finish immediately. This handles {}/[] and ,}/,] cases.
			pos++;
			return result;
		}

	private:

		/** Reads a non-whitespace character and returns it. */
		char readChar() {
			char result = peekChar();
			pos++;
			return result;
		}

		/**
		 * Peeks a non-whitespace character and returns it. The only difference
		 * between this and {@code readChar} is that this doesn't consume the char.
		 */
		char peekChar() {
			skipWhitespace(true);
			unexpected(pos != data.length, "unexpected end of file");
			return data[pos];
		}

		/** Reads a quoted or unquoted string and returns it. */
		string readString() {
			skipWhitespace(true);
			return peekChar() == '"' ? readQuotedString() : readWord();
		}

		string readQuotedString() {
			enforce(readChar() == '"', new DProtoSyntaxException(""));
			string result;
			while (pos < data.length) {
				char c = data[pos++];
				if (c == '"') return '"'~result~'"';

				if (c == '\\') {
					unexpected(pos != data.length, "unexpected end of file");
					c = data[pos++];
				}

				result ~= c;
				if (c == '\n') newline();
			}
			throw new DProtoSyntaxException("unterminated string");
		}

		string readQuotedPath() {
			skipWhitespace(true);
			unexpected(readChar() == '"', "imports should be quoted");
			auto ret = readWord(`a-zA-Z0-9_.\-/`);
			unexpected(readChar() == '"', "imports should be quoted");
			return ret;
		}

		/** Reads a (paren-wrapped), [square-wrapped] or naked symbol name. */
		string readName() {
			string optionName;
			char c = peekChar();
			if (c == '(') {
				pos++;
				optionName = readWord();
				unexpected(readChar() == ')', "Expected ')'");
			} else if (c == '[') {
				pos++;
				optionName = readWord();
				unexpected(readChar() == ']', "Expected ']'");
			} else {
				optionName = readWord();
			}
			return optionName;
		}

		/** Reads a symbol name */
		string readSymbolName() {
			string name = readWord();
			enforce(!isDKeyword(name), new DProtoReservedWordException(name));
			return name;
		}

		/** Reads a non-empty word and returns it. */
		string readWord(string pattern = `a-zA-Z0-9_.\-`) {
			skipWhitespace(true);
			int start = pos;
			while (pos < data.length) {
				char c = data[pos];
				if(c.inPattern(pattern)) {
					pos++;
				} else {
					break;
				}
			}
			unexpected(start != pos, "Expected a word");
			return data[start .. pos].idup;
		}

		/** Reads an integer and returns it. */
		int readInt() {
			string tag = readWord();
			try {
				int radix = 10;
				if (tag.startsWith("0x")) {
					tag = tag["0x".length .. $];
					radix = 16;
				}
				return tag.to!int(radix);
			} catch (Exception e) {
				throw new DProtoSyntaxException(
						"Expected an integer but was `" ~ tag ~ "`",
						e.msg);
			}
		}

		/**
		 * Like {@link #skipWhitespace}, but this returns a string containing all
		 * comment text. By convention, comments before a declaration document that
		 * declaration.
		 */
		string readDocumentation() {
			string result = null;
			while (true) {
				skipWhitespace(false);
				if (pos == data.length || data[pos] != '/') {
					return result != null ? cleanUpDocumentation(result) : "";
				}
				string comment = readComment();
				result = (result == null) ? comment : (result ~ "\n" ~ comment);
			}
		}

		/** Reads a comment and returns its body. */
		string readComment() {
			enforce(!(pos == data.length || data[pos] != '/'), new DProtoSyntaxException(""));
			pos++;
			int commentType = pos < data.length ? data[pos++] : -1;
			if (commentType == '*') {
				int start = pos;
				while (pos + 1 < data.length) {
					if (data[pos] == '*' && data[pos + 1] == '/') {
						pos += 2;
						return data[start .. pos - 2].idup;
					} else {
						char c = data[pos++];
						if (c == '\n') newline();
					}
				}
				throw new DProtoSyntaxException("unterminated comment");
			} else if (commentType == '/') {
				int start = pos;
				while (pos < data.length) {
					char c = data[pos++];
					if (c == '\n') {
						newline();
						break;
					}
				}
				return data[start .. pos - 1].idup;
			} else {
				throw new DProtoSyntaxException("unexpected '/'");
			}
		}

		/**
		 * Returns a string like {@code comment}, but without leading whitespace or
		 * asterisks.
		 */
		string cleanUpDocumentation(string comment) {
			string result;
			bool beginningOfLine = true;
			for (int i = 0; i < comment.length; i++) {
				char c = comment[i];
				if (!beginningOfLine || ! " \t*".canFind(c)) {
					result ~= c;
					beginningOfLine = false;
				}
				if (c == '\n') {
					beginningOfLine = true;
				}
			}
			return result.strip();
		}

		/**
		 * Skips whitespace characters and optionally comments. When this returns,
		 * either {@code pos == data.length} or a non-whitespace character.
		 */
		void skipWhitespace(bool skipComments) {
			while (pos < data.length) {
				char c = data[pos];
				if (" \t\r\n".canFind(c)) {
					pos++;
					if (c == '\n') newline();
				} else if (skipComments && c == '/') {
					readComment();
				} else {
					break;
				}
			}
		}

		/** Call this everytime a '\n' is encountered. */
		void newline() {
			line++;
			lineStart = pos;
		}

		void unexpected(bool value, string message)
		{
			if (!value)
			{
				new DProtoSyntaxException(
					"Syntax error in %s at %d:%d: %s".format(fileName, line + 1,
					(pos - lineStart + 1), message));
			}
		}

		/** Returns true if the name is a reserved word in D
		 *
		 * This will cause problems trying to use them as variables
		 * Note: Some keywords are specifically whitelisted,
		 * in order to allow usage of the protobuf names
		 */
		bool isDKeyword(string name)
		{
			// dfmt off
			enum KEYWORDS = [
				"abstract", "alias", "align", "asm", "assert", "auto",
				"body", /+ "bool", +/ "break", "byte",
				"case", "cast", "catch", "cdouble", "cent", "cfloat", "char", "class", "const", "continue", "creal",
				"dchar", "debug", "default", "delegate", "delete", "deprecated", "do", /+ "double", +/
				"else", "enum", "export", "extern",
				"false", "final", "finally", /+ "float", +/ "for", "foreach", "foreach_reverse", "function",
				"goto",
				"idouble", "if", "ifloat", "immutable", "import", "in", "inout", "int", "interface", "invariant", "ireal", "is",
				"lazy", "long",
				"macro", "mixin", "module",
				"new", "nothrow", "null",
				"out", "override",
				"package", "pragma", "private", "protected", "public", "pure",
				"real", "ref", "return",
				"scope", "shared", "short", "static", "struct", "super", "switch", "synchronized",
				"template", "this", "throw", "true", "try", "typedef", "typeid", "typeof",
				"ubyte", "ucent", "uint", "ulong", "union", "unittest", "ushort",
				"version", "void", "volatile",
				"wchar", "while", "with",
				"__FILE__", "__MODULE__", "__LINE__", "__FUNCTION__", "__PRETTY_FUNCTION__",
				"__gshared", "__traits", "__vector", "__parameters",
			];
			// dfmt on
			return KEYWORDS.canFind(name);
		}

	}

	return ProtoSchemaParser(name_, data_).readProtoPackage();

}

