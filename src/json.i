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

local __json_debug;
/* DOCUMENT __json_debug
   Enabled JSON debug mode. Set to 1 or higher and it will output debug info
   with increasing levels of verbosity. Only implemented in selected portions
   of the code, as needed.
*/
if(is_void(__json_debug)) {
   __json_debug = 0;
}

func __json_dbug(state, c, message, lvl=) {
/* DOCUMENT __json_dbug, state, c, message, lvl=
   Outputs debug information, if __json_debug is >= lvl.
      state = Current state.
      c = Current character in buffer.
      message = A message to output. Optional.
      lvl = Debug level to display at. Default is 1.
*/
   extern __json_debug;
   default, message, "";
   default, lvl, 1;
   if(__json_debug >= lvl)
      write, format="[%s] \"%s\" %s\n", state, c, message;
}

func __json_getc(&text) {
/* DOCUMENT __json_getc, text
   Pops off and returns the first character of text (altering text in place).
*/
   if(strlen(text) == 0) {
      error, "Unexpected end of text.";
   }
   c = strpart(text, :1);
   text = strpart(text, 2:);
   return c;
}

func json2yorick(text) {
/* DOCUMENT json2yorick(text)
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
   yor = __json2yorick(text);
   if(strlen(text)) {
      c = strpart(text, :1);
      while(regmatch("^[ \t\r\n]+$", c)) {
         __json_getc, text;
         c = strpart(text, :1);
      }
      if(strlen(text))
         error, "Unexpected trailing characters:\n" + text;
   }
   return yor;
}

func __json2yorick(&text) {
   extern __json_debug;

   // No text = no json
   if(numberof(text) < 1) {
      return [];
   }
   // Merge multilines together
   if(numberof(text) > 1) {
      // Merges with no space:
      //text = text(sum);
      // Merges with space:
      text = (text + "\n")(sum);
   }
   // No text = no json
   if(strlen(text) < 1) {
      return [];
   }

   state = "TOP";

   listval = hashval = name = str = [];

   while(strlen(text) > 0) {
      c = strpart(text, :1);

      // Skip whitespace
      while(regmatch("^[ \t\r\n]+$", c)) {
         __json_getc, text;
         c = strpart(text, :1);
      }

      if(c == "{") {
         __json_dbug, state, c, "branch {";
         if(state == "TOP") {
            // It's an object
            __json_getc, text;
            state = "OBJECT";
            hashval = h_new();
         } else if(state == "VALUE") {
            // This object element's value is an object
            h_set, hashval, name, __json2yorick(text);
            state = "COMMA";
         } else if(state == "LIST") {
            // Next element of the list is an object
            listval = _cat(listval, 0);
            _car, listval, _len(listval), __json2yorick(text);
            state = "COMMA";
         } else {
            error, "Unexpected open brace in " + state + "mode.";
         }
      } else if(c == "}") {
         __json_dbug, state, c, "branch }";
         __json_getc, text;
         if(state != "OBJECT" && state != "COMMA") {
            error, "Unexpected close brace in " + state + "mode.";
         }
         return hashval;
      } else if(c == ":") {
         __json_dbug, state, c, "branch :";
         // name separator
         __json_getc, text;
         if(state == "COLON") {
            state = "VALUE";
         } else {
            error, "Unexpected colon in " + state + " mode.";
         }
      } else if(c == ",") {
         __json_dbug, state, c, "branch ,";
         // element separator
         if(state == "COMMA") {
            __json_getc, text;
            if(!is_void(listval)) {
               state = "LIST";
            } else if(!is_void(hashval)) {
               state = "OBJECT";
            }
         } else {
            error, "Unexpected comma in " + state + " mode.";
         }
      } else if(c == "\"") { // workaround for vim: "
         __json_dbug, state, c, "branch \" "; //"
         // string
         // capture quoted string with backslash sequences
         restr = "^\"([^\\\"]*(\\\\.)*)*\"";  // for vim:  "]) "" )
         if(! regmatch(restr, text, str)) {
            error, "Invalid formatted string in " + strpart(text, :32) + "...";
         }
         text = strpart(text, strlen(str)+1:);
         // chop off outer ""
         str = strpart(str, 2:-1);

         // backslash substition
         str = regsub("\\\\\\\\", str, "\\\\", all=1);
         str = regsub("\\\\\"", str, "\"", all=1);
         str = regsub("\\\\/", str, "/", all=1);
         str = regsub("\\\\b", str, "\b", all=1);
         str = regsub("\\\\f", str, "\f", all=1);
         str = regsub("\\\\n", str, "\n", all=1);
         str = regsub("\\\\r", str, "\r", all=1);
         str = regsub("\\\\t", str, "\t", all=1);

         // NOTE: Does not handle unicode sequences, \x####
         
         if(state == "TOP") {
            return str;
         } else if(state == "OBJECT") {
            name = str;
            state = "COLON";
         } else if(state == "LIST") {
            listval = _cat(listval, 0);
            _car, listval, _len(listval), str;
            state = "COMMA";
         } else if(state == "VALUE") {
            h_set, hashval, name, str;
            name = [];
            state = "COMMA";
         }
      } else if(c == "[") {
         __json_dbug, state, c, "branch [";
         // JSON array -> Yorick _lst
         // Can't use real array because we don't know type info, and it
         // might be nested with hashes
         if(state == "TOP") {
            __json_getc, text;
            state = "LIST";
         } else if(state == "LIST") {
            listval = _cat(listval, 0);
            _car, listval, _len(listval), __json2yorick(text);
            state = "COMMA";
         } else if(state == "VALUE") {
            h_set, hashval, name, __json2yorick(text);
            state = "COMMA";
         } else {
            error, "Unexpected open bracket in " + state + " mode.";
         }
      } else if(c == "]") {
         __json_dbug, state, c, "branch ]";
         // end of list
         __json_getc, text;
         return list2array(listval, strict=1);
//      } else if(c == "/") {  // comments -- not implemented
      } else if(regmatch("[-0-9]", c)) {
         __json_dbug, state, c, "branch numeric";
         // end of list
         // numbers
         // extract number portion
         restr = "^-?(0|[1-9][0-9]*)(\\.[0-9]+)?([eE][-+]?[0-9]+)?";
         num = [];
         if(regmatch(restr, text, num)) {
            __json_dbug, state, c, "extracted " + num, lvl=2;
            text = strpart(text, strlen(num)+1:);
            // convert textual number to numeric number
            // then typecast to int or double
            // initial conversion must be to double, because atoi won't
            // handle the "E" or "e" forms
            temp_num = atod(num);
            __json_dbug, state, c, "to double: " + swrite(format="%.16g", temp_num), lvl=2;
            if(regmatch("\\.", num)) {
               num = temp_num;
               __json_dbug, state, c, "stored as double: " + swrite(format="%.16g", num), lvl=2;
            } else {
               num = long(temp_num);
               __json_dbug, state, c, "stored as long: " + swrite(format="%d", num), lvl=2;
            }
            if(state == "TOP") {
               return num;
            } else if(state == "LIST") {
               listval = _cat(listval, 0);
               _car, listval, _len(listval), num;
               state = "COMMA";
            } else if(state == "VALUE") {
               h_set, hashval, name, num;
               state = "COMMA";
            } else {
               __json_getc, text;
               error, "Unexpected '" + c + "' in " + state + " mode.";
            }
         } else {
            __json_dbug, state, c, "nothing extracted", lvl=2;
            __json_getc, text;
            error, "Unexpected '" + c + "' in " + state + " mode.";
         }
      } else if(regmatch("^(true|false|null)", text, val)) {
         __json_dbug, state, c, "branch bareword";
         // bare word value: true | false | null
         // val -> word, text -> rest of it
         text = strpart(text, strlen(val)+1:);
         __json_dbug, state, c, "extracted bareword: " + val, lvl=2;
         val = h_new(true=1, false=0, null=[])(val);
         if(state == "TOP") {
            return val;
         } else if(state == "LIST") {
            listval = _cat(listval, 0);
            _car, listval, _len(listval), val;
            state = "COMMA";
         } else if(state == "VALUE") {
            h_set, hashval, name, val;
            state = "COMMA";
         } else {
            __json_getc, text;
            error, "Unexpected '" + c + "' in " + state + " mode.";
         }
      } else {
         error, "Unexpected '" + c + "' in " + state + " mode.";
      }
   }
}

func yorick2json(data, compact=) {
/* DOCUMENT yorick2json(data, compact=)
   Given a Yorick variable, this will convert it to a JSON string.

   If compact=1, then the resulting string will be compact--meaning, it will
   contain no extraneous spaces or newlines. Otherwise (by default), it will be
   laid out with spaces and newlines for easier reading. Both forms represent
   the same data.
*/
   if(is_void(data))
      return "null";

   typelist = ["builtin", "pointer", "function", "stream", "text_stream",
      "complex"];
   if(regmatch("^" + typeof(data) + "$", typelist)(sum)) {
      error, "Unsupported data type: " + typeof(data);
   }

   if(typeof(data) == "struct_instance")
      data = struct2hash(data);

   if(numberof(data) && dimsof(data)(1))
      return __array2json(data, compact);

   if(typeof(data) == "short")
      return swrite(format="%d", data);
   if(typeof(data) == "int")
      return swrite(format="%d", data);
   if(typeof(data) == "long")
      return swrite(format="%d", data);
   if(typeof(data) == "char")
      return swrite(format="%d", data);
   if(typeof(data) == "float")
      return swrite(format="%.8g", data);
   if(typeof(data) == "double")
      return swrite(format="%.16g", data);
   if(typeof(data) == "string")
      return __string2json(data);

   if(typeof(data) == "list")
      return __list2json(data, compact);

   if(typeof(data) == "hash_table")
      return __hash2json(data, compact);
}

