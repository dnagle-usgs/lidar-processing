// vim: set ts=2 sts=2 sw=2 ai sr et:

// === SASR: Scan Angle Shift Reprocessing =====================================
// The SASR library is used to reprocess a single raster while applying a shift
// to its scan angle. This is used to correct a data issue wherein the scan
// angles for a raster are occasionally mis-recorded with a shift in one
// direction or the other. The issue presents itself in the data by making a
// raster look tilted compared to adjacent rasters.

// --- Main Functions ----------------------------------------------------------
// There are two functions that are intended for general use: sasr_display and
// sasr_apply. The first provides a plot to analyze the data and the second
// applies a specified shift to the raster and updates the data. Both of these
// functions are primarily intended to be used by the corresponding SASR GUI.

func sasr_display(args) {
/* DOCUMENT sasr_display, data, raster, channel=, neardist=, win=, dmode=,
   pmode=, shift=, ext_bad_att=

  Plots a selected raster for analysis to determine a possible required scan
  angle shift. The raster will be plotted in a transect-like fashion along the
  scan line, perpendicular to the plane's heading. Optionally, nearby rasters
  are also plotted for context. Optionally, the raster's reprocessed points
  with a selected shift are plotted for preview.

  There are two variant ways to call this function. If you omit shift=, then a
  basic plot will be provided that just shows the data as it exists. If you
  provide shift=, then the raster will be reprocessed and the result will
  additionally be plotted.

  Prerequisite:
    You must already have the correct flight loaded in the Mission
    Configuration Manager for the raster you wish to view.

  Parameters:
    data - An array of EAARL point data.
    raster - The raster to analyze.

  Options:
    channel= Configures what channels to view/process.
        channel=[]      If omitted or explicitly set to void, then the channels
          are automatically handled. All data will be plotted. When
          reprocessing, the channels that exist for this raster in the source
          data will be reprocessed. (Note: if the selected raster contains
          fewer channels than the data as a whole, only those fewer channels
          will be used. This may or may not be what you want.)
        channel=[2,3]   If a channel or array of channels are provided, then
          those channels are used. Only those channels will be plotted. Only
          those channels will be reprocessed and displayed. (Note: if you
          include a channel that does not exist in your source data, that
          channel will still be included in the reprocessing.)
    neardist= Specifies how far away we should go when including nearby rasters
      for display. This is an integer number of rasters.
        neardist=2    Default; includes two rasters before and two rasters
          after the specified raster.
    win= Specifies the window to plot in. By default, this will use the current
      window.
    dmode= Specifies the mode to use for displaying the data. This corresponds
      to the mode= option used in many other point cloud / xyz oriented
      functions. Possible settings include:
        dmode="fs"    Default; first surface
        dmode="be"    Bare earth
        dmode="ba"    Bathy
    pmode= Specifies the mode to use for processing the data. This corresponds
      to the mode= option used in many processing functions. Possible settings
      include:
        pmode="f"     First surface
        pmode="b"     Bathy
        pmode="v"     Vegetation
      If this is omitted, then an attempt will be made to auto-detect an
      appropriate pmode based on the data's struct: FS yields "f", VEG__ yields
      "v", and GEO yields "b".
    shift= Specifies an offset to apply to the scan angle when reprocessing.
      This should generally be a multiple of 4 if provided.
        shift=[]      Default; if omitted or set to void, then no reprocessing
          is performed or displayed.
        shift=4       Apply a shift of 4 counts.
        shift=-4      Apply a shift of -4 counts.
    ext_bad_att= This is passed through to the underlying processing function.
      It specifies the minimum flying height, in meters.
        ext_bad_att=20    Default
*/
  local msg;

  if(args(0) != 2) error, "must provide exactly 2 positional args: data, raster";
  data = args(1);
  raster = args(2);
  vname = args(-,1);

  local channel, neardist, win, dmode, pmode, shift, ext_bad_att;
  restore_if_exists, args2obj(args), channel, neardist, win, dmode, pmode,
    shift, ext_bad_att;

  valid = ["channel", "neardist", "win", "dmode", "pmode", "shift", "ext_bad_att"];
  invalid = set_difference(args(-), valid);
  if(numberof(invalid)) {
    error, "invalid options: "+print(invalid)(sum);
  }

  default, win, max(0, current_window());
  default, dmode, "fs";

  cmd = swrite(format="::eaarl::sasr::config %d -raster %d -dmode %s",
    win, raster, dmode);
  if(strlen(vname)) cmd += swrite(format=" -variable {%s}", vname);
  if(!is_void(pmode)) cmd += " -pmode "+pmode;
  tkcmd, cmd;

  if(is_void(tans)) {
    msg = "Unable to locate flightline\nDid you load the flight data?";
    goto ERR;
  }

  // Extract near and current points
  work = sasr_extract(data, raster, neardist, channel);

  if(is_void(work)) {
    msg = swrite(format="No data found for raster %d", raster);
    goto ERR;
  }

  // if pmode is not provided and if we're not reprocessing, attempt to
  // auto-detect a processing mode and notify the GUI
  if(is_void(pmode) && is_void(shift)) {
    s = structof(data);
    if(structeq(s, FS)) pmode="f";
    if(structeq(s, VEG__)) pmode="v";
    if(structeq(s, GEO)) pmode="b";
    if(!is_void(pmode))
      tkcmd, swrite(format="::eaarl::sasr::config %d -pmode %s", win, pmode);
  }

  // Reprocess if needed
  if(!is_void(shift)) {
    sasr_process, work, raster, channel, shift, pmode, ext_bad_att;

    if(is_void(work.match)) {
      msg = swrite(format="Reprocessing failed for raster %d", raster);
      goto ERR;
    }
    if(!structeq(structof(data), structof(work.match))) {
      msg = "Error: struct mismatch\nIs your processing mode set correctly?";
      goto ERR;
    }
  }

  // Pull subvars out of work var
  near = curr = match = extra = [];
  restore_if_exists, work, near, curr, match, extra;

  // Area of interest "aoi" - we use all of the current raster points for
  // several calculations
  aoi = curr;
  if(!is_void(match)) grow, aoi, match;
  if(!is_void(extra)) grow, aoi, extra;

  // Figure out the current heading and create a perpendicular line to project
  // the data against.

  // Pick the time in the middle of the range
  somd = (aoi.soe(max) + aoi.soe(min))/2 - soe_day_start;

  // Bracket off a 2s segment of tans to use, because we don't want to
  // interpolate against something far away by mistake
  w = where(somd - 1 <= tans.somd & tans.somd <= somd + 1);
  if(!numberof(w)) {
    msg = "Unable to determine heading";
    goto ERR;
  }

  // Interpolate the heading. Then convert from CW-from-north to CCW-from-east
  // and rotate to perpendicular.
  heading = interp_angles(tans(w).heading, tans(w).somd, somd);
  angle = rereference_angle(heading, "CW", "N", "CCW", "E") - 90;
  angle *= DEG2RAD;

  // Derive perpendicular line
  local x, y;
  data2xyz, aoi, x, y, mode=dmode;
  x0 = x(avg);
  y0 = y(avg);
  line = [x0,y0,x0+cos(angle),y0+sin(angle)];
  x = y = x0 = y0 = [];

  // Do the actual plotting
  wbkp = current_window();
  window, win;
  fma;
  limits, square=0;

  msg = swrite(format="raster = %d", raster);
  if(is_void(shift)) {
    limits;
  } else {
    msg += swrite(format=", shift = %d", shift);
  }

  legend, reset;
  legend, add, "black", msg;
  sasr_plot_helper, near, dmode, line, 0.1, "black", "Nearby points";
  sasr_plot_helper, curr, dmode, line, 0.25, "red", "Current points";
  sasr_plot_helper, match, dmode, line, 0.25, "blue", "Reprocessed matching points";
  sasr_plot_helper, extra, dmode, line, 0.25, "cyan", "Reprocessed missing points";
  legend, show, height=10;

  if(strlen(vname)) pltitle, regsub("_", vname, "!_", all=1);
  xytitles, "Relative Distance Along Raster, meters", "Elevation, meters";

  window_select, wbkp;
  return;

ERR:
  wbkp = current_window();
  window, win;
  fma;

  if(is_void(msg)) msg="Unknown error";

  xy = viewport_justify("CH");
  plt, msg, xy(1), xy(2), tosys=0, justify="CH";

  window_select, wbkp;
}
wrap_args, sasr_display;

