// vim: set ts=3 sts=3 sw=3 ai sr et:
/***********************************************************************
   Range_bias computed from 7-29-02 ground test.  The EAARL data 
 was taken from pulses 8716:10810 which was captured from a static 
 target at 101.1256 meters measured distance.  The EAARL centroid 
 range values were averaged and then the actual slope distance to 
 the target subtracted to yield the range_biasM.  The rms noise on 
 the range values used to compute the range_biasM was 3.19cm
   range_biasM is the measured range bias in Meters
***********************************************************************/

// Mission configuration data structure.
struct mission_constants {
  string name;		// The name of the settings
  string varname;	// The name of this variable 
  float y_offset;    // Aircraft relative + fwd along fuselage 
  float x_offset;    // Aircraft relative + out the right wing
  float z_offset;    // Aircraft relative + up  
  float roll_bias;   // Instrument roll mounting bias 
  float pitch_bias;  // Instrument pitch mounting bias
  float yaw_bias;    // Instrument yaw (heading) mounting bias
  float scan_bias;   // Scan encoder mechanical offset from zero 
  float range_biasM; //  Laser range measurement bias.
  float range_biasNS; //  Laser range measurement bias in NS
  float chn1_range_bias; // range bias for channel 1
  float chn2_range_bias; // range bias for channel 2
  float chn3_range_bias; // range bias for channel 3
  int max_sfc_sat;	// maximum saturation allowed for first return
}


/*************************************************************
 Default operations constants.  These should not be modified
 in this file. To "customize" these on a mission to mission
 basis, create a "*-conf.i" file in the mission root directory
 have that file, for example, first execute:

  tans_config = ops_default;

which will preload your new config file with the default values
and then simply set only parameters that need changing in your
new config structure.  

for example, perhaps you need a slightly different roll_bias
and pitch_bias value for your data set in which case your
custom file should have:

  tans_config = ops_default;
  tans_config.roll_bias  = -1.55;
  tans_config.pitch_bias = -0.1;


The intention of this is to permit multiple configurations to 
exist at the same time and to allow easy switching between 
those configurations.  New configurations will exist for the 
Applanix, and for the new Inertial Science DTG unit.  If and 
when the EAARL system is ever installed on an different aircraft 
a new configuration file will need to be created with new values 
for the angle biases and the x,y and z offsets.

 The body coords. system of the plane is as follows:

 +X  Out the right wing.
 +Y  Forward along the fuselage
 +Z  Up.

 
*************************************************************/
 ops_default = array(mission_constants);
 ops_default.range_biasM =   0.7962;         // Laser range measurement bias.

// chn range bias and max_sfc_sat settings are set by default to the values
// below to allow backward compatibility.  The older ops_conf.i files did not
// have these values set.  If these values remain -999 and -1 by default, then
// the functions that use them will change it to the expected value
// (0,0.36,0.23 for chn range biases and 2 for max_sfc_sat)

 ops_default.chn1_range_bias = -999;
 ops_default.chn2_range_bias = -999;
 ops_default.chn3_range_bias = -999;
 ops_default.max_sfc_sat = -1;

 ops_tans = array(mission_constants);
 ops_tans = ops_default;
 ops_tans.varname    = "ops_tans"
 ops_tans.name       = "Tans Default Values"
 ops_tans.roll_bias  = -1.40;        // carefully tweaked on 2-18-03 data
 ops_tans.pitch_bias = +0.5;
 ops_tans.yaw_bias   =  0.0;
 ops_tans.y_offset   = -1.403;	// From Applanix pospac
 ops_tans.x_offset   =  -.470;       // From Applanix pospac
 ops_tans.z_offset   = -1.3;		// should be -1.708... but need better 
                                        // measurement of IMU to laser point
 ops_tans.scan_bias  =  0.0;
 ops_tans.range_biasM = 0.7962;         // Laser range measurement bias.

// Now, copy the default values to the operating values.
 ops_conf = ops_tans;

 func opscpy( d, s ) {
/* DOCUMENT opscpy( d, s ) 

  Documentation goes here.
*/
   tmp1 = d.varname;
	 tmp2 = d.name;
	 tmp1;
	 tmp2;
	 d = s;
	 d.varname = tmp1;
	 d.name    = tmp2;
	 d;
	 return(d);
 }

/**************************************************************
 Now configure a default for the EAARL #1 IMU
 which is the location directly above the scanner

 The default numbers below were determined from the 9-16-03
 flight from ksby to kmyr using pospac on 10-02-2003.
**************************************************************/
 ops_IMU1 = ops_default;
 ops_IMU1.name       = "Applanix 510 Defaults"
 ops_IMU1.varname    = "ops_IMU1"
 ops_IMU1.x_offset   =  0.470;    // This is Applanix Y Axis +Rt Wing
 ops_IMU1.y_offset   =  1.403;    // This is Applanix X Axis +nose
 ops_IMU1.z_offset   = -0.833;    // This is Applanix Z Axis +Down
 ops_IMU1.roll_bias  = -0.755;    // DMARS roll bias from 2-13-04
 ops_IMU1.pitch_bias = 0.1;      // DMARS pitch bias from 2-13-04

