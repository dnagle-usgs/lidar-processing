// vim: set ts=3 sts=3 sw=3 ai sr et:
require, "eaarl.i";

func draw_grid(w) {
/* DOCUMENT draw_grid, w
   Draws a 10k/2k grid in window W using the window's current limits. The grid
   will contain one or more of the following kinds of grid lines:
      10km tile: violet
      2km tile: red
      1km quad: dark grey
      250m cell: light grey
   SEE ALSO: tile_file_name show_grid_location
*/
   local x0, x1, y0, y1;
   default, w, 5;
   old_w = current_window();
   window, w;
   ll = long(limits()/2000) * 2000;

   // Only show 10km tiles if range is >= 8km; otherwise, 2km
   if(ll(4) - ll(3) >= 8000) {
      ll = long(ll/10000)*10000;
      ll([2,4]) += 10000;
   } else {
      ll([2,4]) += 2000;
   }
   assign, ll, x0, x1, y0, y1;

   // Only show quads and cells when within 4km
   if (y1 - y0 <= 4000) {
      plgrid, indgen(y0:y1:250), indgen(x0:x1:250), color=[200,200,200],
         width=0.1;
      plgrid, indgen(y0:y1:1000), indgen(x0:x1:1000), color=[120,120,120],
         width=0.1;
   }

   // Always show 2km tile, though with a smaller width when zoomed out
   width = (y1 - y0 >= 8000) ? 3 : 5;
   plgrid, indgen(y0:y1:2000), indgen(x0:x1:2000), color=[250,140,140],
      width=width;

   // Only show 1km tiles if range is >= 8km
   if(y1 - y0 >= 8000) {
      plgrid, indgen(y0:y1:10000), indgen(x0:x1:10000), color=[170,120,170],
         width=7;
   }

   window_select, old_w;
}

func show_grid_location(m) {
/* DOCUMENT show_grid_location, win
   -or- show_grid_location, point
   Displays information about the grid location for a given point. If provided
   a scalar value WIN, the user will be prompted to click on a location in that
   window. Otherwise, the location POINT is used. Will display the index tile,
   data tile, quad name, and cell name.
   SEE ALSO: draw_grid
*/
   extern curzone;
   local quad, cell;
   default, w, 5;
   if(is_scalar(m) || is_void(m)) {
      wbkp = current_window();
      window, m;
      m = mouse();
      window_select, wbkp;
   }
   write, format="10km index tile : %s\n", get_utm_itcodes(m(2), m(1), curzone);
   get_utm_dt_quadcell, m(2), m(1), quad, cell;
   write, format="2km data tile   : %s   quad %s cell %d\n",
      get_utm_dtcodes(m(2), m(1), curzone), quad, cell;
}
