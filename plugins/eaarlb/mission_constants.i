// vim: set ts=2 sts=2 sw=2 ai sr et:

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
    short minsamples;       // Minimum samples required for waveform
  }

  Additionally, the following are given defaults as follows.

    chn1_range_bias=0.
    chn2_range_bias=0.36
    chn3_range_bias=0.23
    max_sfc_sat=2

  == EAARL-B ==

  For EAARL-B surveys, conf.type should be "EAARL-B v1". (Or if more than one
  version of EAARL-B comes along, perhaps "EAARL-B v2", etc. This allows for
  the possibility of slightly different ops_conf layouts for different EAARL-B
  configurations as the system is developed.)

  When conf.type="EAARL-B v1", the struct is initialized as above for EAARL-A,
  but with the addition of the following new fields.

    double chn4_range_bias; // range bias for channel 4
    double chn1_dx;         // channel 1 spacing from center in x direction
    double chn1_dy;         // channel 1 spacing from center in y direction
    double chn2_dx;         // channel 2 spacing from center in x direction
    double chn2_dy;         // channel 2 spacing from center in y direction
    double chn3_dx;         // channel 3 spacing from center in x direction
    double chn3_dy;         // channel 3 spacing from center in y direction
    double chn4_dx;         // channel 4 spacing from center in x direction
    double chn4_dy;         // channel 4 spacing from center in y direction
    double delta_ht;        // flight height assumed for channel spacing
    short tx_clean;         // specifies that transmit wf needs cleaning
    short dmars_invert;     // if 1, then invert the dmars when loaded
    short use_ins_for_gps;  // if 1, then use tans instead of pnav for georef

  Additionally, the following are given defaults as follows.

    chn1_range_bias=-13.480
    chn2_range_bias=-12.105
    chn3_range_bias=-10.564
    chn4_range_bias=-18.985
    max_sfc_sat=2
    tx_clean=8
    dmars_invert=0
    use_ins_for_gps=0
    chn1_dx=-0.42
    chn1_dy=-1.67
    chn2_dx=0
    chn2_dy=0
    chn3_dx=-0.42
    chn3_dy=1.67
    chn4_dx=0
    chn4_dy=0
    delta_ht=300

  If conf.type="EAARL-B", then it is changed to conf.type="EAARL-B v1".

  == Further explanation of fields ==

  ops_conf.x_offset, ops_conf.y_offset, ops_conf.z_offset
    These represent then distance from the GPS antenna (or INS center) to the
    mirror exit.

  ops_conf.minsamples
    If a waveform has fewer than this many samples, it is completely rejected.
    This was implemented to solve the issue that arises when the plane rolls
    enough that the surface is outside of its maximum range gate. When this
    happens, we get very short waveforms containing just noise (because they're
    well above the surface).

  ops_conf.tx_clean
    When this field is present, the transmit waveform will be cleaned up. The
    field should be an index value into the transmit waveform. The transmit
    waveform will be claned up as such:
        tx(ops_conf.tx_clean:) = tx(1)
    This eliminates noise in the transmit due to reflections from the mirrors.

  ops_conf.dmars_invert
    If set to 1, then the DMARS INS data will be inverted when loading. This
    does the following operations:
      tans.pitch *= -1
      tans.roll *= -1
      tans.heading = (tans.heading + 180) % 360
    This compensates for the INS being mounted in the opposite direction as is
    traditionally expected. This compensation is only necessary if it is not
    applied when processing the trajectory in Inertial Explorer.

  use_ins_for_gps
    If set to 1, then the INS data will be used for determining the mirror
    position instead of the PNAV data. This means that the mounting biases
    (*_offset) are the distance between the mirror and the INS system. (When
    set to 0 or omitted, the offsets are the distance between the mirror and
    the GPS antenna.)
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
    max_sfc_sat=2n,
    minsamples=0s
  );
  conf = obj_merge(defaults, conf);
  keycast, conf, defaults;

  if(conf.type == "EAARL-B v1")
    save, conf, type="EAARL-B";

  if(conf.type == "EAARL-A") {
    defaults = save(
      chn1_range_bias=0.,
      chn2_range_bias=0.36,
      chn3_range_bias=0.23
    );
    // If we do "conf = obj_merge(defaults, conf)", then the stuff in defaults
    // will come first. By using temp and then later inverting, they come last.
    temp = obj_merge(defaults, conf);
    keycast, temp, defaults;
    conf = obj_merge(conf, temp);
  }
  if(conf.type == "EAARL-B") {
    defaults = save(
      chn1_range_bias=-13.480,
      chn2_range_bias=-12.105,
      chn3_range_bias=-10.564,
      chn4_range_bias=-18.985,
      chn1_dx=-0.42,
      chn1_dy=-1.67,
      chn2_dx=0.,
      chn2_dy=0.,
      chn3_dx=-0.42,
      chn3_dy=1.67,
      chn4_dx=0.,
      chn4_dy=0.,
      delta_ht=300.,
      tx_clean=8s,
      dmars_invert=1s,
      use_ins_for_gps=0s
    );
    // If we do "conf = obj_merge(defaults, conf)", then the stuff in defaults
    // will come first. By using temp and then later inverting, they come last.
    temp = obj_merge(defaults, conf);
    keycast, temp, defaults;
    conf = obj_merge(conf, temp);
  }

  return obj2struct(conf, name="mission_constants");
}
wrap_args, mission_constants;

  /*****************************************************************************
  The range bias was computed from the 2002-07-29 ground test. The EAARL data
  was taken from pulses 8716:10810 which was captured from a static target at
  101.1256 meters measured distance. The EAARL centroid range values were
  averaged and then the actual slope distance to the target subtracted to yield
  the range bias in meters (stored as ops_conf.range_biasM). The RMS noise on
  the range values used to compute the range bias was 3.19cm.

  ******************************************************************************
  Following are default operations constants. These should generally not be
  modified in this file. To customize them on a mission-to-mission basis,
  create new ops_conf.i files in the mission directory using write_ops_conf.

  So for example, initialize ops_conf using something like:
    ops_conf = ops_default
  or
    ops_conf = mission_constants(type="EAARL-A")
  or
    ops_conf = mission_constants(type="EAARL-B v1")

  Then modify specific values as you like. Then export to file:
    write_ops_conf, "/path/to/file"

  The active operations constants used throughout ALPS are always in the
  variable ops_conf.

  The ops_conf settings written using write_ops_conf above are stored in a
  simple Yorick source file. You can load them back in using #include or by
  using load_ops_conf:
    load_ops_conf, "/path/to/file"
  However, usually you should set the ops_conf file in the Mission
  Configuration Manager and let it worry about loading your settings.

  ******************************************************************************
  The coordinate system of the plane is as follows:

    +X  Out the right wing
    +Y  Forward along the fuselage
    +Z  Up.

  *****************************************************************************/

  ops_default = mission_constants(
    range_biasM = 0.7962,
    chn1_range_bias = 0.,
    chn2_range_bias = 0.36,
    chn3_range_bias = 0.23,
    max_sfc_sat = 2
  );

  ops_tans = ops_default;
  ops_tans.name       = "Tans Default Values"
  ops_tans.roll_bias  = -1.40;    // carefully tweaked on 2003-02-18 data
  ops_tans.pitch_bias = +0.5;
  ops_tans.yaw_bias   =  0.0;
  ops_tans.y_offset   = -1.403;   // From Applanix pospac
  ops_tans.x_offset   =  -.470;   // From Applanix pospac
  // z_offset should be -1.708, but need better measurement of IMU to laser
  // point
  ops_tans.z_offset   = -1.3;
  ops_tans.scan_bias  =  0.0;
  ops_tans.range_biasM = 0.7962;  // Laser range measurement bias

  // By default, we use ops_tans for our constants
  ops_conf = ops_tans;

  /*****************************************************************************
  Defaults for the EAARL #1 IMU which is the location directly above the
  scanner.

  The default numbers below were determined from the 2003-09-16 flight from
  ksby to kmyr using pospac on 2003-10-02.
  *****************************************************************************/
  ops_IMU1 = ops_default;
  ops_IMU1.name       = "Applanix 510 Defaults"
  ops_IMU1.x_offset   =  0.470;   // This is Applanix Y Axis +Rt Wing
  ops_IMU1.y_offset   =  1.403;   // This is Applanix X Axis +nose
  ops_IMU1.z_offset   = -0.833;   // This is Applanix Z Axis +Down
  ops_IMU1.roll_bias  = -0.755;   // DMARS roll bias from 2-13-04
  ops_IMU1.pitch_bias =  0.1;     // DMARS pitch bias from 2-13-04

  ops_IMU2 = ops_default;
  ops_IMU2.name       = "DMARS Defaults"
  ops_IMU2.roll_bias  = -0.8;     // with 03/12 Albert Whitted runway
  ops_IMU2.pitch_bias =  0.1;     // with 03/12 Albert Whitted runway
  ops_IMU2.yaw_bias   =  0.;

  /*****************************************************************************
  Defaults for the EAARL-B system on N7793Q
  *****************************************************************************/
  ops_eaarlb = mission_constants(type="EAARL-B");
  ops_eaarlb.x_offset = -0.03099;
  ops_eaarlb.y_offset = 0.02426;
  ops_eaarlb.z_offset = -0.25877;
  ops_eaarlb.roll_bias = 0;
  ops_eaarlb.pitch_bias = 0;
  ops_eaarlb.yaw_bias = 0;
  ops_eaarlb.scan_bias = 0; // Needs to be calibrated
  // range_biasM needs to remain at 0; bias is calculated per-channel instead
  ops_eaarlb.range_biasM = 0;
  // Following values were calculated by WW on 2012-01-07
  // Biases were calibrated in meters, which were then converted to NS.
  ops_eaarlb.chn1_range_bias = -13.480; // = -2.020 / NS2MAIR;
  ops_eaarlb.chn2_range_bias = -12.105; // = -1.814 / NS2MAIR;
  ops_eaarlb.chn3_range_bias = -10.564; // = -1.583 / NS2MAIR;
  ops_eaarlb.chn4_range_bias = -18.985; // = -2.845 / NS2MAIR;
  ops_eaarlb.chn1_dx = -0.42;
  ops_eaarlb.chn1_dy = -1.67;
  ops_eaarlb.chn2_dx = 0.;
  ops_eaarlb.chn2_dy = 0.;
  ops_eaarlb.chn3_dx = -0.42;
  ops_eaarlb.chn3_dy = 1.67;
  ops_eaarlb.chn4_dx = 0.;
  ops_eaarlb.chn4_dy = 0.;
  ops_eaarlb.delta_ht = 300.;
  ops_eaarlb.max_sfc_sat = 2;
  ops_eaarlb.tx_clean = 8;
  ops_eaarlb.dmars_invert = 1;
  ops_eaarlb.use_ins_for_gps = 1;

