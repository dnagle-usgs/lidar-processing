// vim: set ts=2 sts=2 sw=2 ai sr et:

local eaarl_structs, eaarl_structs_i;
/* DOCUMENT eaarl_structs.i
  File eaarl_structs.i contains the definitions for many of the Yorick
  structures used throughout ALPS. It contains all point-cloud oriented
  structures as well as many others.

  This file explicitly does *not* include binary file specific structures such
  as those used for EDF and LAS files. It also does not include other
  specific-purpose structures.

  For a list of all structures defined in your current ALPS session, run this:
    > write, format="%s\n", symbol_names(64)
*/

local POINTCLOUD;
/* DOCUMENT
  Transitional structure for point cloud data. This will supercede FS, VEG__,
  GEO, etc. as well as their raster-oriented counterparts.

  struct POINTCLOUD {
    double mx, my, mz;      mirror coordinates
    double fx, fy, fz;      first return coordinates
    double lx, ly, lz;      last return coordinates
    double soe;             seconds of epoch
    long rn;                legacy: raster + pulse << 24
    long raster_seconds;    raster_seconds+raster_fseconds replace rn and
    long raster_fseconds;     allow unique lookups
    char pulse, channel;    pulse number and channel number
    char digitizer;         digitizer used
    float fint, lint;       first/last intensity value (return)
    float ftx, frx;         first transmit/return index in waveform
    float ltx, lrx;         last transmit/return index in waveform
    char nx;                number of returns detected
  }
*/

struct POINTCLOUD {
  double mx, my, mz;
  double fx, fy, fz;
  double lx, ly, lz;
  char zone;
  double soe;
  long rn;
  long raster_seconds;
  long raster_fseconds;
  char pulse, channel;
  char digitizer;
  float fint, lint;
  float ftx, frx;
  float ltx, lrx;
  char nx;
}

local FS;
/* DOCUMENT
  Point structure for first returns. (Note that struct VEG__ also is used for
  first returns.)

  struct FS {
    long rn;             raster + pulse << 24
    long mnorth;         mirror northing
    long meast;          mirror east
    long melevation;     mirror elevation
    long north;          surface north
    long east;           surface east
    long elevation;      surface elevation (m)
    short intensity;     surface return intensity
    double soe;          seconds of the epoch
  };

  SEE ALSO: R, VEG__, GEO
*/

struct FS {
  long rn;
  long mnorth, meast, melevation;
  long north, east, elevation;
  short intensity;
  double soe;
}

local VEG__, VEG_, VEG;
/* DOCUMENT
  Point structures for topo under veg.

  The primary structure currently used is VEG__, which encodes the first,
  last, and mirror coordinates.

  struct VEG__ {
    long rn;          raster + pulse << 24
    long north;       surface northing (cm)
    long east;        surface easting (cm)
    long elevation;   surface elevation (cm)
    long mnorth;      mirror northing (cm)
    long meast;       mirror easting (cm)
    long melevation;  mirror elevation (cm)
    long lnorth;      bottom northing (cm)
    long least;       bottom easting (cm)
    long lelv;        bottom elevation (cm)
    short fint;       first return pulse peak value
    short lint;       last return pulse peak value
    char nx;          number of return pulses found
    double soe;       seconds of the epoch
  }

  Older data may use VEG_ instead. VEG_ is no longer in use, and is documented
  here primarily for historic reasons and backwards compatibility.

  struct VEG_ {
    long rn;          raster + pulse << 24
    long north;       surface northing in centimeters
    long east;        surface easting in centimeters
    long elevation;   first surface elevation in centimeters
    long mnorth;      mirror northing
    long meast;       mirror easting
    long melevation;  mirror elevation
    long felv;        irange value in ns
    short fint;       first pulse peak value
    long lelv;        last return in centimeters
    short lint;       last return pulse peak value
    char nx;          number of return pulses found
    double soe;       seconds of the epoch
  };

  Even older data may use VEG, which is almost identical to VEG_ but has two
  fields with different types/meanings:

    short felv;       first pulse index
    short lelv;       last pulse index

  SEE ALSO: VEG_ALL_, R, GEO
*/

struct VEG__ {
  long rn;
  long north, east, elevation;
  long mnorth, meast, melevation;
  long lnorth, least, lelv;
  short fint, lint;
  char nx;
  double soe;
}

struct VEG_ {
  long rn;
  long north, east, elevation;
  long mnorth, meast, melevation;
  long felv;
  short fint;
  long lelv;
  short lint;
  char nx;
  double soe;
}

