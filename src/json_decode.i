// vim: set ts=4 sts=4 sw=4 ai sr et:

// partially adapted from
// http://cpansearch.perl.org/src/MAKAMAKA/JSON-2.27/lib/JSON/PP.pm

scratch = save(scratch, tmp, _array, _string);
tmp = save(
        // data items
        escapes, bslash, fslash, dquote, lbrace, rbrace, lbracket, rbracket,
        minus, plus, digit, digit19, hexdigit,
        // functions
        render_position, decode_error, next_chr, value, hexdigits, escape,
        string, comment, white, array, object, apply_conversions, word, digits,
        number_int, number_frac, number_exp, number);

// For clarity's sake, a lot of character values are declared here with
// meaningful names. This also prevents vim from freaking out over some of the
// escape sequences.

// escapes(1,) -- a character we expect to find after a backslash
// escapes(2,) -- the character we want to replace the sequence with
escapes = [[0x22,0x22],     // \" quote
        [0x2f,0x2f],        // \/ forward slash
        [0x62,0x08],        // \b backspace
        [0x66,0x0c],        // \f form feed
        [0x6e,0x0a],        // \n newline
        [0x72,0x0d],        // \r carriage return
        [0x74,0x09],        // \t tab
        [0x5c,0x5c]];       // \\ bslash

// contant ASCII values
bslash = 0x5c;
fslash = 0x2f;
dquote = 0x22;
lbrace = 0x7b;
rbrace = 0x7d
lbracket = 0x5b;
rbracket = 0x5d;
minus = 0x2d;
plus = 0x2b;

// some ranges of values that are used as a set
digit = char(indgen('0':'9'));
digit19 = char(indgen('1':'9'));
hexdigit = char(grow(indgen('0':'9'), indgen('a':'f'), indgen('A':'F')));

// must use self = use()
// cannot use "use, at, etc." because if a called function changes the member,
// it won't reflect

/*
    json_decode becomes a closure at the end of the file. That closure supplies
    'base', which contains everything related to parsing json except
    json_decode.

    'base' is copied to 'self', given state information and options, then used.
    The state information is:
        text - array of char for input
        at - current position
        ch - current character
        len - length of text
    The options are as defined in json_decode's documentation (all of the
    keyword arguments).
*/
func json_decode(base, text, arrays=, objects=) {
/* DOCUMENT json_decode(text, arrays=, objects=)
    Decodes TEXT, which must be a valid JSON string. Returns the data structure
    represented by TEXT.

    Objects "{ ... }" are created using oxy group objects, unless modified by
    the OBJECTS= option. See help, oxy.

    Arrays "[ ... ]" are also created using oxy group objects, unless modified
    by the ARRAYS= option. By default, ARRAYS= is configured to attempt
    conversion to Yorick arrays; see options below.

    Numbers are converted into either doubles or integers. Integers are used if
    the value has no decimal point and if its integer value is identical to its
    floating point value.

    Strings are converted to strings. Backspace substitution is performed as
    appropriate, with the exception of unicode escape sequences. Yorick does
    not support unicode strings; thus, unicode escape sequences are left as-is
    unless they happen to represent an ASCII character. A warning will be
    printed for each non-ASCII unicode escape sequence encountered.

    Options:
        arrays= Conversion functions to apply to arrays. See "Conversion
            Functions" below. Default: arrays="json_ary2array"
        objects= Conversion functions to apply to objects. See "Conversion
            Functions" below. Default: objects="json_obj2hash"

    Conversion Functions:
        The arrays= and objects= options accept a string value or an array of
        string values. Each string must be the name of a function, or the empty
        string "". The empty string "" means "do nothing". Functions will be
        called like so:
            finished = FUNCTION(ary)
            finished = FUNCTION(obj)
        The ary or obj is expected to be updated in-place. The return result
        should be 0 (meaning that more conversions may be attempted) or 1
        (meaning that the value was converted and should be used in its current
        state).

        If multiple functions are given, they are called in the order given
        until one of the functions returns 1. This might be useful if, for
        example, you want to attempt conversion of a JSON array to Yorick array
        if possible, then to a Yorick list if that fails. It could also be
        useful for testing an object against a series of classes to see which
        "class" to "bless" it with.

        A few general-purpose conversion functions exist:
            json_ary2array - attempts coercion to Yorick array
            json_ary2list - coerces to Yorick list
            json_obj2hash - coerces to Yeti hash
*/
    default, arrays, "json_ary2array";
    default, objects, "json_obj2hash";

    self = obj_copy(base);
    save, self, arrays, objects;

    if(!is_string(text))
        error, "input must be a well-formed JSON string";

    // In case input is an array of strings, merge them together
    if(!is_scalar(text))
        text = (text + "\n")(sum);

    if(strlen(text) < 1)
        error, "malformed JSON string";

    text = strchar(text);
    save, self, text=text(:-1), at=1, ch=' ';
    save, self, len=numberof(self.text);

    text = [];

    self, white;
    if(is_void(self.ch))
        self, decode_error, "malformed JSON string";
    result = self(value,);
    self, white;
    if(!is_void(self.ch))
        self, decode_error, "garbage after JSON object";
    return result;
}