func display_mission_constants(conf, ytk=) {
/* DOCUMENT display_mission_constants, conf, ytk=
  Displays the mission constants given, either in Yorick or (if ytk=1) in Tcl
  using a GUI. CONF may be given as a value or as the string name of a
  variable. Here are some examples of how it can be called:

    display_mission_constants, ops_tans
    display_mission_constants, ops_tans, ytk=1
    display_mission_constants, "ops_tans"
    display_mission_constants, "ops_tans", ytk=1

  If ytk=1, then it is preferred to give the variable as a string name so that
  its name will be displayed in the GUI's title bar.
*/
  name = [];
  if(is_string(conf)) {
    name = conf;
    conf = symbol_def(name);
  }
  if(ytk) {
    json = json_encode(conf);
    cmd = swrite(format="::eaarl::settings::ops_conf::view {%s}", json);
    if(!is_void(name))
      cmd += swrite(format=" {%s}", name);
    tkcmd, cmd;
  } else {
    write_ops_conf, conf=conf;
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
  else if(typeof(fn) == "text_stream")
    f = fn;
  if(f) {
    write, f, format="// Exported from ALPS on %s\n", soe2date(getsoe());
    write, f, format="%s", "ops_conf = ";
  }
  write, f, format="mission_constants(\n  %s\n)\n", params;
  if(is_string(fn)) close, f;
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

func eaarl_ops_conf_gui_init(nil) {
/* DOCUMENT eaarl_ops_conf_gui_init
  Glue for ::eaarl::settings::ops_conf::gui.
*/
  extern ops_conf;
  fields = get_members(ops_conf);
  fields = strjoin(fields, " ");
  tkcmd, swrite(format="::eaarl::settings::ops_conf::gui_init {%s}", fields);
}