struct VEG {
  long rn;
  long north, east, elevation;
  long mnorth, meast, melevation;
  short felv, fint, lelv, lint;
  char nx;
  double soe;
}

local GEO;
/* DOCUMENT
  Point structure for bathymetry.

  struct GEO {
    long rn;             raster + pulse << 24
    long north;          surface northing in cm
    long east;           surface easting in cm
    short sr2;           slant range first to last return in ns*10
    long elevation;      first surface elevation in cm
    long mnorth;         mirror northing
    long meast;          mirror easting
    long melevation;     mirror elevation
    short bottom_peak;   peak amplitude of bottom return signal
    short first_peak;    peak amplitude of first surface return signal
    long bath;           unused?
    short depth;         water depth in cm
    double soe;          seconds of the epoch
  }

  SEE ALSO: GEOALL, R, VEG__
*/
struct GEO {
  long rn;
  long north, east;
  short sr2;
  long elevation;
  long mnorth, meast, melevation;
  short bottom_peak, first_peak;
  long bath;
  short depth;
  double soe;
}

local R;
/* DOCUMENT
  Raster structure for first returns. (Note that struct VEG_ALL_ also is used
  for first returns.)

  struct R {
    long rn(120);                 raster + pulse << 24
    long mnorth(120);             mirror northing
    long meast(120);              mirror east
    long melevation(120);         mirror elevation
    long north(120);              surface north
    long east(120);               surface east
    long elevation(120);          surface elevation (m)
    short intensity(120);         surface return intensity
    short fs_rtn_centroid(120);   surface return centroid location w/in waveform
    double soe(120);              seconds of the epoch
  };

  SEE ALSO: FS, VEG_ALL_, GEOALL
*/

struct R {
  long rn(120);
  long mnorth(120), meast(120), melevation(120);
  long north(120), east(120), elevation(120);
  short intensity(120), fs_rtn_centroid(120);
  double soe(120);
};

local VEG_ALL_, VEG_ALL, VEGALL;
/* DOCUMENT
  Raster structures for topo under veg.

  The primary structure currently used is VEG_ALL_, which encodes the first,
  last, and mirror coordinates.

  struct VEG_ALL_ {
    long rn(120);           raster + pulse << 24
    long north(120);        surface northing in centimeters
    long east(120);         surface easting in centimeters
    long elevation(120);    first surface elevation in centimeters
    long mnorth(120);       mirror northing
    long meast(120);        mirror easting
    long melevation(120);   mirror elevation
    long lnorth(120);       bottom northing in centimeters
    long least(120);        bottom easting in centimeters
    long lelv(120);         last return in centimeters
    short fint(120);        first pulse peak value
    short lint(120);        last return pulse peak value
    char nx(120);           number of return pulses found
    double soe(120);        seconds of the epoch
  };

  Older data may use VEGALL instead. VEGALL is no longer in use, and is
  documented here primarily for historic reasons and backwards compatibility.

  struct VEG_ALL {
    long rn(120);           raster + pulse << 24
    long north(120);        surface northing in centimeters
    long east(120);         surface easting in centimeters
    long elevation(120);    first surface elevation in centimeters
    long mnorth(120);       mirror northing
    long meast(120);        mirror easting
    long melevation(120);   mirror elevation
    long felv(120);         irange value in ns
    short fint(120);        first pulse peak value
    long lelv(120);         last return in centimeters
    short lint(120);        last return pulse peak value
    char nx(120);           number of return pulses found
    double soe(120);        seconds of the epoch
  };

  Even older data may use VEGALL, which is almost identical to VEG_ALL but has
  two fields with different types/meanings:

    short felv(120);        first pulse index
    short lelv(120);        last pulse index

  SEE ALSO: VEG__, R, GEOALL
*/

struct VEG_ALL_ {
  long rn(120);
  long north(120), east(120), elevation(120);
  long mnorth(120), meast(120), melevation(120);
  long lnorth(120), least(120), lelv(120);
  short fint(120), lint(120);
  char nx(120);
  double soe(120);
};

struct VEG_ALL {
  long rn(120);
  long north(120), east(120), elevation(120);
  long mnorth(120), meast(120), melevation(120);
  long felv(120);
  short fint(120);
  long lelv(120);
  short lint(120);
  char nx(120);
  double soe(120);
};

struct VEGALL {
  long rn(120);
  long north(120), east(120), elevation(120);
  long mnorth(120), meast(120), melevation(120);
  short felv(120), fint(120), lelv(120), lint(120);
  char nx(120);
  double soe(120);
};


