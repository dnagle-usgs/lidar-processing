// vim: set ts=2 sts=2 sw=2 ai sr et:

/*
   Batch process multiple days for fs, be, ba, and bback.
   See my_batch_vars.i for setting vars.

   You should copy both files to your home directory and
   modify to suit your task.
*/

if ( ! chstr ) {
  write, format="%s\n", "You must load a set of variables first.";
  exit, "Aborting."
} else {

  idx_dir = o_dir + "/Index_Tiles";
  bb1_tmp = o_dir + "/bb1tmp/";
  bb2_tmp = o_dir + "/bb2tmp/";
  bb1_dir = o_dir + "/bb1/";
  bb2_dir = o_dir + "/bb2/";
  edf_dir = o_dir + "/edf/";
  tif_dir = o_dir + "/tif/";
  xyz_dir = o_dir + "/xyz/";

  write, format="%s\n", "==================";
  write, format="Mission: %s\n", msn;

  my_usage;

}

/*

// RCF parameters
xywin = 700;
 zwin =  50;
min_points = 2;


// BBack parameters
bbackcell = 10;
*/

func my_show_bathy {
  mygroups=bathconf(profiles,);
  write, format="%s", "\nAll Groups: ";
  mygroups(*,);
  for ( i=1; i<= numberof(mygroups(*,)); ++i) {
    write, format="\nGroup: %s\n", mygroups(*,i);
    myprofiles=bathconf(profiles,mygroups(*,i));
    myprofiles;
  }
}

func my_usage {


  count = numberof(days);
  write, format="%s\n", "==================";
  write, format="Region file: %s\n", xyzfile;
  write, format="Region: %s\n", region(1);
  write, format="Output dir : %s\n",   o_dir;
  write, format="Tile   dir : %s\n", idx_dir;
  write, format="w84_sch: %s\n",    w84_srch;
  write, format="n88_sch: %s\n",    n88_srch;
  write, format="bathy profile: %s %s\n", use_group, use_profile;

  write, format="\n%s\n", "===== Days =======";
  for (i=1; i<=count; ++i) {
    write, format="%s\n", days(i);
  }
  write, format="%s\n", "==================";
  write, format="%s\n", "my_bback   : Process for BBack";
  write, format="%s\n", "my_bathy   : Process for Bathy";
  write, format="%s\n", "my_veg     : Process for FS or Veg";
  write, format="%s\n", "my_load_poly";
  write, format="%s\n", "my_batch   : Run mf_batch_eaarl";
  write, format="%s\n", "my_convert : Convert to wgs84 to N88";
  write, format="%s\n", "my_grids   : Generate ALPS Grids";
  write, format="%s\n", "my_tifs    : Convert grids to tifs";
  write, format="%s\n", "my_rcf     : Run batch_rcf";
  write, format="%s\n", "my_xyz     : Run batch_write_xyz";
  write, format="%s\n", "my_edf     : Run batch_pbd2edf";
  write, format="%s\n", "my_idl_tifs";

}


// Do Everything!

func my_bback {
  my_load_poly;
  my_profile;
  my_batch;
  my_convert;
  my_grids;
  my_tifs;
}

func my_bathy {
  my_load_poly;
  my_profile;
  my_batch;
  my_convert;
  my_rcf;
  my_xyz;
  my_edf;
  my_idl_tifs;
}

func my_veg {
  my_load_poly;
  my_batch;
  my_convert;
  my_rcf;
  my_xyz;
  my_edf;
  my_idl_tifs;
}

// Load Polygon file
func my_load_poly {
  if ( polyplot(exists, region)) {
    write, format="Region loaded: %s\n", region(1);
  } else {
    write, format="Loading xyz: %s\n", msn+xyzfile;
    polyplot, import, msn+xyzfile;
  }
}

func my_profile {
  write, format="Setting bathy profile: %s %s\n", use_group, use_profile;

  bathconf, profile_select,
    use_group,
    use_profile,
    eaarl_ba_plot,
    1, 60, win=25,
    xfma=1,
    channel=bath_ch;
}


