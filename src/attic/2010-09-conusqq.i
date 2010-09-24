/******************************************************************************\
* This file was created in the attic on 2010-09-24. It contains the function   *
* get_conusqq_data and the struct CONUSQQ, both from qq24k.i. These were used  *
* for development purposes while writing the original quarter-quad related     *
* code. However, they are no longer in use and no longer needed.               *
\******************************************************************************/

// vim: set ts=3 sts=3 sw=3 ai sr et:

struct CONUSQQ {
   string   codeqq;
   double   lat;
   double   lon;
   string   name24k;
   string   state24k;
   string   code24k;
   int      utmzone;
   string   nedquad;
}

func get_conusqq_data(void) {
/* DOCUMENT get_conusqq_data()

   Loads and returns the CONUS quarter quad data from ../CONUSQQ/conusqq.pbd.
   This file can be downloaded from

      lidar.net:/mnt/alps/eaarl/tarfiles/CONUSQQ/conusqq.pbd

   It should be placed in the directory eaarl/lidar-processing/CONUSQQ/, which
   makes its relative path ../CONUSQQ/ from the perspective of Ytk (when run
   from lidar-processing/src).

   This data was collected from a shapefile provided by Jason Stoker of the
   USGS.  It uses a quarter quad tile scheme as described in calc24qq. This
   data provides additional information for each tile.

   The return data is an array of CONUSQQ.

   See also: calc24qq
*/
   fname = "../CONUSQQ/conusqq.pbd";
   if(!open(fname,"r",1)) {
      message = "The conus quarter-quad data is not available. Please download it from lidar.net:/mnt/alps/eaarl/tarfiles/CONUSQQ/conusqq.pbd and place it in the directory eaarl/lidar-processing/CONUSQQ/."
      tkcmd, "MessageDlg .conusqqerror -type ok -icon error -title {Data not available} -message {" + message + "}"
      write, format="%s\n", message;
   } else {
      restore, openb(fname), conusqq;
      return conusqq;
   }
}