local GEOALL;
/* DOCUMENT
  Raster structure for bathymetry.

  struct GEOALL {
    long rn (120);             raster + pulse << 24
    long north(120);           surface northing in cm
    long east(120);            surface easting in cm
    short sr2(120);            slant range first to last return in ns*10
    long elevation(120);       first surface elevation in cm
    long mnorth(120);          mirror northing
    long meast(120);           mirror easting
    long melevation(120);      mirror elevation
    short bottom_peak(120);    peak amplitude of bottom return signal
    short first_peak(120);     peak amplitude of first surface return signal
    int depth(120);            water depth in cm
    double soe(120);           seconds of the epoch
  }

  Several changes have been made to this structure over time:
    2009-03-21: depth changed from short to int (RWM)
    2005-01-28: slant range modified by a factor of 10 to increase accuracy
      of range vector (AN)

  SEE ALSO: GEO, R, VEG_ALL_
*/

struct GEOALL {
  long rn (120);
  long north(120), east(120);
  short sr2(120);
  long elevation(120);
  long mnorth(120), meast(120), melevation(120);
  short bottom_peak(120), first_peak(120);
  int depth(120);
  double soe(120);
}

local CVEG_ALL;
/* DOCUMENT

  struct CVEG_ALL {
    long rn;          raster + pulse << 24
    long north;       target northing in centimeters
    long east;        target easting in centimeters
    long elevation;   target elevation in centimeters
    long mnorth;      mirror northing
    long meast;       mirror easting
    long melevation;  mirror elevation
    short intensity;  pulse peak intensity value
    char nx;          number of return pulses found
    double soe;       Seconds of the epoch
  };
*/

struct CVEG_ALL {
  long rn;
  long north, east, elevation;
  long mnorth, meast, melevation;
  short intensity;
  char nx;
  double soe;
};

local LFP_VEG;
/* DOCUMENT
  Structure for large-footprint vegetation. Primarily used in veg_energy.i.

  struct LFP_VEG {
    long north;          footprint northing in cm
    long east;           footprint easting in cm
    pointer rx;          ?
    pointer npixels;     number of 1ns returns in each vertical bin
    pointer elevation;   ?
    long npix;           number of returns in the composite footprint
  }
*/

struct LFP_VEG {
  long north, east;
  pointer rx, npixels, elevation;
  long npix;
}

local EAARL_INDEX;
/* DOCUMENT
  Structure for indexing into TLD files to retrieve waveforms.

  struct EAARL_INDEX {
    int seconds;         seconds of the epoch
    int fseconds;        fractional seconds (1e-6)
    int offset;          offset in file to raster data
    int raster_length;   length of raster
    short file_number;   file raster is in (index into array of filenames)
    char pixels;         pixel count for this raster
    char digitizer;      digitizer used
  };

  SEE ALSO: edb_open load_edb
*/
struct EAARL_INDEX {
  int seconds;
  int fseconds;
  int offset;
  int raster_length;
  short file_number;
  char pixels;
  char digitizer;
};

local RAST;
/* DOCUMENT
  Structure for raw waveform raster data.

  struct RAST {
    int soe;                   seconds of the epoch
    int rasternbr;             raster number
    int digitizer;             digitizer
    int npixels;               number of pixels actually in this raster
    int irange(120);           integer range values
    int sa(120);               shaft angles
    double offset_time(120);   fractional offset seconds
    int rxbias(120,4);         receive waveform bias values
    pointer tx(120);           transmit waveforms
    pointer rx(120,4);         return waveforms
  };

  SEE ALSO: decode_raster
*/
struct RAST {
  int soe, rasternbr, digitizer, npixels;
  int irange(120), sa(120);
  double offset_time(120);
  int rxbias(120,4);
  pointer tx(120), rx(120,4);
};

local ZGRID;
/* DOCUMENT
  This structure is used for gridded data.

  struct ZGRID {
    double xmin;      Lower-left corner, x-coordinate
    double ymin;      Lower-left corner, y-coordinate
    double cell;      Size of cell (must be square)
    double nodata;    The value given to cells that have no data
    pointer zgrid;    Pointer to an array of doubles or floats for elevations
  }

  The cell size is the distance between rows/columns in zgrid. Each cell's
  location can be determined based on xmin/ymin, cell, and their row/column.

  The value for each zgrid location is the *center* of a cell. xmin/ymin
  define the lower-left *corner* of the lower-left cell.
*/
struct ZGRID {
  double xmin, ymin, cell, nodata;
  pointer zgrid;
}