func render_position(pos) {
/*
    Renders the current position in the input, primarily used by decode_error.

    Sample output:
      [1,2,3:]
            ^
*/
    self = use();

    mess = "";
    carrot = "";
    offset = max(pos, 30) - 29;
    offset = max(1, min(offset, self.len - 60));
    if(offset > 1) {
        mess = "...";
        carrot = "   ";
    }
    while(offset <= self.len && strlen(mess) < 68) {
        ch = self.text(offset);
        if(offset == pos) {
            carrot += "^";
        }
        if(anyof(ch == ['\t', '\n', '\r', self.bslash])) {
            if(offset < pos)
                carrot += "  ";
            if(ch == '\t') mess += "\\t";
            if(ch == '\n') mess += "\\n";
            if(ch == '\r') mess += "\\r";
            if(ch == self.bslash)
                mess += swrite(format="%c%c", self.bslash, self.bslash);
        } else if(ch < 0x20) {
            code = swrite(format="\\x{%x}", ch);
            if(offset < pos)
                carrot += array(" ", strlen(code))(sum);
            mess += code;
        } else {
            mess += swrite(format="%c", ch);
            if(offset < pos)
                carrot += " ";
        }
        offset++;
    }
    if(offset < self.len)
        mess += "...";
    else if(self.len < pos)
        carrot += "^";
    return swrite(format="  %s\n  %s", mess, carrot);
}

func decode_error(msg) {
// Throws an error, showing where in the input the error occurs
    self = use();
    excerpt = self(render_position, self.at - 1);
    write, format="Problem encountered near position %d:\n%s\n",
        self.at - 1, excerpt;
    error, msg;
}
errs2caller, decode_error;

func next_chr(nil) {
// Sets "ch" to the next character and advances "at" to the next position.
    self = use();
    if(self.at > self.len)
        save, self, ch=[], at=self.len+2;
    else
        save, self, ch=self.text(self.at), at=self.at+1;
    return self.ch;
}

func value(nil) {
// Parses the input and returns the next complete value.
    self = use();
    self, white;
    if(is_void(self.ch))
        return [];
    if(self.ch == self.lbrace)
        return self(object,);
    if(self.ch == self.lbracket)
        return self(array,);
    if(self.ch == self.dquote)
        return self(string,);
    if(anyof(self.ch == self.digit) || self.ch == self.minus)
        return self(number,);
    return self(word,);
}

func hexdigits(nil) {
// Parses and returns four consecutive hex digits as a char array. (For use in
// unicode escape sequences.)
    self = use();
    digits = array(char, 4);
    for(i = 1; i <= 4; i++) {
        digits(i) = self(next_chr,);
        if(noneof(digits(i) == self.hexdigit))
            self, decode_error, "expected hex digit missing";
    }
    return digits;
}

func escape(nil) {
// Parses a backslash escape sequence, converts it, and returns it as a char
// array.
    self = use();
    if(self.ch != self.bslash)
        self, decode_error, "expected backslash missing";
    self, next_chr;
    if(anyof(self.escapes(1,) == self.ch)) {
        w = where(self.escapes(1,) == self.ch)(1);
        return self.escapes(2,w);
    } else if(self.ch == 'u') {
        digits = self(hexdigits,);
        if(allof(digits(1:2) == 0)) {
            return [char(digits(3)*16+digits(4))];
        } else {
            write, "Warning: unicode escape sequence encountered";
            return grow(self.bslash, 'u', digits);
        }
    } else {
        self, decode_error, "illegal backslash escape";
    }
}

func _string(nil) {
// Parses and returns a string, converting any escape sequences encountered.
    self = use();
    if(self.ch != self.dquote)
        self, decode_error, "expected double quotation mark missing";

    result = array(char, 2^16);
    end = 0;

    while(!is_void(self(next_chr,))) {
        new = [];
        if(self.ch == self.dquote) {
            self, next_chr;
            if(end == 0)
                return string(0);
            return strchar(result(:end));
        } else if(self.ch == self.bslash) {
            new = self(escape,);
        } else {
            new = self.ch;
        }
        count = numberof(new);
        for(i = 1; i <= count; i++) {
            end++;
            if(end > numberof(result))
                grow, result, result;
            result(end) = new(i);
        }
    }
    self, decode_error, "unexpected end of string while parsing JSON string";
}
string = _string;

