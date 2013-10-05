/*******************************************************************************
 * Convert a .proto file into a string representing the class
 *
 * Author: Matthew Soucy, msoucy@csh.rit.edu
 * Date: Mar 20, 2013
 * Version: 0.0.1
 */
module dproto.parse;

import dproto.exception;
import dproto.intermediate;

import std.algorithm;
import std.array;
import std.conv;
import std.exception;
import std.stdio;
import std.string;
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
						enforce(context.packageName == null, unexpected("too many package names"));
						context.packageName = readName();
						enforce(readChar() == ';', unexpected("expected ';'"));
						return;
					} else {
						throw unexpected("package in " ~ ContextName);
					}
				}
				case "import": {
					static if(is(Context==ProtoPackage)) {
						context.dependencies ~= readString();
						enforce(readChar() == ';', unexpected("expected ';'"));
						return;
					} else {
						throw unexpected("import in " ~ ContextName);
					}
				}
				case "option": {
					Option result = readOption('=');
					enforce(readChar() == ';', unexpected("expected ';'"));
					context.options[result.name] = result.value;
					return;
				}
				case "message": {
					static if(hasMember!(Context, "messageTypes")) {
						context.messageTypes ~= readMessage();
						return;
					} else {
						throw unexpected("message in " ~ ContextName);
					}
				}
				case "enum": {
					static if(hasMember!(Context, "enumTypes")) {
						context.enumTypes ~= readEnumType();
						return;
					} else {
						throw unexpected("enum in " ~ ContextName);
					}
				}
				/+
				case "service": {
					readService();
					return;
				}
				+/
				case "extend": {
					readExtend();
					return;
				}
				/+
				case "rpc": {
					static if( hasMember!(Context, "rpc")) {
						readRpc();
						return;
					} else {
						throw unexpected("rpc in " ~ context)
					}
				}
				+/
				case "required":
				case "optional":
				case "repeated": {
					static if( hasMember!(Context, "fields") ) {
						context.fields ~= readField(label);
						return;
					} else {
						throw unexpected("fields must be nested");
					}
				}
				case "extensions": {
					static if(!is(Context==ProtoPackage)) {
						readExtensions();
						return;
					} else {
						throw unexpected("extensions must be nested");
					}
				}
				default: {
					static if(is(Context==EnumType)) {
						enforce(readChar() == '=', unexpected("expected '='"));
						int tag = readInt();
						enforce(readChar() == ';', unexpected("expected ';'"));
						context.values[label] = tag;
						return;
					} else {
						throw unexpected("unexpected label: " ~ label);
					}
				}
			}
		}

		/** Reads a message declaration. */
		MessageType readMessage() {
			auto ret = MessageType(readName());
			enforce(readChar() == '{', unexpected("expected '{'"));
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
			enforce(readChar() == '{', unexpected("expected '{'"));
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

		static if(0)
		/** Reads a service declaration and returns it.
			@todo */
		Service readService() {
			string name = readName();
			Service.Method[] methods = [];
			enforce(readChar() == '{', unexpected("expected '{'"));
			while (true) {
				string methodDocumentation = readDocumentation();
				if (peekChar() == '}') {
					pos++;
					break;
				}
				Object declared = readDeclaration(Context.SERVICE);
				if (cast(Service.Method)declared) {
					methods.add(cast(Service.Method) declared);
				}
			}
			return new Service(name, methods);
		}

		/** Reads an enumerated type declaration and returns it. */
		EnumType readEnumType() {
			auto ret = EnumType(readName());
			enforce(readChar() == '{', unexpected("expected '{'"));
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

		/** Reads an field declaration and returns it. */
		Field readField(string label) {
			Field.Requirement labelEnum = label.toUpper().to!(Field.Requirement)();
			string type = readName();
			string name = readName();
			enforce(readChar() == '=', unexpected("expected '='"));
			int tag = readInt();
			enforce((0 < tag && tag < 19000) || (19999 < tag && tag < 2^^29), new DProtoException("Invalid tag number: "~tag.to!string()));
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
			throw unexpected("expected ';'");
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
			enforce(readChar() == ';', unexpected("expected ';'"));
			return ret;
		}

		/** Reads a option containing a name, an '=' or ':', and a value. */
		Option readOption(char keyValueSeparator) {
			string name = readName(); // Option name.
			enforce(readChar() == keyValueSeparator, unexpected("expected '" ~ keyValueSeparator ~ "' in option"));
			string value = (peekChar() == '{') ? readMap('{', '}', ':').to!string() : readString();
			return Option(name, value);
		}

		/**
		 * Returns a map of string keys and values. This is similar to a JSON object,
		 * with '{' and '}' surrounding the map, ':' separating keys from values, and
		 * ',' separating entries.
		 */
		Options readMap(char openBrace, char closeBrace, char keyValueSeparator) {
			enforce(readChar() == openBrace, unexpected(openBrace ~ " to begin map"));
			Options result;
			while (peekChar() != closeBrace) {

				Option option = readOption(keyValueSeparator);
				result[option.name] = option.value;

				char c = peekChar();
				if (c == ',') {
					pos++;
				} else if (c != closeBrace) {
					throw unexpected("expected ',' or '" ~ closeBrace ~ "'");
				}
			}

			// If we see the close brace, finish immediately. This handles {}/[] and ,}/,] cases.
			pos++;
			return result;
		}

		static if(0)
		/** Reads an rpc method and returns it.
			@todo */
		Service.Method readRpc(string documentation) {
			string name = readName();

			enforce(readChar() == '(', unexpected("expected '('"));
			string requestType = readName();
			enforce(readChar() == ')', unexpected("expected ')'"));

			enforce(readWord() != "returns", unexpected("expected 'returns'"));

			enforce(readChar() == '(', unexpected("expected '('"));
			string responseType = readName();
			enforce(readChar() == ')', unexpected("expected ')'"));

			Option[] options = [];
			if (peekChar() == '{') {
				pos++;
				while (true) {
					string methodDocumentation = readDocumentation();
					if (peekChar() == '}') {
						pos++;
						break;
					}
					Object declared = readDeclaration(methodDocumentation, Context.RPC);
					if (cast(Option)declared) {
						Option option = cast(Option) declared;
						options.put(option.getName(), option.getValue());
					}
				}
			} else if (readChar() != ';') throw unexpected("expected ';'");

			return new Service.Method(name, documentation, requestType, responseType, options);
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
			enforce(pos != data.length, unexpected("unexpected end of file"));
			return data[pos];
		}

		/** Reads a quoted or unquoted string and returns it. */
		string readString() {
			skipWhitespace(true);
			return peekChar() == '"' ? readQuotedString() : readWord();
		}

		string readQuotedString() {
			enforce(readChar() == '"', new DProtoException(""));
			string result;
			while (pos < data.length) {
				char c = data[pos++];
				if (c == '"') return result;

				if (c == '\\') {
					enforce(pos != data.length, unexpected("unexpected end of file"));
					c = data[pos++];
				}

				result ~= c;
				if (c == '\n') newline();
			}
			throw unexpected("unterminated string");
		}

		/** Reads a (paren-wrapped), [square-wrapped] or naked symbol name. */
		string readName() {
			string optionName;
			char c = peekChar();
			if (c == '(') {
				pos++;
				optionName = readWord();
				enforce(readChar() == ')', unexpected("expected ')'"));
			} else if (c == '[') {
				pos++;
				optionName = readWord();
				enforce(readChar() == ']', unexpected("expected ']'"));
			} else {
				optionName = readWord();
			}
			return optionName;
		}

		/** Reads a non-empty word and returns it. */
		string readWord() {
			skipWhitespace(true);
			int start = pos;
			while (pos < data.length) {
				char c = data[pos];
				if(c.inPattern(`a-zA-Z0-9_.\-`)) {
					pos++;
				} else {
					break;
				}
			}
			enforce(start != pos, unexpected("expected a word"));
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
				throw unexpected("expected an integer but was " ~ tag);
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
			enforce(!(pos == data.length || data[pos] != '/'), new DProtoException(""));
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
				throw unexpected("unterminated comment");
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
				throw unexpected("unexpected '/'");
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

		Exception unexpected(string message) {
			throw new DProtoException("Syntax error in %s at %d:%d: %s"
					.format(fileName, line+1, (pos - lineStart + 1), message));
		}

	}

	return ProtoSchemaParser(name_, data_).readProtoPackage();

}
