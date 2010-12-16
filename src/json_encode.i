// vim: set ts=4 sts=4 sw=4 ai sr et:

scratch = save(scratch, tmp, _long, _double, _float, _string);
tmp = save(
        // data items
        escape_find, escape_replace,
        // functions
        json_stringify, long, char, short, int, double, float, string, void,
        newline_indent, json_array, json_object
        );

// Predefine the escape sequences for shorter code later, and to avoid having
// vim freak out over the escapes.

escape_find = swrite(format="%c", [
        0x5c,   // \\ backslash
        0x2f,   // \/ forward slash
        0x08,   // \b backspace
        0x0c,   // \f form feed
        0x0a,   // \n newline
        0x0d,   // \r carriage return
        0x09,   // \t tab
        0x22    // \" double quote
]);

escape_replace = swrite(format="%c%c", 0x05c, [
        0x5c,   // \\ backslash
        0x2f,   // \/ forward slash
        0x62,   // \b backspace
        0x66,   // \f form feed
        0x6e,   // \n newline
        0x72,   // \r carriage return
        0x74,   // \t tab
        0x22    // \" double quote
]);

// must use self = use()
// cannot use "use, at, etc." because if a called function changes the member,
// it won't reflect

func json_encode(base, data, separators=, indent=) {
/* DOCUMENT json_encode(data, separators=, indent=)
    Converts the given DATA into a valid JSON string, which is then returned.

    DATA may be any of a number of Yorick data items, including numbers (char,
    short, int, long, float, double), strings, arrays, lists, oxy objects, Yeti
    hashes, and struct instances. Primitive types such as numbers and strings
    are encoded directly. JSON arrays and objects are encoded with the help of
    can_iter_list, iter_list, can_iter_dict, and iter_dict, so see those
    functions for details on what they accept.

    Options:
        separators= Specifies the symbols to use for separators, as [ITEM_SEP,
            KEY_SEP]. The default is:
                separators=[", ", ": "]
            which spaces things out nicely. If you need a very compact
            representation, you can provide:
                separators=[",",":"]
        indent= Specifies how much indentation should be used. If omitted (or
            specified as indent=[]), then no indentation is used and all output
            will be on a single line. With indent=0, no indentation is
            performed, but newlines will be interspersed. With indent= set to 1
            or higher, that many spaces will be used for each indentation
            level. For example:
                indent=[]       No indents, single-line output
                indent=0        No indents, multi-line output
                indent=2        Multi-line, with 2-space indents
                indent=5        Multi-line, with 5-space indents
*/
    default, separators, [", ", ": "];
    self = obj_copy(base);
    save, self, item_separator=separators(1), key_separator=separators(2),
        indent, indent_level=0;
    return self(json_stringify, data);
}

func json_stringify(data) {
// Convert data into a json string
    self = use();
    type = typeof(data);

    // No native support for complex numbers, so we fake it
    if(is_complex(data))
        data = save(re=data.re, im=data.im);

    if(can_iter_dict(data))
        return self(json_object, data);
    if(can_iter_list(data))
        return self(json_array, data);

    if(self(*,type))
        return self(noop(type), data);

    error, "Unsupported data type: " + type;
}

// Encode various numerical types
func _long(data) { return swrite(format="%d", data); }
char = short = int = long = _long;
func _double(data) { return swrite(format="%.16g", data); }
double = _double;
func _float(data) { return swrite(format="%.8g", data); }
float = _float;

func _string(data) {
// Encodes a json string
    self = use();
    if(!is_scalar(data)) {
        result = array(string, dimsof(data));
        count = numberof(result);
        for(i = 1; i <= count; i++)
            result(i) = self(string, data(i));
        return result;
    }

    // replace pre-defined escapes
    count = numberof(self.escape_find);
    for(i = 1; i <= count; i++) {
        pos = strfind(self.escape_find(i), data, n=strlen(data));
        streplace, data, pos, self.escape_replace(i);
    }

    // encode ascii control characters and extended ascii as unicode
    c = strchar(data);
    w = where(c < 32 | c > 126);
    count = numberof(w);
    for(i = count; i > 0; i--) {
        unicode = swrite(format="\\u00%02x", c(w(i)));
        streplace, data, [w(i)-1, w(i)], unicode;
    }

    return "\"" + data + "\"";
}
string = _string;

func void(data) {
    return "null";
}

func newline_indent(nil) {
// Constructs a newline + indentation sequence
// Used by json_array and json_object
    self = use();
    buffer = "\n";
    if(self.indent && self.indent_level)
        buffer += array(" ", self.indent * self.indent_level)(sum);
    return buffer;
}

func json_array(data) {
// Constructs a json array
    self = use();
    buffer = "[";
    if(!is_void(self.indent)) {
        save, self, indent_level=self.indent_level+1;
        newline_indent = self(newline_indent,);
        separator = strtrimright(self.item_separator) + newline_indent;
    } else {
        newline_indent = "";
        separator = self.item_separator;
    }
    iter = iter_list(data);
    for(i = 1; i <= iter.count; i++) {
        if(i == 1)
            buffer += newline_indent;
        else
            buffer += separator;
        buffer += self(json_stringify, iter(item,i));
    }
    if(!is_void(self.indent)) {
        save, self, indent_level=self.indent_level-1;
        buffer += self(newline_indent,);
    }
    buffer += "]";
    return buffer;
}

func json_object(data) {
// Constructs a json object
    self = use();
    buffer = "{";
    if(!is_void(self.indent)) {
        save, self, indent_level=self.indent_level+1;
        newline_indent = self(newline_indent,);
        separator = strtrimright(self.item_separator) + newline_indent;
    } else {
        newline_indent = "";
        separator = self.item_separator;
    }
    iter = iter_dict(data);
    for(i = 1; i <= iter.count; i++) {
        if(i == 1)
            buffer += newline_indent;
        else
            buffer += separator;
        buffer += self(string, iter.keys(i));
        buffer += self.key_separator;
        buffer += self(json_stringify, iter(item,i));
    }
    if(!is_void(self.indent)) {
        save, self, indent_level=self.indent_level-1;
        buffer += self(newline_indent,);
    }
    buffer += "}";
    return buffer;
}

json_encode = closure(json_encode, restore(tmp));
restore, scratch;
