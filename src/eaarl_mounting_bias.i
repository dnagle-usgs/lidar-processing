/***********************************************************************
 $Id$


   Range_bias computed from 7-29-02 ground test.  The EAARL data 
 was taken from pulses 8716:10810 which was captured from a static 
 target at 101.1256 meters measured distance.  The EAARL centroid 
 range values were averaged and then the actual slope distance to 
 the target subtracted to yield the range_biasM.  The rms noise on 
 the range values used to compute the range_biasM was 3.19cm
   range_biasM is the measured range bias in Meters, and range_biasNS 
 is the same bias expressed in Nanoseconds.
***********************************************************************/

write,"$Id$"

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
  float range_biasNS; // range_biasM / NS2MAIR;
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
 ops_tans = array(mission_constants);
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
 ops_tans.range_biasNS=  ops_default.range_biasM / NS2MAIR;

// Now, copy the default values to the operating values.
 ops_conf = ops_default = ops_tans;

/**************************************************************
 Now configure a default for the EAARL #1 IMU
 which is the location directly above the scanner

 The default numbers below were determined from the 9-16-03
 flight from ksby to kmyr using pospac on 10-02-2003.
**************************************************************/
 ops_IMU1 = ops_default;
 ops_IMU1.name       = "Applanix 510 Defaults"
 ops_tans.varname    = "ops_IMU1"
 ops_IMU1.x_offset   =  0.470;    // This is Applanix Y Axis +Rt Wing
 ops_IMU1.y_offset   =  1.403;    // This is Applanix X Axis +nose
 ops_IMU1.z_offset   = -0.833;    // This is Applanix Z Axis +Down
 ops_IMU1.roll_bias  = -0.755;    // DMARS roll bias from 2-13-04
 ops_IMU1.pitch_bias = 0.1;      // DMARS pitch bias from 2-13-04


 ops_IMU2 = ops_default;
 ops_IMU2.name       = "DMARS Defaults"
 ops_IMU2.varname    = "ops_IMU2"
 ops_IMU2.roll_bias  = -0.8;    // with 03/12 Albert Whitted runway
 ops_IMU2.pitch_bias = 0.1;    // with 03/12 Albert Whitted runway
 ops_IMU2.yaw_bias   = 0;    // 

func display_mission_constants( m, ytk= ) {
  if ( ytk ) {
  cmd = swrite( format="display_mission_constants { Name {%s} {VarName} %s Roll %4.2f  Pitch %4.2f Yaw %4.2f Scanner %5.3f {Range M} %5.3f {Range NS} %5.3f {X offset} %5.2f {Y offset} %5.2f {Z offset} %5.2f }",
	m.name,
	m.varname,
        m.roll_bias,
        m.pitch_bias,
        m.yaw_bias,
        m.scan_bias,
        m.range_biasM,
        m.range_biasNS,
        m.x_offset,
        m.y_offset,
        m.z_offset );
      tkcmd, cmd
  } else {
  write,format="\nMounting Bias Values: %s\n", m.name
  write, "____________________BIAS__________________     _____Offsets_____"
  write, "Roll Pitch Heading Scanner  RangeM RangeNS      X     Y     Z"
  write, format="%4.2f  %4.2f    %4.2f  %5.3f    %5.3f   %5.3f    %5.2f %5.2f %5.2f\n",
        m.roll_bias,
        m.pitch_bias,
        m.yaw_bias,
        m.scan_bias,
        m.range_biasM,
        m.range_biasNS,
        m.x_offset,
        m.y_offset,
        m.z_offset

  write,""
  }
}