// Batch process
func my_batch {
  count = numberof(days);
  for ( i=1; i<=count; ++i) {
    write, format="Loading: %s\n", days(i);
    mission, load, days(i);

    write, format="mf_batch_eaarl: %s\n", region;
    parsed = mf_batch_eaarl(
      region=region,
      mode=batch_mode,
      channel=channels,
      outdir=idx_dir,
      update = 0);
    last = parsed.log(0);
    failed = last.nodes_waiting || last.nodes_running || last.nodes_aborted;
    if ( failed ) {
      write, format="mf_batch_eaarl error: %s\n", failed;
      exit, "Stopping run\n";
    }
  }
}


func my_convert {
  write, format="Converting to NAVD88: %s\n", idx_dir;
  write, format="searchstr           : %s\n", w84_srch;
  res = batch_datum_convert(
    idx_dir,
    searchstr=w84_srch,
    update=0,
    dst_geoid="12A");
}

// mkdirp, bbedfdir

func my_grids {
  write, format="Generating ALPS grids: %s\n", bb1_tmp;

  if ( 1 ) {
    mkdirp, bb1_tmp;
    res = batch_grid(
      idx_dir,
      outdir = bb1_tmp,
      searchstr=n88_srch,
      method="cell_average",
      mode="bback1",
      toarc=1,
      nodata=-1,
      cell=bbackcell);
  }

  if ( 1 ) {
    mkdirp, bb2_tmp;
    res = batch_grid(
       idx_dir,
       outdir = bb2_tmp,
       searchstr=n88_srch,
       method="cell_average",
       mode="bback2",
       toarc=1,
       nodata=-1,
       cell=bbackcell);
  }

}

func my_tifs {
  // Convert BB grid to tiff
  if ( 1 ) {
    write, format="Generating BB1 TIFS %s\n", bb1_dir;
    mkdirp, bb1_dir;
    res = batch_convert_arcgrid2geotiff(
       bb1_tmp,
       compress=1,
       outdir=bb1_dir);
  }
  if ( 1 ) {
    write, format="Generating BB2 TIFS %s\n", bb2_dir;
    mkdirp, bb2_dir;
    res = batch_convert_arcgrid2geotiff(
       bb2_tmp,
       compress=1,
       outdir=bb2_dir);
  }
}

func my_rcf {

  write, format="RCF Filtering:\n%s\n%s\n%s\n",
    idx_dir,
    rcf_srch,
    data_mode;
  batch_rcf,
    idx_dir,
    searchstr = rcf_srch,
    mode      = data_mode,
    prefilter_max = prefilter_max,
    prefilter_min = prefilter_min,
    buf = xywin,
    w   = zwin,
    n   = min_points;
}

func my_xyz {
  write, format="Writing xyz files:\n%s\n%s\n%s\n%s\n",
    idx_dir,
    xyz_dir,
    grcf_srch,
    data_mode;

  mkdirp, xyz_dir;

  batch_write_xyz,
    idx_dir,
    outdir    = xyz_dir,
    searchstr = grcf_srch,
    extension = ".xyz",
    mode      = data_mode;
}


func my_edf {
  write, format="Generating temp EDF files: %s\n", edf_dir;

  mkdirp, edf_dir;

  res = batch_pbd2edf(
      idx_dir,
      searchstr = grcf_srch,
      outdir    = edf_dir);
}

func my_idl_tifs {
  if ( !curzone ) {
    exit, "curzone not set, aborting\n";
  }

  write, format="Generating IDL tiffs: %s\n", tif_dir;
  write, format="Generating IDL tiffs:\n%s\n%s\n%s\n%s\n",
    edf_dir,
    tif_dir,
    edf_srch,
    data_mode;

  mkdirp, tif_dir;

  system, "pgrep lmgrd || /opt/exelis/idl/bin/lmgrd";

  if (0) {
  res = idl_batch_grid(
      edf_dir,
      mode      = data_mode,
      searchstr = edf_srch,
      outdir    = tif_dir,
      cell      = tif_cell,
      maxarea   = tif_area,
      maxside   = tif_side,
      tilemode  = tif_mode,
      datum     =  1,
      buffer    =  0);
  }

  write, format="%s\n", "GZipping TIFS";
  system, "find " \
    +tif_dir \
    +" -name \*.tif -print0 | xargs -0 -P"\
    +pr1(zip_jobs)\
    +" -n 1 gzip";
//system, "gzip -fv "+tif_dir+"/*.tif";

}
