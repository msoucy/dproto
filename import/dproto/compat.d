/*******************************************************************************
 * Compatibility layer for different D/Phobos versions
 *
 * Authors: Matthew Soucy, dproto@msoucy.me
 */
module dproto.compat;

// nogc compat shim using UDAs (@nogc must appear as function prefix)
static if (__VERSION__ < 2066) enum nogc;

enum DPROTO_PROTOBUF_VERSION = 2.2;
