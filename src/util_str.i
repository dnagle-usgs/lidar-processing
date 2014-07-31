// vim: set ts=2 sts=2 sw=2 ai sr et:
require, "util_basic.i";
require, "rdcols.i";
require, "yeti_regex.i";

func atoi(str) {
/* DOCUMENT atoi(str)
  Converts a string representation of a number into an integer. For example:
    > atoi("12")
    12
    > atoi(["13.45", "-1000"])
    [13,-1000]
*/
  dims = dimsof(str);
  res = _rc_convert(str(*), 2, 0);
  return (dims(0) ? reform(res, dims) : res(1));
}

func atod(str) {
/* DOCUMENT atod(str)
  Converts a string representation of a number into a double. For example:
    > atod("3.14")
    3.14
    > atod(["-23.4", "43.1"])
    [-23.4,43.1]
*/
  dims = dimsof(str);
  res = _rc_convert(str(*), 3, 0.);
  return (dims(0) ? reform(res, dims) : res(1));
}

func atoc(str) {
/* DOCUMENT atoc(str)
  Converts a string representation of a char into a char. For example:
    > atoc("a")
    0x61
    > atoc(["a","b","c"])
    [0x61,0x62,0x63]
  Caveat: Every string element must be exactly one character in length.
*/
// Original David B. Nagle 2009-04-17
  if(anyof(strlen(str) != 1))
    error, "Input string elements must be exactly one character in length.";
  c = array(char, dimsof(str));
  for(i = 1; i <= numberof(str); i++) {
    c(i) = strchar(str(i))(1);
  }
  return c;
}

func strsplit(str, sep) {
/* DOCUMENT strsplit(str, sep)

  Given an input string (or array of strings), this will split the string(s)
  into arrays at each instance of the separator.

  A pair of separators with nothing between them results in "". If some of the
  strings in an array have more fields than others, the shorter-fielded ones
  will be padded with (nil).

  This will work only on one-dimensional arrays and scalar strings.

  Examples:

  > strsplit("hello,world", ",")
  ["hello","world"]

  > strsplit("foo,,bar", ",")
  ["foo","","bar"]

  > strsplit(["a b c", "1 2 3 4"], " ")
  [["a","1"],["b","2"],["c","3"],[(nil), "4"]]

  > strsplit("anythingSPLITcanSPLITseparate", "SPLIT")
  ["anything","can","separate"]

  In a one-dimensional array: If res is the result, then res(1,) contains the
  substrings for the first element, and res(,1) contains the first field of
  all elements.
*/
  if(!is_scalar(str)) {
    if(!is_vector(str)) error, "STR must be scalar or vector";

    nstr = numberof(str);
    work = array(pointer, nstr);
    lens = array(long, nstr);
    for(i = 1; i <= nstr; i++) {
      tmp = strsplit(str(i), sep);
      lens(i) = numberof(tmp);
      work(i) = &tmp;
    }

    max_len = lens(max);
    result = array(string, nstr, max_len);
    for(i = 1; i <= nstr; i++) {
      result(i,:lens(i)) = *work(i);
    }

    return result;
  }

  i = strfind(sep, str, n=strlen(str));
  i = i(1:min(where(i<0))-1);
  if(numberof(i) <= 1) return [str];
  return strpart(str, grow([0],i));
}

func strjoin2(lst, sep, stripnil=) {
/* DOCUMENT strjoin2(lst, sep, stripnil=)

  Given an input array of strings, this will join the strings into a single
  string, using the separator between each array item. If the array is not
  one-dimensional, it will be collapsed as str(*).

  If stripnil=1, then any nil values will be removed prior to joining.

  Example: strjoin2(["a", "b", "c"], "--") will return "a--b--c".

  SEE ALSO: string
*/
  default, stripnil, 0;
  if(!numberof(lst)) return string(0);
  if(stripnil) {
    w = where(lst);
    if(!numberof(w))
      return string(0);
    lst = lst(w);
  }
  if(numberof(lst) > 1) {
    lst = lst(*);
    lst(:-1) += sep;
  }
  return lst(sum);
}

