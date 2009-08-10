#!/bin/gawk -f

# Orginal: W. Wright 9/27/2003
# Read the output from ngs "htdp" program
# See http://www.ngs.noaa.gov/TOOLS/Htdp/Htdp.html
# for info on it.
#
# This program was written to read one of Mark Hansen's datasets.
#
# Usage:
#   htdp <htpddatafile >outputfile.dat
#
# A record of output from htdp looks like this:
# -25.694                 
#  LATITUDE     26 23 26.88000 N     26 23 26.89754 N      0.00 mm/yr  north
#  LONGITUDE    81 53  0.49200 W     81 53  0.50623 W      0.00 mm/yr  east
#  ELLIP. HT.            -25.694            -27.279 m      0.00 mm/yr  up
#  X                  807191.587         807190.963 m      0.00 mm/yr
#  Y                -5659917.460       -5659915.873 m      0.00 mm/yr
#  Z                 2817900.689        2817900.468 m      0.00 mm/yr
#
# and this program reads the latitude, longitude and elevation
# from the right most column and converts the lat/lon values
# to decimal degrees then outputs each record on one line.  Example
# output follows:
#
#  Lat         Lon       Elev.
#  26.39051   -81.88416 -26.877
#  26.39052   -81.88413 -27.157
#  26.39053   -81.88410 -27.347
#  26.39054   -81.88407 -27.348
#  26.39055   -81.88404 -27.358
#  26.39057   -81.88401 -27.388



BEGIN {
  CONVFMT = "%.12g"
  OFMT  = "%.12g"
}

/LATITUDE/{ 
  dlat = $6 + ($7 + $8/60.0)/60.0;
  printf "\n%10.5f ", dlat
}

/LONGITUDE/ {
  dlon = -($6 + ($7 + $8/60.0)/60.0);
  printf " %10.5f", dlon

}

/ELLIP. HT./ {
  printf " %6.3f", $4
}