func sasr_apply(data, raster, channel=, pmode=, shift=, ext_bad_att=, useall=) {
/* DOCUMENT result = sasr_apply(data, raster, channel=, pmode=, shift=,
   ext_bad_att=, useall=)

  Updates the provided data to replace the specified raster's points with
  reprocessed data, applying the specified scan angle shift.

  Prerequisite:
    You must already have the correct flight loaded in the Mission
    Configuration Manager for the raster you wish to view.

  Parameters:
    data - An array of EAARL point data.
    raster - The raster to reprocess.

  Options:
    channel= Configures what channels reprocess.
        channel=[]      If omitted or explicitly set to void, then the channels
          are automatically detected: the channels that exist for this raster
          in the source data will be reprocessed. (Note: if the selected raster
          contains fewer channels than the data as a whole, only those fewer
          channels will be used. This may or may not be what you want.)
        channel=[2,3]   If a channel or array of channels are provided, then
          those channels are reprocessed. (Note: if you include a channel that
          does not exist in your source data, that channel will still be
          included in the reprocessing.)
    pmode= Specifies the mode to use for processing the data. This corresponds
      to the mode= option used in many processing functions. Possible settings
      include:
        pmode="f"     First surface
        pmode="b"     Bathy
        pmode="v"     Vegetation
    shift= Specifies an offset to apply to the scan angle when reprocessing.
      This should generally be a multiple of 4 if provided.
        shift=0       Default; no shift is actually applied.
        shift=4       Apply a shift of 4 counts.
        shift=-4      Apply a shift of -4 counts.
    ext_bad_att= This is passed through to the underlying processing function.
      It specifies the minimum flying height, in meters.
        ext_bad_att=20    Default
    useall= Specifies whether to only include corresponding points or to
      include all points.
        useall=0      Default; when replacing the raster's points, only those
          points that already exist in the data are used. In other words, if
          some points have been removed by RCF or manual editing, those points
          will not be re-introduced by the reprocessing.
        useall=1      When replacing the raster's points, use all reprocessed
          points even if they did not exist in the data previously.
*/
  default, shift, 0;
  default, useall, 0;

  if(is_void(pmode)) error, "missing pmode=";

  work = sasr_extract(data, raster, 0, channel);
  sasr_process, work, raster, channel, shift, pmode, ext_bad_att;

  result = work.notcurr;
  if(work(*,"match"))
    grow, result, work.match;
  if(work(*,"extra") && useall)
    grow, result, work.extra;

  result = result(sort(result.soe));
  return result;
}