func __string2json(str) {
   // backslash substition
   str = regsub("\\\\", str, "\\\\\\\\", all=1);
   str = regsub("\"", str,  "\\\\\"", all=1);
   str = regsub("/", str, "\\\\/", all=1);
   str = regsub("\b", str, "\\\\b", all=1);
   str = regsub("\f", str, "\\\\f", all=1);
   str = regsub("\n", str, "\\\\n", all=1);
   str = regsub("\r", str, "\\\\r", all=1);
   str = regsub("\t", str, "\\\\t", all=1);
   return "\"" + str + "\"";
}

func __array2json(ary, compact) {
/* DOCUMENT __array2json(ary, compact)
   Handles conversion of arrays to json.
*/
   type = typeof(ary);
   if(type == "short")
      ary = swrite(format="%d", ary);
   if(type == "int")
      ary = swrite(format="%d", ary);
   if(type == "long")
      ary = swrite(format="%d", ary);
   if(type == "char")
      ary = swrite(format="%d", ary);
   if(type == "float")
      ary = swrite(format="%.8e", ary);
   if(type == "double")
      ary = swrite(format="%.16e", ary);
   if(type == "string")
      ary = __string2json(ary);

   return __array2json_helper(ary, compact);
}

func __json_join(elements, compact) {
   if(compact) {
      joined = strjoin(elements, ",");
   } else {
      joined = strjoin(elements, ", ");
      if(strlen(joined) != strlen(strtrim(strindent(joined, " ")))) {
         // contains newlines, thus, we should indent
         joined = "\n" + strindent(strjoin(elements, ",\n"), "  ") + "\n";
      } else if(strlen(joined) > 72) {
         subarray = strpart(elements, :1) == "[";
         subhash = strpart(elements, :1) == "{";
         if(anyof(subarray) || anyof(subhash)) {
            joined = "\n" + strindent(strjoin(elements, ",\n"), "  ") + "\n";
         } else {
            joined = "\n" + strindent(strwrap(joined, width=68), "  ") + "\n";
         }
      }
   }
   return joined;
}

