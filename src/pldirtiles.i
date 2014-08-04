// vim: set ts=2 sts=2 sw=2 ai sr et:

func pldirtiles(dir, liness=, borderss=, solidss=, win=, xfma=, tsize=, title=,
bsize=) {
/* DOCUMENT pldirtiles, dir, liness=, borderss=, solidss=, win=, xfma=, tsize=,
   title=, bsize=

  Plots the tile outlines for selected files present in a directory of 2km
  tiles. Up to three sets of files can be plotted to compare availability of
  tiles.

  Sets of files are specified by providing a search string.  The files selected
  must have the 2km tile name in their file name (such as
  t_e246000_n3984000_15_... or e246_n394_15_...). Only the file name is used,
  so this can be used against pbd files, tif files, las files, or any other
  kind of file provided it has the tile name.

  There are three stylings used for displaying sets of files: solid dark blue
  lines, thick green borders, and solid cyan backgrounds. For the border and
  solid variants, a gray dotted line will be included to indicate tile
  boundaries. For all variants, 10km boundaries are indicated with a thicker
  line width than the 2km boundaries. (All colors are hard-coded and cannot be
  easily changed.)

  If you omit the search string for a styling or if no files are found for the
  styling, then that styling is just skipped.

  Parameters:
    dir: Path to the data directory.

  Options:
    liness= Search string to use for plotting the solid dark blue lines.
    borderss= Search string to use for plotting the thick green borders.
    solidss= Search string to use for plotting the solid cyan backgrounds.
    win= The window to plot in. Defaults to 30.
    xfma= By default, the window will be cleared prior to plotting which is
      normally what you want. You can use xfma=0 to prevent this, which is
      useful if you are plotting the tile lines/borders over a plot of the
      point cloud data.
    tsize= If specified, this enables adding the tile names to each cell and
      specifies the font size to use. Start with tsize=10 and adjust up or down
      based on how big your cells are in the current plot.
    title= Specifies a title to add to the plot.
    bsize= Configures the thickness of the border. Default is bsize=8. Bigger
      numbers make a smaller border. Enforced minimum is bsize=4.
*/
  local x, y, xmin, xmax, ymin, ymax, xmin10, xmax10, ymin10, ymax10;
  default, win, 30;
  default, xfma, 1;
  default, tsize, 0;
  default, bsize, 8;

  bsize = max(long(bsize), 4);

  ss = save(solidss, borderss, liness);

  breg = array(0, bsize, bsize);
  breg(2, 2:) = 1;
  breg(bsize, 2:) = 1;
  breg(2:, 2) = 1;
  breg(2:, bsize) = 1;
  // 0,200,0 = Dark green
  bary = array(char([0,200,0]), bsize-1, bsize-1);

  alltiles = [];

  wbkp = current_window();
  window, win;
  if(xfma) fma;
  limits, square=1;
  for(i = 1; i <= ss(*); i++) {
    if(is_void(ss(noop(i)))) continue;

    files = find(dir, searchstr=ss(noop(i)));
    if(!numberof(files)) continue;

    tiles = extract_dt(file_tail(files));
    tiles = tiles(unique(tiles));
    grow, alltiles, tiles;

    ntiles = numberof(tiles);
    for(j = 1; j <= ntiles; j++) {
      dt2utm, tiles(j), xmin, ymax;
      xmax = xmin + 2000;
      ymin = ymax - 2000;

      dt2utm, dt2it(tiles(j)), xmin10, ymax10;
      xmax10 = xmin10 + 10000;
      ymin10 = ymax10 - 10000;

      // Solid
      if(i == 1) {
        // 0,255,255 = cyan
        pli, char([[[0,255,255]]]), xmin, ymin, xmax, ymax;
      // Border
      } else if(i == 2) {
        plf, bary,
          array(span(ymin, ymax, bsize), bsize),
          transpose(array(span(xmin, xmax, bsize), bsize)),
          breg;
      }

      // i == 3 is lines; highlight with color. Otherwise, use gray.
      if(i == 3) {
        // 25,25,112 = dark blue
        color = char([25,25,112]);
        type = ["solid","solid"];
        width = [1,4];
      } else {
        // 127,127,127 = gray
        color = char([127,127,127]);
        type = ["dash","dash"];
        width = [1,4];
      }

      k = (xmin == xmin10) + 1;
      pldj, xmin, ymin, xmin, ymax, color=color, type=type(k), width=width(k);
      k = (xmax == xmax10) + 1;
      pldj, xmax, ymin, xmax, ymax, color=color, type=type(k), width=width(k);
      k = (ymin == ymin10) + 1;
      pldj, xmin, ymin, xmax, ymin, color=color, type=type(k), width=width(k);
      k = (ymax == ymax10) + 1;
      pldj, xmin, ymax, xmax, ymax, color=color, type=type(k), width=width(k);
    }
  }

  if(tsize > 0) {
    tiles = alltiles(unique(alltiles));
    alltiles = [];
    ntiles = numberof(tiles);
    for(i = 1; i <= ntiles; i++) {
      dt2utm, tiles(i), xmin, ymax;
      x = xmin + 1000;
      y = ymax - 1000;
      plt, swrite(format="e%d", xmin/1000), x, y, tosys=1, justify="CB",
        height=tsize;
      plt, swrite(format="n%d", ymax/1000), x, y, tosys=1, justify="CT",
        height=tsize;
    }
  }

  if(!is_void(title)) {
    title = regsub("_", title, "!_", all=1);
    pltitle, title;
  }

  window_select, wbkp;
}
