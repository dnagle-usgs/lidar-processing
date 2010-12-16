// vim: set ts=3 sts=3 sw=3 ai sr et:

require, "eaarl.i";

local json_i;
/* DOCUMENT json_i
   
   Implements JSON support in Yorick.

   json2yorick converts a JSON string to a Yorick data structure. Some
   important caveats:
      - When a JSON array contains a mixture of items that cannot be
        represented by a Yorick array, it will be represented by a Yorick list.
        See help, _lst;
      - Yeti hashes are used instead of structs. Structs cannot be constructed
        on the fly, plus they cannot hold complex or hierarchical data.
      - If a number can be represented as a long, it is. Otherwise, it's a
        double.

   yorick2json converts a Yorick data structure to a JSON string.

   Important note:
      If you round trip something through json2yorick and yorick2json (in
      either direction), you will probably not get exactly the same result!
      This is due to limitations in the way Yorick can represent data. You will
      probably encounter unwanted type and structure conversions, including
      struct -> hash and array -> list. Data saved to then loaded from JSON may
      require postprocessing to put in a more useful/efficient format.
*/

// Original David Nagle for ADAPT, imported to ALPS 2009-02-02

/*
   The json2yorick func is based largely on the json parser in TclLib:
   http://tcllib.cvs.sourceforge.net/tcllib/tcllib/modules/json/json.tcl?revision1.2&view=markup
*/

func json2yorick(text) {
/* DOCUMENT json2yorick(text)

   DEPRECATED: Use json_decode instead.

   Parses text, which should be a valid JSON string. Returns the data structure
   represented by text.

   Objects "{ ... }" are turned into Yeti hash objects. See help, h_new.

   Arrays "[ ... ]" are turned into Yorick list objects. See help, _lst. (Lists
   are used instead of arrays since arrays can't handle a lot of the data types
   that may be encountered.)

   Numbers are converted into integers if they do not contain a decimal.
   Otherwise they are converted into doubles.

   Strings are converted to strings. Backspace substition is performed, except
   for unicode escapes which are not yet implemented.

   The bare word "true" is converted to 1, "false" to 0, and "null" to [].
*/
   return json_decode(text, arrays=["json_ary2array", "json_ary2list"],
      objects="json_obj2hash");
}

func yorick2json(data, compact=) {
/* DOCUMENT yorick2json(data, compact=)

   DEPRECATED: Use json_encode instead.

   Given a Yorick variable, this will convert it to a JSON string.

   If compact=1, then the resulting string will be compact--meaning, it will
   contain no extraneous spaces or newlines. Otherwise (by default), it will be
   laid out with spaces and newlines for easier reading. Both forms represent
   the same data.
*/
   if(compact)
      return json_encode(data, separators=[",",":"]);
   else
      return json_encode(data, indent=2);
}