func comment(nil) {
// Parses and ignores comments. Comments must be of one of these forms:
//   /* multiline */
//   // single line
    self = use();
    if(self.ch != self.fslash)
        self, decode_error, "expected forward slash missing";
    self, next_chr;
    if(self.ch == self.fslash) {
        while(!is_void(self(next_chr,))) {
            if(self.ch == '\n' || self.ch == '\r')
                break;
        }
    } else if(self.ch == '*') {
        self, next_chr;
        while(1) {
            if(is_void(self.ch))
                self, decode_error, "unterminated comment";
            while(self.ch == '*') {
                self, next_chr;
                if(self.ch == self.fslash) {
                    self, next_chr;
                    return;
                }
            }
            self, next_chr;
        }
    } else {
        self, decode_error, "malformed JSON string";
    }
}

func white(nil) {
// Parses and ignores whitespace and comments.
    self = use();
    while(!is_void(self.ch)) {
        if(self.ch <= ' ') {
            self, next_chr;
        } else if(self.ch == self.fslash) {
            self, comment;
        } else {
            break;
        }
    }
}

func _array(nil) {
// Parses and returns an array.
    self = use();
    ary = save();

    self, next_chr;
    self, white;

    if(self.ch == self.rbracket) {
        self, next_chr;
        return self(apply_conversions, ary, self.arrays);
    } else {
        while(!is_void(self.ch)) {
            save, ary, string(0), self(value,);

            self, white;

            if(self.ch == self.rbracket) {
                self, next_chr;
                return self(apply_conversions, ary, self.arrays);
            }

            if(self.ch != ',') {
                break;
            }

            self, next_chr;
            self, white;
        }
    }
    self, decode_error, "expected ',' or ']' while parsing array";
}
array = _array;

func object(nil) {
// Parses and returns an object.
    self = use();
    obj = save();

    self, next_chr;
    self, white;

    if(self.ch == self.rbrace) {
        self, next_chr;
        return self(apply_conversions, obj, self.objects);
    } else {
        while(!is_void(self.ch)) {
            key = self(string,);
            self, white;

            if(self.ch != ':') {
                self, decode_error, "':' expected while parsing object";
            }

            self, next_chr;
            save, obj, noop(key), self(value,);
            self, white;

            if(self.ch == self.rbrace) {
                self, next_chr;
                return self(apply_conversions, obj, self.objects);
            }

            if(self.ch != ',') {
                break;
            }

            self, next_chr;
            self, white;
        }
    }
    self, decode_error, "expected ',' or '}' while parsing object";
}

func apply_conversions(input, funcs) {
// Used by array and object to apply conversions to final result
    count = numberof(funcs);
    for(i = 1; i <= count; i++) {
        if(strlen(funcs(i)) < 1)
            continue;
        f = symbol_def(funcs(i));
        if(f(input))
            break;
    }
    return input;
}

func word(nil) {
// Parses a bare word and returns its corresponding value. Three bare words are
// valid:
//    true, which converts to 1
//    false, which converts to 0
//    null, which converts to []
    self = use();
    good = 1;
    expect = [];
    backup = self.at;
    if(self.ch == 't') {
        expect = "true";
        good &= (self(next_chr,) == 'r');
        good &= (self(next_chr,) == 'u');
        good &= (self(next_chr,) == 'e');
        self, next_chr;
        if(good)
            return 1;
    } else if(self.ch == 'f') {
        expect = "false";
        good &= (self(next_chr,) == 'a');
        good &= (self(next_chr,) == 'l');
        good &= (self(next_chr,) == 's');
        good &= (self(next_chr,) == 'e');
        self, next_chr;
        if(good)
            return 0;
    } else if(self.ch == 'n') {
        expect = "null";
        good &= (self(next_chr,) == 'u');
        good &= (self(next_chr,) == 'l');
        good &= (self(next_chr,) == 'l');
        self, next_chr;
        if(good)
            return [];
    }
    save, self, at=backup;
    if(is_void(expect))
        self, decode_error, "malformed JSON string";
    else
        self, decode_error, "'" + expect + "' expected";
}

func digits(nil) {
// Parses a series of digits (0-9) and returns as a char array.
    self = use();

    result = array(char, 2^16);
    end = 0;

    while(anyof(self.ch == self.digit)) {
        end++;
        if(end > numberof(result))
            grow, result, result;
        result(end) = self.ch;
        self, next_chr;
    }

    if(end)
        return result(:end);
    else
        return [];
}

