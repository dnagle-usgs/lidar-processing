// vim: set ts=3 sts=3 sw=3 ai sr et:

/*
   This file is included by ytk.i during start up. Therefore, it can't include
   the entire ALPS codebase, otherwise errors ensue. This prohibits the use of
   functions like 'default'.
*/

func base64_encode(input, maxlen=, wrapchar=) {
/* DOCUMENT encoded = base64_encode(input, maxlen=, wrapchar=)
   Uses base64 encoding to encode data.

   Parameter:
      input: Must be a scalar string or a one-dimensional char array.

   Options:
      maxlen= The maximum length for a single line in the encoded output. Lines
         will be broken with wrapchar at this length. Defaults to 76.
      wrapchar= The character to insert between lines, for wrapping. Defaults
         to \n.

   Output will be a scalar string.
*/
   if(is_void(maxlen)) maxlen = 76;
   if(is_void(wrapchar)) wrapchar = '\n';

   base64_alphabet = char(grow(
      indgen(65:90),    // A-Z   0 to 25
      indgen(97:122),   // a-z   26 to 51
      indgen(48:57),    // 0-9   52 to 61
      43, 47            // +/    62 to 63
   ));

   if(typeof(input) == "string")
      data = strchar(input)(:-1);
   else if(typeof(input) == "char")
      data = input;
   else
      error, "Only accepts char and string input.";
   input = [];

   bitmod = numberof(data) % 3;

   if(bitmod)
      grow, data, array(char(0), 3 - bitmod);

   num_groups = numberof(data) / 3;

   data = reform(data, [2, 3, num_groups]);
   encoded = array(char, [2, 4, num_groups]);

   encoded(1,) = data(1,) >> 2;
   encoded(2,) = ((data(1,)&3)<<4) + (data(2,)>>4);
   encoded(3,) = ((data(2,)&15)<<2) + (data(3,)>>6);
   encoded(4,) = data(3,) & 63;

   encoded = reform(encoded, [1, numberof(encoded)]);
   indices = int(encoded) + 1;

   output = base64_alphabet(indices);
   if(bitmod == 1)
      output(-1:0) = ['=', '='];
   else if(bitmod == 2)
      output(0) = '=';

   if(numberof(output) > maxlen) {
      padding = maxlen - (numberof(output) % maxlen);
      padding = (padding == maxlen) ? 0 : padding;
      if(padding)
         grow, output, array(char, padding);
      output = reform(output, [2, maxlen, numberof(output) / maxlen]);
      output = transpose(grow(transpose(output), wrapchar));
      output = reform(output, [1, numberof(output)]);
      output = output(:-padding);
      output = output(:-numberof(wrapchar));
   }

   return strchar(output);
}

func base64_decode(input) {
/* DOCUMENT decoded = base64_decode(input)
   Decodes a string that was encoded using base64 encoding.

   Parameter:
      input: Must be a scalar string or a one-dimensional char array.

   Output will be an array of char data. (Pass to strchar to turn into a
   string.)
*/
// Rationale for returning char array instead of string:
// When passing through strchar, an array of char data ending with a single \0
// is treated the same as an array of char data ending without \0. Thus,
// passing the decoded output through strchar prior to returning would result
// in data loss in specific constrained circumstances.

   base64_alphabet = char(grow(
      indgen(65:90),    // A-Z   0 to 25
      indgen(97:122),   // a-z   26 to 51
      indgen(48:57),    // 0-9   52 to 61
      43, 47            // +/    62 to 63
   ));

   if(typeof(input) == "string")
      data = strchar(input)(:-1);
   else if(typeof(input) == "char")
      data = input;
   else
      error, "Only accepts char and string input.";
   input = [];

   encoded = array(char, numberof(data));
   gooddata = array(0, numberof(data));
   for(i = 1; i <= numberof(base64_alphabet); i++) {
      current = base64_alphabet(i);
      w = where(data == current);
      if(numberof(w)) {
         encoded(w) = i - 1;
         gooddata(w) = 1;
      }
   }
   w = where(data == '=');
   if(numberof(w)) {
      encoded(w) = 255;
      gooddata(w) = 1;
   }
   w = where(gooddata);
   if(numberof(w)) {
      encoded = encoded(w);
   } else {
      return "";
   }

   if(encoded(0) == 255) {
      if(encoded(-1) == 255) {
         bitmod = 1;
         encoded(-1) = 0;
         encoded(0) = 0;
      } else {
         bitmod = 2;
         encoded(0) = 0;
      }
   } else {
      bitmod = 3;
   }

   w = where(encoded == 255);
   if(numberof(w)) {
      error, "The = character was found in an illegal position.";
   }

   num_groups = numberof(encoded) / 4;

   data = array(char, [2, 3, num_groups]);
   encoded = reform(encoded, [2, 4, num_groups]);

   data(1,) = (encoded(1,) << 2) + (encoded(2,) >> 4);
   data(2,) = (encoded(2,) << 4) + (encoded(3,) >> 2);
   data(3,) = (encoded(3,) << 6) + encoded(4,);

   data = reform(data, [1, numberof(data)]);

   data = data(:bitmod-3);

   return data;
}

func hex_encode(data) {
/* DOCUMENT hex_encode(data)
   Uses hex encoding to encode data. This inflates the size of the data by 100%.

   Parameter:
      data: Must be a scalar string or a one-dimensional char array.

   Output will be a scalar string.
*/
   if(is_void(data) || (is_string(data) && !strlen(data)))
      return [];
   if(is_string(data))
      data = strchar(data)(:-1);
   return swrite(format="%02x", data)(sum);
}

func hex_decode(input) {
/* DOCUMENT hex_decode(input)
   Decodes a string that was encoded using hex_encode.

   Parameter:
      input: Must be a scalar string.

   Output will be an array of char data. (Pass to strchar to turn into a
   string.)
*/
// Rationale for returning char array instead of string:
// See note under base64_decode.
   output = array(char, strlen(input)/2);
   sread, input, format="%2x", output;
   return output;
}
