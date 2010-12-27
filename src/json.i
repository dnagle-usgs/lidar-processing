// vim: set ts=3 sts=3 sw=3 ai sr et:

require, "eaarl.i";

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
   return json_decode(text, arrays=["json_ary2array", "json_ary2list"]);
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