func __array2json_helper(ary, compact) {
   if(dimsof(ary)(1) > 1) {
      ret = array(string, dimsof(ary)(0));
      for(i = 1; i <= numberof(ret); i++) {
         ret(i) = __array2json_helper(ary(..,i), compact);
      }
      ary = ret;
   }
   joined = __json_join(unref(ary), compact);
   return "[" + joined + "]";
}

func __list2json(list, compact) {
/* DOCUMENT __list2json(list, compact)
   Handles conversion of lists to json.
*/
   out = array(string, _len(list));
   for(i = 1; i <= _len(list); i++) {
      out(i) = yorick2json(_car(list, i), compact=compact);
   }
   joined = __json_join(unref(out), compact);
   return "[" + joined + "]";
}

func __hash2json(hash, compact) {
/* DOCUMENT __hash2json(hash, compact)
   Handles conversion of hashes to json.
*/
   keys = h_keys(hash);
   if(!numberof(keys))
      return compact ? "{}" : "{ }";
   keys = keys(sort(keys));
   out = array(string, numberof(keys));
   fmt = compact ? "\"%s\":%s" : "\"%s\": %s";
   for(i = 1; i <= numberof(keys); i++) {
      out(i) = swrite(format=fmt,
         keys(i),
         yorick2json(hash(keys(i)), compact=compact)
      );
   }
   joined = __json_join(unref(out), compact);
   return "{" + joined + "}";
}
