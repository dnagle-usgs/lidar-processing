// vim: set ts=2 sts=2 sw=2 ai sr et:
/***********************************************************************
  Range_bias computed from 7-29-02 ground test.  The EAARL data
 was taken from pulses 8716:10810 which was captured from a static
 target at 101.1256 meters measured distance.  The EAARL centroid
 range values were averaged and then the actual slope distance to
 the target subtracted to yield the range_biasM.  The rms noise on
 the range values used to compute the range_biasM was 3.19cm
  range_biasM is the measured range bias in Meters
***********************************************************************/

func mission_constants(args) {
/* DOCUMENT mission_constants(key1=val1, key2=val2, key3=val3, ...)

  Creates a struct instance with mission constants. The struct will be
  dynamically constructed using whatever key-value pairs are given.

  The type= field specifies what kind of initialization should occur. The
  initialization will make sure all fields relative to that type are present
  (and with default values, when appropriate), and it will type-cast all of the
  fields to the appropriate data types as well (for example, coercing integers
  into doubles).

  == EAARL-A ==

  By default, the struct will be set for EAARL-A (conf.type="EAARL-A"). When
  conf.type="EAARL-A", the struct is initialized with the following structure.

  struct mission_constants {
    string type;            // Type of mission settings
    string name;            // The name of the settings
    double y_offset;        // Aircraft relative + fwd along fuselage
    double x_offset;        // Aircraft relative + out the right wing
    double z_offset;        // Aircraft relative + up
    double roll_bias;       // Instrument roll mounting bias
    double pitch_bias;      // Instrument pitch mounting bias
    double yaw_bias;        // Instrument yaw (heading) mounting bias
    double scan_bias;       // Scan encoder mechanical offset from zero
    double range_biasM;     // Laser range measurement bias.
    double chn1_range_bias; // range bias for channel 1
    double chn2_range_bias; // range bias for channel 2
    double chn3_range_bias; // range bias for channel 3
    int max_sfc_sat;        // Maximum saturation allowed for first return
  }

  == EAARL-B ==

  For EAARL-B surveys, conf.type should be "EAARL-B v1". (Or if more than one
  version of EAARL-B comes along, perhaps "EAARL-B v2", etc. This allows for
  the possibility of slightly different ops_conf layouts for different EAARl-B
  configurations as the system is developed.)

  When conf.type="EAARL-B v1", the struct is initialized as above for EAARL-A,
  but with the addition of the following new fields.

    double chn4_range_bias; // range bias for channel 4
    short tx_clean;         // Specifies that transmit wf needs cleaning

  Additionally, tx_clean defaults to 8.

  If conf.type="EAARL-B", then it is changed to conf.type="EAARL-B v1".

  == Further explanation of fields ==

  ops_conf.tx_clean
    When this field is present, the transmit waveform will be cleaned up. The
    field should be an index value into the transmit waveform. The transmit
    waveform will be claned up as such:
        tx(ops_conf.tx_clean:) = tx(1)
    This eliminates noise in the transmit due to reflections from the mirrors.
*/
  conf = args2obj(args);
  defaults = save(
    type="EAARL-A",
    name=string(0),
    x_offset=0.,
    y_offset=0.,
    z_offset=0.,
    roll_bias=0.,
    pitch_bias=0.,
    yaw_bias=0.,
    scan_bias=0.,
    range_biasM=0.,
    chn1_range_bias=0.,
    chn2_range_bias=0.,
    chn3_range_bias=0.,
    max_sfc_sat=0n
  );
  conf = obj_merge(defaults, conf);
  keycast, conf, defaults;

  if(conf.type == "EAARL-B")
    save, conf, type="EAARL-B v1";

  if(conf.type == "EAARL-B v1") {
    defaults = save(
      chn4_range_bias=0.,
      tx_clean=8s
    );
    // If we do "conf = obj_merge(defaults, conf)", then the stuff in defaults
    // will come first. By using temp and then later inverting, they come last.
    temp = obj_merge(defaults, conf);
    keycast, temp, defaults;
    conf = obj_merge(conf, temp);
  }

  if(noneof([conf.chn1_range_bias, conf.chn2_range_bias, conf.chn3_range_bias])) {
    write,
       "============================================================\n" +
      " WARNING: Your ops_conf does not have valid values for\n" +
      " chn1_range_bias, chn2_range_bias, and chn3_range_bias. You\n" +
      " may also need to verify the value for max_sfc_sat.\n" +
      " ============================================================";
  }

  return obj2struct(conf, name="mission_constants");
}
wrap_args, mission_constants;

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
ops_default = mission_constants(
  range_biasM = 0.7962,
  chn1_range_bias = 0.,
  chn2_range_bias = 0.36,
  chn3_range_bias = 0.23,
  max_sfc_sat = 2
);

 ops_tans = ops_default;
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

/**************************************************************
 Now configure a default for the EAARL #1 IMU
 which is the location directly above the scanner

 The default numbers below were determined from the 9-16-03
 flight from ksby to kmyr using pospac on 10-02-2003.
**************************************************************/
 ops_IMU1 = ops_default;
 ops_IMU1.name       = "Applanix 510 Defaults"
 ops_IMU1.x_offset   =  0.470;    // This is Applanix Y Axis +Rt Wing
 ops_IMU1.y_offset   =  1.403;    // This is Applanix X Axis +nose
 ops_IMU1.z_offset   = -0.833;    // This is Applanix Z Axis +Down
 ops_IMU1.roll_bias  = -0.755;    // DMARS roll bias from 2-13-04
 ops_IMU1.pitch_bias = 0.1;      // DMARS pitch bias from 2-13-04

// Start with existing default values
 ops_IMU2 = ops_default;
 ops_IMU2.name       = "DMARS Defaults"
 ops_IMU2.roll_bias  = -0.8;    // with 03/12 Albert Whitted runway
 ops_IMU2.pitch_bias = 0.1;    // with 03/12 Albert Whitted runway
 ops_IMU2.yaw_bias   = 0;    //

func display_mission_constants( m, ytk= ) {
  if ( ytk ) {
  cmd = swrite( format="display_mission_constants { Name {%s} Roll %4.2f  Pitch %4.2f Yaw %4.2f Scanner %5.3f {Range M} %5.3f {X offset} %5.2f {Y offset} %5.2f {Z offset} %5.2f {Chn1 range bias} %5.2f {Chn 2 Range bias} %5.2f {Chn3 Range bias} %5.2f {Max sfc sat} %2d }",
      m.name,
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
  This verifies that chn1_range_bias, chn2_range_bias, and chn3_range_bias are
  properly set. Older ops_conf.i files may not have these settings defined,
  and would need to have them specified to work with the current version of
  the software.
*/
  if(noneof([conf.chn1_range_bias, conf.chn2_range_bias, conf.chn3_range_bias])) {
    write,
       "============================================================\n" +
      " WARNING: Your ops_conf does not have valid values for\n" +
      " chn1_range_bias, chn2_range_bias, and chn3_range_bias. You\n" +
      " may also need to verify the value for max_sfc_sat.\n" +
      " ============================================================";
  }
}

func l1pro_ops_conf_gui_init(nil) {
/* DOCUMENT l1pro_ops_conf_gui_init
  Glue for ::l1pro::settings::ops_conf::gui.
*/
  extern ops_conf;
  fields = get_members(ops_conf);
  fields = strjoin(fields, " ");
  tkcmd, swrite(format="::l1pro::settings::ops_conf::gui_init {%s}", fields);
}
