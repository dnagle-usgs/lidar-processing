
/*
   $Id$
*/

write, "eaarl_constants.i as of 12/22/2001"

CNS      = 0.299792458;         // speed of light/nanosecond in space
KAIR     =  1.000276
NS2MAIR  = (CNS/KAIR)*0.5
CNSH2O2X = 0.11270393157;       // two way Speed of light/ns  in water (m)
CNSH2O2XF = CNSH2O2X*3.280839895; // two way Speed of light/ns  in water (ft)

// Attenuation depths in water for calculating the bottom detection threshold
attdepth = span(0.0, 256 * CNSH2O2X, 256 );


 struct EAARL_INDEX {
   int seconds;
   int fseconds;
   int offset;
   int raster_length;
   short file_number;
   char  pixels;
   char  digitizer;
} ;

struct EDB_FILE {
  string name;
  char status;
};


struct RAST {
  int soe;                      // seconds of the epoch
  int rasternbr;                // raster number
  int digitizer;                // digitizer
  int npixels;                  // number of pixels actually in this raster
  int irange(120);              // integer range values
  int sa(120);                  // shaft angles
  double offset_time(120);      // fractional offset seconds
  int rxbias(120,4);            // receive waveform bias values
  pointer tx(120);              // transmit waveforms
  pointer rx(120,4);            // return waveforms
};


// desired graphics default settings
pldefault,marks=0



