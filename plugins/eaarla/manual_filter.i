// vim: set ts=2 sts=2 sw=2 ai sr et:

func test_and_clean(&data, verbose=, force=, mirror=, zeronorth=, zerodepth=,
negch=, chanint=) {
/* DOCUMENT test_and_clean, data, verbose=, force=, mirror=, zeronorth=,
    zerodepth=, negch=, chanint=
  cleaned = test_and_clean(data, verbose=, force=, mirror=, zeronorth=,
    zerodepth=, negch=, chanint=)

  Tests the data in various ways and cleans it as necessary.

  The tests and cleaning that occurs corresponds to various options as
  detailed below.

  The first test is to see if the data is in a raster format (GEOALL,
  VEG_ALL_, VEG_ALL, or R). If it is, the data is coerced into the
  corresponding point format (GEO, VEG__, VEG__, and FS respectively).

  At this point, force= comes into play.

  force= Specifies whether data should be cleaned when the structure is
    already "right".
      force=0        Default. If the structure was not GEOALL, VEG_ALL_,
                VEG_ALL, or R, then nothing further happens and the
                function is effectively a noop.
      force=1        Further cleaning will always happen.

  If further cleaning occurs, then the following options come into play.

  mirror= Removes points by performing two checks using the mirror
    coordinates. If the data has .elevation, .lelv, and .melevation fields,
    then points where both .elevation and .lelv equal .melevation are
    discarded.  If the data has .elevation and .melevation but not .depth or
    .lelv, then points where .elevation equals .melevation are discarded.
      mirror=1       Default. Perform this filtering.
      mirror=0       Skip this filter.

  zeronorth= Removes points with zero values for .north or .lnorth.
      zeronorth=1    Default. Perform this filtering.
      zeronorth=0    Skip this filter.

  zerodepth= Removes points with zero .depth values.
      zerodepth=1    Default. Perform this filtering.
      zerodepth=0    Skip this filter.

  negch= Detects points with a negative canopy height; that is, where the
    first return .elevation is lower than the last return .lelv. The actual
    action taken depends on the setting's value.
      negch=2        Default. Set .elevation to .lelv.
      negch=1        Remove the points.
      negch=0        Skip this filter.

  chanint= Detangles channel and intensity values. If a channel field is
    present and zero, then the channel field is set based on the first surface
    intensity and the intensity values are put in the range 0 to 300. If the
    channel field is missing or if it is present with non-zero values, then no
    action is taken.
      chanint=1     Default. Perform this fix.
      chanint=0     Skip this fix.

  By default, it runs silently. Use verbose=1 to get some info.

  This function utilizes memory better when run as a subroutine rather than a
  function. If you don't need to keep the original, unclean data, then use the
  subroutine form.
*/
  default, verbose, 0;
  default, force, 0;
  default, mirror, 1;
  default, zeronorth, 1;
  default, zerodepth, 1;
  default, negch, 2;
  default, chanint, 1;

  if(is_void(data)) {
    if(verbose)
      write, "No data found in variable provided.";
    return [];
  }

  // If we're not forcing, and if the struct isn't a known raster type, do
  // nothing.
  if(!force && !structeqany(structof(data), GEOALL, VEG_ALL_, VEG_ALL, R))
    return data;

  // If we're running as subroutine, we can be more memory efficient.
  if(am_subroutine()) {
    eq_nocopy, result, data;
    data = [];
  } else {
    result = data;
  }

  // Convert from raster type to point type
  struct_cast, result, verbose=verbose;

  if(verbose)
    write, "Cleaning data...";

  if(mirror) {
    // Only applies to veg types.
    // Removes points where both of elevation and lelv equal the mirror.
    if(
      has_member(result, "elevation") && has_member(result, "lelv") &&
      has_member(result, "melevation")
    ) {
      w = where(
        (result.lelv != result.melevation) |
        (result.elevation != result.melevation)
      );
      result = numberof(w) ? result(w) : [];
    }

    // Only applies to fs types. (Explicitly avoiding veg and bathy.)
    // Removes points where the elevation equals the mirror.
    if(
      has_member(result, "elevation") && has_member(result, "melevation") &&
      !has_member(result, "depth") && !has_member(result, "lelv")
    ) {
      w = where(result.elevation != result.melevation);
      result = numberof(w) ? result(w) : [];
    }
  }

  if(zeronorth) {
    // Applies to all types.
    // Removes points with zero fs northings.
    if(has_member(result, "north")) {
      w = where(result.north);
      result = numberof(w) ? result(w) : [];
    }

    // Only applies to veg types.
    // Removes points with zero be northings.
    if(has_member(result, "lnorth")) {
      w = where(result.lnorth);
      result = numberof(w) ? result(w) : [];
    }
  }

  if(zerodepth) {
    // Only applies to bathy types.
    // Removes points with zero depths.
    if(has_member(result, "depth")) {
      w = where(result.depth);
      result = numberof(w) ? result(w) : [];
    }
  }

  if(negch == 2) {
    // Only applies to veg types.
    // Ensures that first return is not lower than last return.
    // For negch=2, coerce to match
    if(has_member(result, "elevation") && has_member(result, "lelv")) {
      w = where(result.lelv > result.elevation);
      if(numberof(w)) {
        result.north(w) = result.lnorth(w);
        result.east(w) = result.least(w);
        result.elevation(w) = result.lelv(w);
      }
    }
  } else if(negch) {
    // Only applies to veg types.
    // Ensures that first return is not lower than last return.
    // For negch=1, discard
    if(has_member(result, "elevation") && has_member(result, "lelv")) {
      w = where(result.lelv <= result.elevation);
      result = numberof(w) ? result(w) : [];
    }
  }

  if(chanint) {
    if(has_member(result, "channel")) {
      w = where(!result.channel);
      if(numberof(w)) {
        if(has_member(result, "intensity"))
          result(w).channel = result(w).intensity/300 + 1;
        else if(has_member(result, "fint"))
          result(w).channel = result(w).fint/300 + 1;
        if(has_member(result, "intensity"))
          result(w).intensity %= 300;
        if(has_member(result, "fint"))
          result(w).fint %= 300;
        if(has_member(result, "lint"))
          result(w).lint %= 300;
        if(has_member(result, "first_peak"))
          result(w).first_peak %= 300;
        if(has_member(result, "bottom_peak"))
          result(w).bottom_peak %= 300;
      }
    }
  }

  if(am_subroutine())
    eq_nocopy, data, result;
  else
    return result;
}

func strip_flightline_edges(data, startpulse=, endpulse=, idx=) {
/* DOCUMENT strip_flightline(data, startpulse=, endpulse=, idx=)
  Remove the edges of the flightlines based on pulse number. The data without
  the edges will be returned.

  Parameters:
    data: Input data array with ".rn" field.
  Options:
    startpulse= Remove all pulses before and including this number.
        startpulse=10 (default)
    endpulse= Remove all pulses after and including this number.
        endpulse=110 (default)
    idx= Specifies that the indices into data should be returned instead of
      the corresponding data.
        idx=0     return data (default)
        idx=1     return indices

  There are typically 119 laser pulses per raster. Therefore, you should
  usually have 1 <= firstpulse < endpulse <= 119.
*/
  local pulse;
  default, startpulse, 10;
  default, endpulse, 110;
  default, idx, 0;
  parse_rn, data.rn, , pulse;
  w = where((startpulse < pulse) & (pulse < endpulse));
  if(idx) return w;
  return data(w);
}