// --- Utility Functions -------------------------------------------------------
// These functions are for internal use. They primarily exist to avoid code
// duplication between the above functions.

func sasr_extract(data, raster, neardist, channel) {
/* DOCUMENT work = sasr_extract(data, raster, neardist, channel)
  Returns an oxy group containing up to three variables:
    curr - the points matching the specified raster
    near - the points within neardist of the specified raster
    notcurr - every point not included in curr
*/
  default, neardist, 2;

  // Find and restrict to the soe range that corresponds to the raster range;
  // this is necessary to accommodate multi-flight data.
  soemin = edb.seconds(max(1, raster-neardist)) - 1;
  soemax = edb.seconds(min(numberof(edb), raster+neardist)) + 2;

  w = where(
    abs(raster - data.raster) <= neardist &
    soemin <= data.soe & data.soe <= soemax
  );

  if(!numberof(w)) return;

  // If channel is specified, then restrict aoi to it
  if(!is_void(channel)) {
    if(numberof(channel) == 1) {
      idx = where(data(w).channel == channel(1));
    } else {
      keep = array(0, numberof(w));
      for(i = 1; i <= numberof(channel); i++) {
        keep |= data(w).channel == channel(i);
      }
      idx = where(keep);
    }
    if(!numberof(idx)) return;
    w = w(idx);
  }

  result = save();

  aoi = data(w);
  match = aoi.raster == raster;
  if(noneof(match)) return;

  // The data we'd like to plot: current raster and nearby rasters, but only
  // for the selected channels (if applicable)
  save, result, curr=aoi(where(match));
  if(nallof(match))
    save, result, near=aoi(where(!match));

  // This is all data except curr; used only if we're updating the data var
  nomatch = array(1, numberof(data));
  nomatch(w(where(match))) = 0;
  save, result, notcurr=data(where(nomatch));

  return result;
}

func sasr_process(work, raster, channel, shift, mode, ext_bad_att) {
/* DOCUMENT sasr_process, work, raster, channel, shift, mode, ext_bad_att
  Updated work (which is an oxy group) to add two new variables:
    match - the reprocessed points that correspond to points in the original
      data
    extra - the reprocessed points that do not correspond to points in the
      original data
*/
  default, shift, 0;
  default, ext_bad_att, 20;

  if(is_void(channel))
    channel = set_remove_duplicates(work.curr.channel);
  conf = obj_copy(ops_conf);
  save, conf, scan_bias = conf.scan_bias + shift;
  new = sasr_process_helper(conf, raster, mode, ext_bad_att, channel);

  match = extract_corresponding_data(new, work.curr, keep=1);
  if(anyof(match))
    save, work, match=new(where(match));
  if(nallof(match))
    save, work, extra=new(where(!match));
}

func sasr_process_helper(conf, raster, mode, ext_bad_att, channel) {
/* DOCUMENT data = sasr_process_helper(conf, raster, mode, ext_bad_att, channel)
  This is a wrapper around process_eaarl. It exists solely to allow the
  creation of a modified local ops_conf without clobbering the global one. This
  masks the global one, causing process_eaarl to see the modified one.

  This way of modifying ops_conf has the benefit that if an error occurs,
  dbexiting out of debug mode will automatically restore ops_conf to its
  expected value. This is much safer than the alternative of modifying and
  restoring the global ops_conf in place.
*/
  local ops_conf;
  ops_conf = conf;
  return process_eaarl(raster, raster, mode=mode, ext_bad_att=ext_bad_att,
    channel=channel);
}

func sasr_plot_helper(var, mode, line, msize, color, label) {
/* DOCUMENT sasr_plot_helper, var, mode, line, msize, color, label
  Simple utility function that plots a single data variable.
*/
  local x, y, z, rx, ry;
  if(!is_void(var)) {
    label += swrite(format=" (%d)", numberof(var));
    data2xyz, var, x, y, z, mode=mode;
    project_points_to_line, line, x, y, rx, ry;
    plmk, z, rx, color=color, marker=1, msize=msize, width=100;
    legend, add, color, label;
  }
}
