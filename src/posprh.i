
/*

   $Id$

  Original: W. Wright 8/7/2003

 Simple Yorick program to read in Applanix data as converted from
 Applanix "ben" to EAARL posprh format.


 The structure that will be read by ALPS
 to convert angles to double multiply by 360.0*2^31
struct POSPRH {
  unsigned long  somd;   // lsb = 1 second
  unsigned long fsecs;   // lsb = 1e-9
  long            alt;   // lsb =  .001 meters (1mm)   *1e-3 for meters
  long          pitch;   // lsb on all angles = (360.0 / 2.0^31)
  long           roll;
  long        heading;
  long            lat;
  long            lon;
} posprh;

*/


func load_posprh {
 extern posprh,
        posprh_somd, 
        posprh_alt,
        posprh_pitch,
        posprh_roll,
        posprh_heading,
        posprh_lat,
        posprh_lon;

 raw2d = (360.0/2.0^31);

// Get the start index, and number of records
  fn = ""
  read( prompt="Enter the file name:", format="%s", fn);
  number=start=int();
  f = open( fn, "r");
  write,format="Read data start and record_count from %s\n",fn
  read,f,format="%x %x", start, number

// Now, create the array, reopen the file binary, and read the data in
 posprh = array(long, 8, number)
 f = open(fn, "rb");
  write,"Reading the scaled data..."
 _read,f,start,posprh
write,"Read complete...."

write,format="Converting..%s", "time.."
 posprh_somd = posprh(1,) + posprh(2,)*1.0e-9;

write,format="%s","alt.."
 posprh_alt  = posprh(3,) * 1.0e-3;

write,format="%s","pitch.."
 posprh_pitch  = double(posprh(4,)) * raw2d;

write,format="%s","Roll.."
 posprh_roll  = posprh(5,) * raw2d;

write,format="%s","Heading.."
 posprh_heading  = posprh(6,)  * raw2d;

write,format="%s", "Latitude.."
 posprh_lat  = posprh(7,) * raw2d;

write,format="%s","Longitude\n"
 posprh_lon  = posprh(8,) * raw2d;

write, "Engineering units data now in: posprh_{somd,alt,pitch,roll,heading,lat,lon}"
write, "Scaled fixed point binary in posprh()"
posprh_help;
}


func posprh_help {
write,""
write,"$Id$"
write,"Type: load_posprh                                      to load some data"
write,"      plg,posprh_lat, posprh_lon,marks=0;              to see the flight track"
write,"      plg,posprh_roll,posprh_somd,marks=0;             to see roll"
write,"      plg,posprh_pitch,posprh_somd,marks=0;            to see pitch"
write,"      plg,posprh_heading,posprh_somd,marks=0;          to see heading"
write,"      plg,posprh_alt,posprh_somd,marks=0;              to see altitude"
write,"      plg,posprh_somd(dif),posprh_somd(1:-1),marks=0;  to see time diff"
write,"      posprh_help                                      for help"
}

posprh_help;

