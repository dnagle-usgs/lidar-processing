// vim: set ts=3 sts=3 sw=3 ai sr et:
require, "eaarl.i";

func extract_qq(text) {
/* DOCUMENT extract_qq(text)

   Extract the quarter quad string from a text string. The text string will
   probably be a filename or similar. The expected rules it will follow:

   - The QQ name may be optionally preceeded by other text, but must be
     separated by an underscore if so.
   - The QQ name may be optionally followed by other text, but must be
     separated by either an underscore or a period if so.
   - The QQ name must be exactly 8 characters in length, and must use lowercase
     alpha instead of uppercase alpha where relevant.

   This function will work on scalars or arrays. The returned result will be
   the quarter quad name(s). If there is no quarter quad to extract, it will
   be string(0).
*/
//  Original David Nagle 2008-07-17
   regmatch, "(^|_|qq)([0-9][0-9][0-1][0-9][0-9][a-h][1-8][a-d])(\.|_|$)", text, , , qq;
   return qq;
}
