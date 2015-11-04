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
