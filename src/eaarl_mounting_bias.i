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
 ops_default = array(mission_constants);
 ops_default.roll_bias  = -1.35;
 ops_default.pitch_bias = +0.5;
 ops_default.yaw_bias   =  0.0;
 ops_default.y_offset   = -2.0;
 ops_default.x_offset   =  0.0;
 ops_default.z_offset   = -1.3;
 ops_default.scan_bias  =  0.0;
 ops_default.range_biasM = 0.7962;                 // Laser range measurement bias.
 ops_default.range_biasNS=  ops_default.range_biasM / NS2MAIR;

// Now, copy the default values to the operating values.
 ops_conf = ops_default;

func display_mission_constants( m, ytk= ) {
  write,""
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


