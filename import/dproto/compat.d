/*******************************************************************************
 * Compatibility layer for different D/Phobos versions
 *
 * Authors: Matthew Soucy, msoucy@csh.rit.edu
 * Date: Oct 28, 2015
 * Version: 1.3.2
 */
module dproto.compat;

// nogc compat shim using UDAs (@nogc must appear as function prefix)
static if (__VERSION__ < 2066) enum nogc;

static if (__VERSION__ < 2068) {
	// Code from std.traits
	// Distributed under the Boost Software License
	// See http://www.boost.org/LICENSE_1_0.txt
	import std.typetuple : staticMap;
	import std.traits : isNested;
	//Required for FieldNameTuple
	private enum NameOf(alias T) = T.stringof;

	/**
	 * Get as an expression tuple the names of the fields of a struct, class, or
	 * union. This consists of the fields that take up memory space, excluding the
	 * hidden fields like the virtual function table pointer or a context pointer
	 * for nested types. If $(D T) isn't a struct, class, or union returns an
	 * expression tuple with an empty string.
	 */
	template FieldNameTuple(T)
	{
		static if (is(T == struct) || is(T == union))
			alias FieldNameTuple = staticMap!(NameOf, T.tupleof[0 .. $ - isNested!T]);
		else static if (is(T == class))
			alias FieldNameTuple = staticMap!(NameOf, T.tupleof);
		else
			alias FieldNameTuple = TypeTuple!"";
	}
}
