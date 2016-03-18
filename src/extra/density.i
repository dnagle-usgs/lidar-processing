/*
  Code for calculating point density.

  Density is a measure of point count over area. Calculating this can be
  slightly tricky because a point cloud doesn't necessarily have a clean
  boundary, which means there's no easy way for calculating the area to divide
  by.

  The approach used here is to grid the data, where each grid cell's value is
  the point count for that cell. The smaller the grid cell, the better the area
  estimate will be. However, smaller grid cells also take longer to process.

  Even with larger cells, we can still get a good density estimate if we focus
  on interior cells and exclude border cells. An interior cell is one that has
  points in each of its eight neighbors. A border cell is one that does not.
  While a border cell is likely to only be partially covered by points, an
  interior cell is very likely entirely covered. Thus, the density calculation
  on interior cells should be more reliable.

  Overview of functions:
  
    grid_cell_counts: Grids an array of data so that cells provide counts of
      points in that cell. Suitable for plotting (ZGRID).

    grid_density: Grids an array of data or a cell counts grid so that cells
      provide density values for that cell. Suitable for plotting (ZGRID).

    density_stats: Analyzes data and outputs statistics about its density.
*/

func grid_cell_counts(data, mode=, cell=) {
/* DOCUMENT grid_cell_counts(data, mode=, cell=)

  Grids data. Each cell's "z" value will be the number of points in that cell.
  Returns a ZGRID value, just like other gridding functions.

  Parameter:
    data: An data array of FS, VEG__, etc.
  Options:
    mode= Data mode to use for deriving the x,y coordinates. Elevation is not used.
    cell= Cell size to use, in meters. Default is 250. When working with tiled
      data, use a value that divides evenly into 2000 for best results.
*/
  default, mode, "fs";
  default, cell, 250.;

  grid = ZGRID();
  grid.nodata = 0;
  grid.cell = cell;

  x = y = z = [];
  data2xyz, data, mode=mode, x, y, z;

  xc = long(x/cell);
  yc = long(y/cell);

  grid.xmin = xc(min) * cell;
  grid.ymin = yc(min) * cell;

  xc = xc - xc(min) + 1;
  yc = yc - yc(min) + 1;

  xcount = xc(max);
  ycount = yc(max);
  zgrid = array(0, xcount, ycount);

  total = numberof(x);
  done = 0;

  status, start;
  for(xi = 1; xi <= xcount; xi++) {
    for(yi = 1; yi <= ycount; yi++) {
      zgrid(xi, yi) = numberof(where((xc == xi) & (yc == yi)));

      done += zgrid(xi, yi);
      status, progress, done, total;
    }
  }
  status, finished;

  grid.zgrid = &zgrid;

  return grid;
}

func file_grid_cell_counts(infile, outfile=, mode=, cell=, empty=) {
/* DOCUMENT file_grid_cell_counts, infile, outfile=, mode=, cell=, empty=
  Applies grid_cell_counts to the data in INFILE and saves it to OUTFILE.

  If not specified, OUTFILE defaults INFILE with "_counts.pbd" at the end. The
  variable name will have "_counts" appended.

  Set empty=1 if you want an empty file created even if no data was loaded.
*/
  default, outfile, file_rootname(infile) + "_counts.pbd";

  data = pbd_load(infile, , vname);

  mkdirp, file_dirname(outfile);
  if(!numberof(data)) {
    if(empty) open, outfile, "w";
    return;
  }

  counts = grid_cell_counts(data, mode=mode, cell=cell);
  vname += "_counts";

  pbd_save, outfile, vname, counts, empty=1;
}

func job_grid_cell_counts(conf) {
/* DOCUMENT job_grid_cell_counts, conf;
  Job function used by batch_grid_cell_counts.
*/
  require, "eaarl.i";
  cell = pass_void(atoi, conf.cell);
  file_grid_cell_counts, conf.infile, outfile=conf.outfile, mode=conf.mode,
    cell=cell, empty=1;
}

func hook_jobs_grid_cell_counts(thisfile, env) {
/* DOCUMENT hook_jobs_grid_cell_counts, env;
  Hook function attached to jobs_env_wrap to ensure this file gets loaded.
*/
  includes = env.env.includes;
  grow, includes, thisfile;
  save, env.env, includes;
  return env;
}
hook_jobs_grid_cell_counts = closure(hook_jobs_grid_cell_counts, current_include());

// This makes sure that the job gets this include file loaded.
makeflow_requires_jobenv, "job_grid_cell_counts";
hook_add, "jobs_env_wrap", "hook_jobs_grid_cell_counts";

func batch_grid_cell_counts(indir, outdir=, searchstr=, mode=, cell=, file_suffix=) {
/* DOCUMENT batch_grid_cell_counts, indir, outdir=, searchstr=, mode=, cell=,
    file_suffix=

  Runs grid_cell_counts over a directory.

  Parameter:

    indir: The source directory for the data to use.

  Options:

    outdir= The output directory to use for the generated cell count grids. By
      default, files are created alongside the input files.

    searchstr= Search string for locating the appropriate data. The default is
      to use all pbd files: searchstr="*.pbd".

    mode= Data mode to use when performing cell counts. Defaults to mode="fs".

    cell= Cell size for the grids, in meters. Defaults to cell=250.

    file_suffix= The suffix to append to output file names. By default, files
      will have "_counts.pbd" appended.
*/
  t0 = array(double, 3);
  timer, t0;

  default, searchstr, "*.pbd";
  default, file_suffix, "_counts.pbd";
  if(strpart(file_suffix, -3:) != ".pbd") file_suffix += ".pbd";

  infiles = find(indir, searchstr=searchstr);
  outfiles = file_rootname(infiles) + file_suffix;
  if(outdir) outfiles = file_join(outdir, file_tail(outfiles));

  conf = save();
  count = numberof(infiles);
  for(i = 1; i <= count; i++) {
    save, conf, string(0), save(
      input=infiles(i),
      output=outfiles(i),
      command="job_grid_cell_counts",
      options=save(
        mode, cell,
        infile=infiles(i),
        outfile=outfiles(i)
      )
    );
  }

  makeflow_run, conf;
  timer_finished, t0;
}

