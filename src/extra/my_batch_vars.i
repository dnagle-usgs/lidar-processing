// vim: set ts=2 sts=2 sw=2 ai sr et:

/* These are example variables for my_batch.i
   Copy both files to your home directory and
   modify to suit your task.
*/

msn  = "/data/EAARL/raw/2014/CANA/";
days = [
  "2014-08-19",
  "2014-08-20-A",
  "2014-08-20-B"
];

// Select your output directory for all files and directories:
o_dir    = "/data/EAARL/Processed/CANA/mitchell";

xyzfile="soxmap/Canaveral.xyz";   // Specify a shapefile for the region to process
region=["Canaveral.xyz", ""];     // Specify which poly to process, "" for all.

  channels=[1,2,3];               // Specify which channels to process
//channels=[4];
//data_mode = "fs";               // Specify how to process
//data_mode = "be";
  data_mode = "ba";

// ======== This section should not need editing ========
  chstr="chan";
  for (i=1; i<=numberof(channels); ++i )
    chstr += pr1(channels(i));
  chstr += "_";

if ( data_mode == "fs" ) {
  batch_mode = "f";                // First Surface
} else if ( data_mode == "be" ) {
    batch_mode = "v";              // Bare Earth
} else if ( data_mode == "ba" ) {
    batch_mode = "b";              // Bathy
} else {
  exit, "Unknown data_mode\n";
}

  w84_ss ="*w84*"+chstr+batch_mode+".pbd";
  n88_ss ="*n88*"+chstr+batch_mode+".pbd";
  rcf_ss ="*n88*"+chstr+batch_mode+".pbd";

  grcf_ss="*n88*"+chstr+"*grcf.pbd";
  edf_ss ="*n88*"+chstr+"*grcf.edf";
// ======== End Section =================================




// Bathy configuration settings
// These values are pulled from your .bathconf file.
// Run: my_show_bathy to show what is currently loaded.

groups=[
  "ch1",
  "ch2",
  "ch3",
  "ch4"
];
use_ch=groups(4);   // select 1 from groups.
bath_ch=4;

profiles=[
  "BBack",
  "ASIS-Ocean-Side"
];
use_profile = profiles(2);  // select 1 profile


// BBack parameters
bbackcell = 10;


// RCF Parameters
if ( data_mode == "ba" ) {
  xywin = 500;
  zwin =  20;
  min_points = 3;
  prefilter_max = -0.3;
  prefitler_min = -5.0;
} else {
  xywin = 700;
  zwin = 200;
  min_points = 2;
  prefilter_max = 30.0;
  prefitler_min = -1.0;
}


// TIN and TIF Parameters
tif_cell =   2.5;
tif_side =  15.0;
tif_area = 100;
tif_mode =   2;

zip_jobs = 12;