func strwrap(str, space=, newline=, paragraph=, width=) {
/* DOCUMENT wrapped = strwrap(str, space=, newline=, paragraph=, width=)
  Performs word-wrapping on the string defined by str.

  Options:
    space= Defaults to " ". This represets the string that delimits words.
    newline= Defaults to "\n". This represents the string the delimits lines.
    paragraph= Defaults to "\n\n". This represents the string the delimits
      paragraphs.
    width= Defaults 72. Specifies the maximum width for the wrapped text.
*/
// Original David B. Nagle 2009-04-03
  default, space, " ";
  default, newline, "\n";
  default, paragraph, "\n\n";
  default, width, 72;

  result = string(0);
  paragraphs = strsplit(str, paragraph);
  for(i = 1; i <= numberof(paragraphs); i++) {
    this_paragraph = string(0);
    this_line = string(0);
    lines = strsplit(paragraphs(i), newline);
    lines = strtrim(lines);
    for(j = 1; j <= numberof(lines); j++) {
      words = strsplit(lines(j), space);
      for(k = 1; k <= numberof(words); k++) {
        trial_line = strjoin2([this_line, words(k)], space, stripnil=1);
        if(strlen(trial_line) <= width) {
          this_line = trial_line;
        } else {
          this_paragraph = strjoin2([this_paragraph, this_line], newline, stripnil=1);
          this_line = words(k);
        }
      }
    }
    if(strlen(this_line)) {
      this_paragraph = strjoin2([this_paragraph, this_line], newline, stripnil=1);
    }
    result = strjoin2([result, this_paragraph], paragraph, stripnil=1);
  }
  return result;
}

func strindent(re, str, ind) {
/* DOCUMENT newstr = strindent(str, ind);
  Indents each line of str (as deliminted by newlines) with the indentation
  given by ind.
*/
  return ind + regsub(re, str, "\n" + ind, all=1);
}
strindent = closure(strindent, regcomp("\n"));

func longest_common_suffix(S) {
/* DOCUMENT suffix = longest_common_suffix(S)
  Returns the longest string that is a common suffix to all strings in S. If
  there is no common suffix, then string(0) is returned.
*/
// Original David Nagle 2009-12-28
  nS = numberof(S);
  if(nS == 0)
    return string(0);
  if(nS == 1)
    return S(1);

  s1 = strchar(S(1));
  for(i = 2; i <= nS; i++) {
    s2 = strchar(S(i));
    len = min(numberof(s1), numberof(s2));
    if(!len)
      return string(0);

    s1 = s1(1-len:);
    s2 = s2(1-len:);

    nomatch = s1 != s2;
    if(allof(nomatch))
      return string(0);

    last = noneof(nomatch) ? 0 : (nomatch * indgen(len))(mxx);
    if(last == len)
      return string(0);

    s1 = s1(last+1:);
  }
  return strchar(s1);
}

func longest_common_prefix(S) {
/* DOCUMENT prefix = longest_common_prefix(S)
  Returns the longest string that is a common prefix to all strings in S. If
  there is no common prefix, then string(0) is returned.
*/
  nS = numberof(S);
  if(nS == 0)
    return string(0);
  if(nS == 1)
    return S(1);

  s1 = strchar(S(1));
  for(i = 2; i <= nS; i++) {
    s2 = strchar(S(i));
    len = min(numberof(s1), numberof(s2));
    if(!len)
      return string(0);

    s1 = s1(:len);
    s2 = s2(:len);

    nomatch = s1 != s2;
    if(allof(nomatch))
      return string(0);

    first = noneof(nomatch) ? len+1 : (nomatch * indgen(len:1))(mxx);
    if(first == 1)
      return string(0);

    s1 = s1(:first-1);
  }
  return strchar(s1);
}