func grid_density(data, mode=, cell=) {
/* DOCUMENT grid_density(data, mode=, cell=)

  Grids data such that the value of each cell is its density (points per meter
  squared).

  If DATA is a grid of cell counts (as from grid_cell_counts), then no other
  options are recognized.

  If DATA is an array of data (in FS, etc.), then this accepts the same options
  as grid_cell_counts.

  Returns a ZGRID value, just like other gridding functions.
*/
  if(structeq(structof(data), ZGRID)) {
    counts = data;
    cell = data.cell;
  } else {
    default, cell, 250.;
    counts = grid_cell_counts(data, mode=mode, cell=cell);
  }

  cell_area = cell * cell;
  zgrid = double(*counts.zgrid) / cell_area;

  density = counts;
  density.zgrid = &zgrid;

  return density;
}

func density_stats(data, mode=, cell=, tile=) {
/* DOCUMENT density_stats, data, mode=, cell=, tile=

  Analyzes the given data and outputs density statistics to the console.

  Parameter:
    data: An array of FS, VEG__, etc. Note: This cannot be a ZGRID value.
  Options:
    mode= Data mode to use for deriving the x,y coordinates. Elevation is not used.
    cell= Cell size to use, in meters. Default is 250. When working with tiled
      data, use a value that divides evenly into 2000 for best results.
    tile= The tile name for the data. If provided, then stats are only
      calculated over the cells that are within the tile's boundaries. However,
      the buffer region cells are still used for detecting if cells are
      interior or border.
*/
  t0 = array(double, 3);
  timer, t0;
  write, format="Calculating densities...%s", "\n";
  counts = grid_cell_counts(data, mode=mode, cell=cell);
  density = grid_density(counts);
  timer_finished, t0, fmt="Densities calculated in ELAPSED\n";

  zcounts = *counts.zgrid;
  zdensity = *density.zgrid;

  xcount = ycount = 0;
  splitary, dimsof(zcounts), , xcount, ycount;

  // Is the cell in the right tile?
  ztile = array(1, xcount, ycount);
  if(tile) {
    x = counts.xmin + indgen(0:xcount-1) * counts.cell;
    y = counts.ymin + indgen(1:ycount) * counts.cell;
    utm2dt_corners, x, y, tile_size(tile);
    bbox = tile2bbox(tile);
    tx = ty = [];
    dt2utm_corner, tile, ty, tx;
    ztile &= (x == tx)(,-);
    ztile &= (y == ty)(-,);
  }

  // Is the cell populated?
  zpop = zcounts > 0;

  // Count how many adjacent cells are populated on each of the eight sides
  zadj = array(0, xcount, ycount);
  zadj(:-1,:-1) += zpop(2:,2:);
  zadj(:-1,) += zpop(2:,);
  zadj(:-1,2:) += zpop(2:,:-1);
  zadj(,:-1) += zpop(,2:);
  zadj(,2:) += zpop(,:-1);
  zadj(2:,:-1) += zpop(:-1,2:);
  zadj(2:,) += zpop(:-1,);
  zadj(2:,2:) += zpop(:-1,:-1);

  // Interior cells are populated cells with eight populated adjacent cells
  zinterior = zpop & (zadj == 8);

  // Border cells are populated cells with fewer than eight populated adjacent cells
  zborder = zpop & (zadj < 8);

  cell_area = counts.cell ^ 2;

  write, "";
  write, format="Overall density statistics%s", "\n";
  density_stats_helper, zdensity(where(zpop & ztile)), cell_area;

  write, format="Border cell density statistics%s", "\n";
  density_stats_helper, zdensity(where(zborder & ztile)), cell_area;

  write, format="Interior cell density statistics%s", "\n";
  density_stats_helper, zdensity(where(zinterior & ztile)), cell_area;

  write, format="Cell size is %g by %g meters.\n", counts.cell, counts.cell;
  write, format="Densities are points per square meter.%s", "\n";
}

func density_stats_helper(density, cell_area) {
/* DOCUMENT density_stats_helper, density, cell_area
  Helper function for density_stats. Not intended for direct use.
*/
  if(!numberof(density)) {
    write, " No applicable cells";
    write, "";
    return;
  }
  cells = numberof(density);
  sq_m = cell_area * cells;
  sq_km = sq_m / (1000 * 1000);
  write, format="  %d cells covering %.3f sq km\n", cells, sq_km;
  write, format="  Minimum density: %.2f\n", density(min);
  write, format="  Maximum density: %.2f\n", density(max);
  write, format="  Average density: %.2f\n", density(avg);
  write, format="  Median density:  %.2f\n", median(density);
  write, "";
}
