require, "yeti.i";
write, "$Id$";

func mouse_click_is(query, click) {
/* DOCUMENT result = mouse_click_is(query, click)
   Returns boolean result 0 or 1 that indicates whether the mouse click given
   matches the query.

   query should be a string. It should be comprised of a hyphen or plus
   delimited series of tokens with the following constraints.
   
      * Query must contain exactly one of the following tokens that specify a
        button:
         left
         middle (synonym: center)
         right
         button4
         button5

      * Query may contain zero or more of the following tokens that specify
        modifiers:
         shift
         shiftlock
         control (synonym: ctrl)
         mod1 (synonyms: alt, meta)
         mod2
         mod3
         mod4
         mod5

      * Tokens may be in any order, but it is recommended that modifiers
        preceed the button.

   Examples of queries:
   
      left
      shift-right
      ctrl+alt+delete
   
   It must contain exactly one of the following tokens: "left",
   "middle", "right", "button4", or "button5".

   If query is an array, then it is treated as a series of OR cases. In other
   words,
      mouse_click_is([case1, case2], click)
   is equivalent to
      mouse_click_is(case1, click) || mouse_click_is(case2, click)

   click can be provided in several formats.
      * An array of length 11 is interpreted as the result of a mouse() call.
      * An array of length 2 is interepreted as elements 10 and 11 of a mouse()
        call.
      * A scalar integer is interpreted as element 10 plus ten times element
        11. This allows the button and modifiers to be comprised in a single
        value.
*/
// Original David Nagle 2009-08-06
   // Coerce click into single-value format; easier to test in that format.
   if(numberof(click) == 11) {
      click = click(10) + 10 * click(11);
   } else if(numberof(click) == 2) {
      click = click(1) + 10 * click(2);
   } else if(numberof(click) != 1) {
      error, "Invalid input for click.";
   }
   click = click(1);

   // Define valid syntax tokens with associated values.
   button_vals = h_new(
      left=1, middle=2, center=2, right=3, button4=4, button5=5
   );
   modifier_vals = h_new(
      shift=1, shiftlock=2, control=4, ctrl=4, mod1=8, alt=8, meta=8, mod2=16,
      mod3=32, mod4=64, mod5=128
   );

   // Parse queries. Each query is converted into a scalar value encoded in the
   // same way as click.
   cases = array(short, dimsof(query));
   for(i = 1; i <= numberof(query); i++) {
      button = 0;
      modifiers = 0;
      tokens = [string(0), query(i)];
      do {
         tokens = strtok(tokens(2), "-+");

         if(h_has(button_vals, tokens(1))) {
            if(button)
               error, "Invalid query: tried to provide multiple buttons.";
            else
               button = button_vals(tokens(1));
         } else if(h_has(modifier_vals, tokens(1))) {
            modifiers |= modifier_vals(tokens(1));
         } else {
            error, "Invalid query: unknown token encountered: " + tokens(1);
         }
      } while(tokens(2));
      if(button)
         cases(i) = button + 10 * modifiers;
      else
         error, "Invalid query: no button provided.";
   }

   // Test to see if any of the cases match the click
   match = (cases == click);
   return match ? 1 : 0;
}