func number_int(nil) {
// Parses the integer part of a number and returns as a char array.
    self = use();

    result = [];

    // may optionally start with a minus
    if(self.ch == self.minus) {
        grow, result, self.ch;
        self, next_chr;
    }

    // must continue with a single 0, or 1-9 followed by digits
    if(self.ch == '0') {
        grow, result, self.ch;
        self, next_chr;
    } else if(anyof(self.ch == self.digit19)) {
        grow, result, self.ch;
        self, next_chr;
        grow, result, self(digits,);
    } else {
        self, decode_error, "malformed number (no leading digits)";
    }

    return result(:end);
}

func number_frac(nil) {
// Parses the fractional part of a number (if present) and returns as a char
// array.
    if(self.ch != '.')
        return [];

    result = [];

    // starts with decimal
    grow, result, self.ch;
    self, next_chr;

    // must continue with digits
    digits = self(digits,);
    if(is_void(digits))
        self, decode_error, "malformed number (no digits after decimal point)";
    grow, result, digits;

    return result;
}

func number_exp(nil) {
// Parses the exponential part of a number (if present) and returns as a char
// array.
    if(noneof(self.ch == ['e','E']))
        return [];

    result = [];

    // starts with e or E
    grow, result, self.ch;
    self, next_chr;

    // a plus or minus may optionally follow
    if(anyof(self.ch == [self.plus, self.minus])) {
        grow, result, self.ch;
        self, next_chr;
    }

    // must continue with digits
    digits = self(digits,);
    if(is_void(digits))
        self, decode_error, "malformed number (no digits after exp sign)";
    grow, result, digits;

    return result;
}

func number(nil) {
// Parses a number and returns as a long or double.
    self = use();

    result = [];
    grow, result, self(number_int,);
    len = numberof(result);
    grow, result, self(number_frac,);
    isdouble = len < numberof(result);
    grow, result, self(number_exp,);

    val = atod(strchar(result));
    if(!isdouble && val == long(val))
        return long(val);
    return val;
}

json_decode = closure(json_decode, restore(tmp));
restore, scratch;

func json_ary2array(&ary) {
/* DOCUMENT json_ary2array(&ary)
    Attempts to convert its input (which should be of type "oxy_object") into a
    Yorick array. Returns 1 if it was able to do so, 0 otherwise.

    Only three types of values may be converted to arrays: strings, longs, and
    doubles. If longs and doubles are mixed together, they are all cast to
    doubles.

    All elements must have identical dimensions.

    Primarily intended for use on JSON arrays with json_decode.
*/
    if(typeof(obj) != "oxy_object")
        return 0;
    count = ary(*);
    types = array(string, count);
    dims = array(short, count);
    for(i = 1; i <= count; i++) {
        types(i) = typeof(ary(noop(i)));
        d = dimsof(ary(noop(i)));
        if(numberof(d))
            dims(i) = d(1);
        else
            dims(i) = -1;
    }
    if(nallof(dims == dims(1)))
        return 0;
    if(anyof(types == "double") && anyof(types == "long")) {
        w = where(types == "long");
        types(w) = "double";
    }
    if(nallof(types == types(1)))
        return 0;
    if(noneof(types(1) == ["string","double","long"]))
        return 0;
    dims = dimsof(ary(1));
    result = array(symbol_def(types(1)), dims, count);
    for(i = 1; i <= count; i++) {
        if(nallof(dims == dimsof(ary(noop(i)))))
            return 0;
        result(..,i) = ary(noop(i));
    }
    ary = result;
    return 1;
}

func json_ary2list(&ary) {
/* DOCUMENT json_ary2list(&ary)
    Attempts to convert a JSON array into a Yorick list. Note that Yorick lists
    are deprecated, so this probably is not appropriate except when working
    with old code. Returns 1 if it was able to covnert it, 0 otherwise.

    SEE ALSO: _lst
*/
    if(typeof(obj) != "oxy_object")
        return 0;
    count = ary(*);
    result = _lst();
    for(i = 1; i <= count; i++) {
        result = _cat(result, 0);
        _car, result, _len(result), result(noop(i));
    }
    return 1;
}

func json_obj2hash(&obj) {
/* DOCUMENT json_obj2hash(&obj)
    Converts its input (which should be of type "oxy_object") into a Yeti hash.
    Returns 1 if it was able to do so, 0 otherwise.

    Primarily intended for use on JSON objects with json_decode.
    SEE ALSO: obj2hash
*/
    if(typeof(obj) != "oxy_object")
        return 0;
    obj = obj2hash(obj);
    return 1;
}
