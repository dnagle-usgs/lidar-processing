// vim: set ts=2 sts=2 sw=2 ai sr et:
require, "yeti.i";

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

func mouse_measure(sys, style, prompt, win=) {
/* DOCUMENT mouse_measure(sys, style, prompt, win=)
  -or- mouse_measure, sys, style, prompt, win=

  Prompts the user to click and drag in the current window to measure a
  distance. If called as a function, the distance will be returned. If called
  as a subroutine, the distance will be written to the screen.

  Arguments SYS, STYLE, and PROMPT are passed through to the mouse function
  and default to 1, 2, and "Click and drag in window %d to measure",
  respectively. WIN is the window the user should click in and defaults to the
  current window.
*/
  default, sys, 1;
  default, style, 2;
  default, win, window();
  default, prompt, swrite(format="Click and drag in window %d to measure", win);

  wbkp = current_window();
  window, win;

  click = mouse(sys, style, prompt);
  dist = ppdist(click(1:2), click(3:4));

  window_select, win;

  if(am_subroutine())
    write, format=" Distance: %.10g\n", dist;
  return dist;
}

func mouse_bounds(&xmin, &ymin, &xmax, &ymax, sys=, style=, prompt=, win=) {
/* DOCUMENT mouse_bounds(sys=, style=, prompt=, win=)
  -or- mouse_bounds, xmin, ymin, xmax, ymax, sys=, style=, prompt=, win=

  Prompts the user to click and drag in the current window to determine a
  bounding box. If called as a function, the coordinates [xmin, ymin, xmax,
  ymax] will be returned. If called as a subroutine, the coordinates will be
  stored in the variables given.

  Options SYS, STYLE, and PROMPT are passed through to the mouse function and
  default to 1, 1, and "Click and drag in window %d to select bounds",
  respectively. WIN is the window the user should click in and defaults to the
  current window.
*/
  default, sys, 1;
  default, style, 1
  default, win, window();
  default, prompt, swrite(format="Click and drag in window %d to select bounds", win);

  wbkp = current_window();
  window, win;

  click = mouse(sys, style, prompt);
  xmin = click([1,3])(min);
  xmax = click([1,3])(max);
  ymin = click([2,4])(min);
  ymax = click([2,4])(max);

  window_select, win;

  return [xmin, ymin, xmax, ymax];
}

func mdist(&click, units=, win=, plot=, verbose=, nox=, noy=) {
/* DOCUMENT mdist(&click, units=, win=, plot=, verbose=, nox=, noy=)
  Measure the distance between two points as selected by mouse click and return
  the distance in meters. The distance in nautical miles, statue miles, and
  meters or kilometers will also be displayed to the console.

  Options:
    units= Specifies the units used in the input window.
        units="ll"  Geographic coordinates in degrees (default)
        units="m"   Meters
        units="cm"  Centimeters
        units="mm"  Millimeters
    win= Specifies a window. If omitted, the current window is used.
    plot= Can be used to turn on/off plotting of the line drawn.
        plot=0      Turn off plotting
        plot=1      Turn on plotting (default)
    verbose= Specifies whether to display text to the console.
        verbose=0   Display nothing to the console
        verbose=1   Display info to the console (default)
    nox= Eliminates X from the distance calculation. (Useful to get height
      differences in a transect window, for example.)
        nox=0   Include X (default)
        nox=1   Exclude X
    noy= Eliminates Y from the distance calculation.
        noy=0   Include Y (default)
        noy=1   Exclude Y

  Output parameters:
    click: The return result from mouse() obtained from the user.

  Returns:
    Scalar distance in meters.

  SEE ALSO: lldist, mouse_measure
*/
  default, units, "ll";
  default, win, window();
  default, plot, 1;
  default, verbose, 1;

  msize = 0.3;
  prompt = swrite(format="Click and drag left mouse button in window %d:", win);

  wbkp = current_window();
  window, win;

  forever = 1;
  while(1) {
    click = mouse(1, 2, prompt);
    if(anyof(click(1:2) - click(3:4))) break;
    write, "You must keep the left mouse button down while dragging the line.";
    write, "Make sure you click in the correct window.";
  }

  result = [];

  if(units == "ll") {
    nm = lldist(click(2), click(1), click(4), click(3));
    sm = nm * 1.150779;
    km = nm * 1.852;
    m = km / 1000.;
  } else {
    dx = nox ? 0 : (click(3) - click(1));
    dy = noy ? 0 : (click(4) - click(2));
    m = sqrt(dx*dx + dy*dy);

    if(units == "cm")
      m *= 0.01;
    else if(units == "mm")
      m *= 0.001;
    else if(units != "m")
      error, "Unknown units= value";

    km = m / 1000.;
    nm = km / 1.852;
    sm = nm * 1.150779;
  }

  if(verbose) {
    write, "Distance is:";
    write, format="   %.3f nautical miles\n", nm;
    write, format="   %.3f statute miles\n", sm;
    if(km > 1)
      write, format="   %.3f kilometers\n", km;
    else
      write, format="   %.3f meters\n", m;
  }

  if(plot) {
    plmk, click(2), click(1), msize=msize;
    plmk, click(4), click(3), msize=msize;
    plg, [click(2),click(4)], [click(1),click(3)], color="red", marks=0;
  }

  window_select, wbkp;
  return m;
}