// Start with existing default values
 ops_IMU2 = ops_default;
 ops_IMU2.name       = "DMARS Defaults"
 ops_IMU2.varname    = "ops_IMU2"
 ops_IMU2.roll_bias  = -0.8;    // with 03/12 Albert Whitted runway
 ops_IMU2.pitch_bias = 0.1;    // with 03/12 Albert Whitted runway
 ops_IMU2.yaw_bias   = 0;    // 

func display_mission_constants( m, ytk= ) {
  if ( ytk ) {
  cmd = swrite( format="display_mission_constants { Name {%s} VarName %s Roll %4.2f  Pitch %4.2f Yaw %4.2f Scanner %5.3f {Range M} %5.3f {X offset} %5.2f {Y offset} %5.2f {Z offset} %5.2f {Chn1 range bias} %5.2f {Chn 2 Range bias} %5.2f {Chn3 Range bias} %5.2f {Max sfc sat} %2d }", 
        m.name,
	m.varname,
        m.roll_bias,
        m.pitch_bias,
        m.yaw_bias,
        m.scan_bias,
        m.range_biasM,
        m.x_offset,
        m.y_offset,
        m.z_offset, 
		  m.chn1_range_bias,
		  m.chn2_range_bias,
		  m.chn3_range_bias,
		  m.max_sfc_sat);
      tkcmd, cmd
  } else {
  write,format="\nMounting Bias Values: %s\n", m.name
  write, "____________________BIAS__________________________   _____Offsets_____"
  write, "Roll Pitch Heading Scanner  RangeM  Chn1   Chn2   Chn3     X     Y     Z Max_Sfc_Sat"
  write, format="%4.2f  %4.2f    %4.2f  %5.3f  %5.3f %5.3f %5.3f    %5.2f %5.2f %5.2f   %3d\n",
        m.roll_bias,
        m.pitch_bias,
        m.yaw_bias,
        m.scan_bias,
        m.range_biasM,
		  m.chn1_range_bias,
		  m.chn2_range_bias,
		  m.chn3_range_bias,
        m.x_offset,
        m.y_offset,
        m.z_offset,
		  m.max_sfc_sat

  write,""
  }
}

func load_ops_conf(fn) {
/* DOCUMENT conf = load_ops_conf(fn)
   -or-  load_ops_conf, fn
   Loads and returns a set of mission constants from a file. If called as a
   function, the settings will be returned and no externs will be altered. If
   called as a subroutine, then the extern ops_conf will be overwritten.
*/
   local ops_conf;
   // include, fn, 0 --> goes to global scope
   // include, fn, 1 --> goes to local scope
   include, fn, !am_subroutine();
   return ops_conf;
}

func write_ops_conf(fn, conf=) {
/* DOCUMENT write_ops_conf, fn, conf=
   -or- write_ops_conf, conf=

   Allows you to write a set of mission constants to file. By default, it will
   write out the constants in ops_conf; however, you can override that with the
   conf= option.

   If you provide an argument, it should be the filename to write the conf file
   to. Otherwise, it will print it to the screen.
*/
   extern ops_conf;
   default, conf, ops_conf;

   ops = swrite(format="%s", print(conf)(sum));
   if(!regmatch("mission_constants\\((.*)\\)", ops, , params))
      error, "Invalid ops_conf!";
   params = strjoin(strsplit(params, ","), ",\n  ");

   f = [];
   if(is_string(fn))
      f = open(fn, "w");
   write, f, format="// Exported from ALPS on %s\n", soe2date(getsoe());
   write, f, format="ops_conf = mission_constants(\n  %s\n)\n", params;
   if(f) close, f;
}

func ops_conf_validate(&conf) {
/* DOCUMENT ops_conf_validate, conf;
   The channel range biases and the max_sfc_sat setting are set by default to
   flag values to allow for backwards compatibility with old ops_conf.i files
   that do not have the values set.

   This function detects the flag values and converts them to proper values.

   Setting           Flag value     Converted value
   chn1_range_bias   -999           0.
   chn2_range_bias   -999           0.36
   chn3_range_bias   -999           0.23
   max_sfc_sat       -1             2
*/
   if(conf.chn1_range_bias == -999)
      conf.chn1_range_bias = 0.;
   if(conf.chn2_range_bias == -999)
      conf.chn2_range_bias = 0.36;
   if(conf.chn3_range_bias == -999)
      conf.chn3_range_bias = 0.23;
   if(conf.max_sfc_sat == -1)
      conf.max_sfc_sat = 2;
}
