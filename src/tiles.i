// vim: set ts=2 sts=2 sw=2 ai sr et:
require, "tiles_dt.i";
require, "tiles_qq.i";

func tile_scheme(&scheme, opts=, defaults=, init=) {
/* DOCUMENT tile_scheme, scheme, opts=, defaults=, init=
  -or- scheme = tile_scheme(scheme, opts=, defaults=, init=)

  Consolidates all input given and converts it into an object-based scheme
  value. This is usually used at the top of tile-oriented functions to resolve
  their input in a consistent way.

  Function documentation will often point to this function for an explanation
  of what can be passed for scheme. See the next three sections (Tiling Tuypes,
  Object Schemes, and String Schemes) for that information.

  === Tiling Types ===

  ALPS currently has support for two types of tiles: UTM-based tiles and
  lat/lon-based quarter quad tiles.

  --- UTM-based Tiles ---

  UTM-based tiles come in a variety of sizes, from 2km to 10km. Tiles are
  always square (same east-to-west extent and south-to-north extent). The tiles
  are named for their northwest corner's coordinates.

  Configuration options:

    dtprefix: Specifies whether the size prefix should be included. 1 includes
      the prefix, 0 omits it.
    dtlength: Specifies whether to use the short form ("short") or long form
      ("long") tile names.

  The size of the tile is determined by its prefix, which corresponds to the
  type's tile mode name.

    Type  Prefix  Size
    ----  ------  ----
    "it"  i_      10km (index tile)
    "dt"  t_      2km (data tile)

  If the prefix is missing, then the tile is assumed to be 2km.

  UTM-based tile names come in two lengths, long and short, and can optionally
  be prefixed by the tile type (noted above).

  The short form encodes the northwest corner's coordinates in kilometers as

    eXXX_nYYYY_ZZ

  where XXX is the corner's easting, YYYY is the northing, and ZZ is the UTM
  zone.

  The long form encodes the northwest corner's coordinates in meters as

    eXXXXXX_nYYYYYYY_ZZ

  where XXXXXX is the corner's easting, and YYYYYYY is the northing, and ZZ is
  the UTM zone.

  Some examples:

    i_e248000_n1376000_15   10km index tile with northwest corner 248000 east,
                            1376000 west, zone 15.
    i_e248_n1376_15         Same as i_e248000_n1376000_15
    t_e248000_n1376000_15   2km data tile with northwest corner 248000 east,
                            1376000 west, zone 15.
    t_e248_n1376_15         Same as t_e248000_n1376000_15
    e248000_n1376000_15     Same as t_e248000_n1376000_15
    e248_n1376_15           Same as t_e248000_n1376000_15

  --- Quarter Quad Tiles ---

  Quarter quads tile data based on geographic coordinates, referenced to the
  NAD83 datum. Note that the code does not make any adjustments to ensure that
  you are in the NAD83 datum; it is assumed the input is in the correct datum.
  Each quarter quad tile is 1/16 degree east-to-west and 1/16 degree
  south-to-north. The scheme is only valid for locations with positive latitude
  and negative longitude.

  Configuration options:

    qqprefix: Tile names are of the form AAOOOaoq, as described below. When
      qqprefix=1, the tile names are prefixed by the string "qq". This enables
      the tile name to be used as a variable in Yorick (since variables cannot
      start with numerals).

  Tile names have the form AAOOOaoq, where

    AA is the absolute value whole number component of the latitude

    OOO is the absolute value whole number component of the longitude,
      zero-padded to a width of 3

    a is an alpha character a-h designating which quad in the degree of
      latitude, where a is closest to 0 minutes and hs is closest to the next
      full degree. Each letter represents 1/8 degree.

    o is a numeral 1-8 designating which quad in the degree of longitude, where
      1 is closest to 0 minutes and 8 is closest to the next full degree. Each
      number represents 1/8 degere.

    q is an alpha character a-d designating which quarter in the quad, where a
      is SE, b is NE, c is NW, and d is SW. Each quarter-quad is 1/16 of a
      degree in latitude and 1/16 of a degree in longitude.

  For example, 47104h2c means:

    47 degrees latitude and 104 degrees longitude: 47N 104W
    h is the 8th in sequence, so the section starts at 7/8 degree and ends at
      8/8 degree: 0.875 to 1.000, which means 47.875N to 48.000N
    2 is the second in sequence, so the section starts at 1/8 degree and ends
      at 2/8 degree: 0.125 to 0.250, which means 104.125W to 104.250W
    c represents the NW corner, which means the bounds are (47.9375N 104.1875W)
      to (48.000N 104.2500W)

  So 47104h2c is bounded by (47.9375N 104.1875W) and (48.000N 104.2500W).

  === Object Schemes ===

  An object-based scheme is simply an oxy group object that contains the
  parameters for the desired scheme. The object can have the following members:

    type - The type of tiling scheme, such as "dt" or "qq".
    path - The tile types to use when constructing a directory name. This can
      be string(0), which means don't add any tile-named subdirectories. It can
      be a single tile type, such as "dt". Or it can be a slash-delimited
      series of tile types, such as "it/dt" (which has index tiles which
      contain data tiles which contain the files).
    length - Whether short tile names (length="short") or long tile names
      (length="long") should be generated.
    prefix - Whether tiles should receive an applicable prefix. 1 adds the
      prefix, 0 omits it.
    dtlength - Same as length, but specific to the utm-based tile types.
    dtprefix - Same as prefix, but specific to the utm-based tile types.
    qqprefix - Same as prefix, but specific to the quarter-quad tile type.

  The type and path can be combined to proivde them as a single value. There
  are two syntaxes for this: TYPE:PATH and PATH.

  An example of TYPE:PATH would be "dt:it", which generates 2km data tile files
  and stores them in 10km index tiles (type="dt", path="it"). Another example
  is "dt:it/dt", which generates the customary 10km index tile folders with 2km
  data tile folders which contain 2km data tile files (type="dt", path="it/dt").

  For PATH, the final component is used for the type. So "it/dt" is equivalent
  to "dt:it/dt" (type="dt", path="it/dt") and "dt" is equivalent to "dt:dt".

  === String Schemes ===

  String values are interpreted as a series of space-delimited tokens and/or
  key-value pairs. A key-value pair is a pair of values separated by an equal
  sign. Anything without an equal sign is interpreted as a token.

  Key-value pairs accept the same range of input as object-based scheme values.
  As an example, this scheme:
    "tile=dt prefix=0"
  Is interpreted as:
    save(tile="dt", prefix=)

  However, tokens are generally more succinct than explicit key-value pairs. If
  the first element in the string is a token, then it is interpreted as the
  tiling scheme. Remaining tokens must be from the following list:

    prefix - Equivalent to prefix=1
    noprefix - Equivalent to prefix=0
    short - Equivalent to length="short"
    long - Equivalent to length="long"

  If a token or key-value pair is not recognized, it is ignored.

  === Parameter and Options ===

  Parameter:
    scheme: This should be the desired scheme, as provided by the calling
      context. It can be either in the string form or the object form, as
      described below. If it's in string form, it will be converted to object
      form.

  Options:
    opts= Explicitly provided options that should be merged into scheme. This
      is primarily to support legacy functions that allow the caller to specify
      options like dtlength=. This must be an oxy group object.
    defaults= Desired default values to use for settings not found in scheme or
      opts. This must be an oxy group object.
    init= Specifies whether internal initialization should occur; in other
      words, whether values should receive the internally-defined defaults. By
      default, init=1. To disable, use init=1. Not that init=0 may result in
      missing fields.

  === Internal Defaults ===

  The internal defaults (used by init=1) are:

    type="dt"
    dtlength="long"
    dtprefix=1
    qqprefix=0

  There are no defaults for length and prefix, as they are merely shortcuts for
  specifying the corresponding tile-specific settings. (Note that length and
  prefix are also removed from the final result as well, since they are not
  used outside of this function.)

  === Usage ===

  Functions that use tiling schemes will generally want to include this near
  the top to convert user input into a consistent form.

  Functions should use the name "scheme" for the scheme variable where
  plausible for consistency's sake. When not plausible, "tile_scheme" is a good
  alternative.

  Follows are examples of how to use it given different needs.

  In this example, the function only accepts a scheme; it does not accept any
  of the related options explicitly. It also does not need to specify any
  defaults. So the usage is very simple.

    func example(scheme) {
      tile_scheme, scheme;
      // do stuff
    }

  In this example, the function accepts the legacy explicit keyword options
  dtlength, dtprefix, and qqprefix. These are passed to opts= as a group to
  allow them to merge into the scheme.

    func example(scheme, dtlength=, dtprefix=, qqprefix=) {
      tile_scheme, scheme, opts=save(dtlength, dtprefix, qqprefix);
      // do stuff
    }

  In this example, the function wants to have specific default values in place
  for length and prefix. These are provided in a group as defaults=.

    func example(scheme) {
      tile_scheme, scheme, defaults=save(length="long", prefix=1);
      // do stuff
    }

  In this example, both legacy explicit keyword options and defaults are used.

    func example(scheme, dtlength=, dtprefix=, qqprefix=) {
      tile_scheme, scheme, opts=save(dtlength, dtprefix, qqprefix),
        defaults=save(length="long", prefix=1);
      // do stuff
    }

  === Precedences ===

  Values in opts have highest precedence, followed by values in scheme,
  followed by values in defaults, followed by internal defaults.

  Explicitly provided values for dtlength, dtprefix, or qqprefix are used in
  preference over values provided for length and prefix, provided they are on
  the same precedence level (opts, scheme, defaults, internal). However, length
  and prefix when provided at a higher level will take precedence over the
  others provided at lower levels.

  For example, the following results in dtprefix=0.

     scheme = tile_scheme("dt dtprefix=1", save(prefix=0))

  If the scheme type provided contains ":" or "/", then its path information
  has highest precedence for path. Otherwise, the type is used for the internal
  default value for path (lowest precedence).
*/
  default, opts, save();
  default, defaults, save();
  default, init, 1;

  // Initialize result as whatever is provided in scheme.
  if(is_string(scheme)) {
    result = tile_scheme_parse(scheme);
  } else if(is_obj(scheme)) {
    result = obj_copy(scheme);
  } else {
    result = save();
  }

  // Resolve shortcuts length and prefix and remove any void elements.
  tile_scheme_resolve_shortcuts, result;
  tile_scheme_resolve_shortcuts, opts;
  tile_scheme_resolve_shortcuts, defaults;

  // Override defaults with values in scheme; override those with values in
  // opts.
  result = obj_merge(defaults, result, opts);

  // Provide internal defaults, unless requested not to.
  if(init) {
    keydefault, result, type="dt", dtlength="long", dtprefix=1, qqprefix=0;
  }

  // Check for path information; if found, apply then fix type
  if(strmatch(result.type, ":")) {
    parts = strsplit(result.type, ":");
    save, result, type=parts(1), path=parts(2);
  } else if(strmatch(result.type, "/")) {
    save, result, path=result.type;
    parts = strsplit(result.type, "/");
    save, result, type=parts(0);
  } else if(init) {
    keydefault, result, path=result.type;
  }

  if(am_subroutine()) scheme = result;
  return result;
}

func tile_scheme_resolve_shortcuts(&scheme) {
/* DOCUMENT tile_scheme_resolve_shortcuts, scheme
  Helper function for tile_scheme that converts shortcut values (length,
  prefix) to type-specific values (dtlength, dtprefix, qqprefix). This also
  removes any void elements that are present.
*/
  obj_delete_voids, scheme;
  if(scheme(*,"length")) {
    keydefault, scheme, dtlength=scheme.length;
  }
  if(scheme(*,"prefix")) {
    keydefault, scheme, dtprefix=scheme.prefix, qqprefix=scheme.prefix;
  }
  obj_delete, result, length, prefix;
}

func tile_scheme_parse(&scheme) {
/* DOCUMENT tile_scheme_parse, scheme
  -or- tile_scheme_parse(scheme)
  SCHEME should be a scalar string; it is parsed to derive a tile scheme group
  object.
*/
  opts = parse_keyval(scheme);

  if(!opts(*,"type") && opts(*) > 0 && !strlen(opts(1))) {
    save, opts, type=opts(*,1);
    opts = opts(2:);
  }

  drop = [];
  new = save();
  for(i = 1; i <= opts(*); i++) {
    if(strlen(opts(noop(i)))) continue;
    key = opts(*,i);
    if(anyof(key == ["short","long"])) {
      save, new, length=key;
      grow, drop, key;
    }
    if(key == "prefix") {
      save, new, prefix="1";
      grow, drop, key;
    }
    if(key == "noprefix") {
      save, new, prefix="0";
      grow, drop, key;
    }
  }
  if(new(*)) {
    obj_delete, opts, noop(drop);
    opts = obj_merge(opts, new);
  }

  if(opts(*,"prefix")) save, opts, prefix=atoi(opts.prefix);
  if(opts(*,"dtprefix")) save, opts, dtprefix=atoi(opts.dtprefix);
  if(opts(*,"qqprefix")) save, opts, qqprefix=atoi(opts.qqprefix);

  if(am_subroutine()) scheme = opts;
  return opts;
}

func tile_scheme_stringify(scheme) {
/* DOCUMENT str = tile_scheme_stringify(scheme)
  Serializes the given scheme data as a string. The string can then be passed
  to tile_scheme to restore the scheme information.

  SEE ALSO: tile_scheme
*/
  tile_scheme, scheme;
  return swrite(format="type=%s path=%s dtlength=%s dtprefix=%d qqprefix=%d",
    scheme.type, scheme.path, scheme.dtlength, scheme.dtprefix, scheme.qqprefix);
}

func extract_tile(text, dtlength=, dtprefix=, qqprefix=) {
/* DOCUMENT extract_tile(text, dtlength=, qqprefix=)
  Attempts to extract a tile name from each string in the given array of text.

  Options:
    dtlength= Dictates which kind of data tile name is returned when a data
      tile is detected. (Note: This has no effect on index tile names.)
      Valid values:
        dtlength="short"  Returns short form (default)
        dtlength="long"   Returns long form

    dtprefix= Dictates whether data tile and index tile names should be
      prefixed with t_ and i_ prefixes, respectively.
        dtprefix=1     Apply prefix
        dtprefix=0     Omit prefix
      By default, index tiles have dtprefix=1; data tiles have dtprefix=1
      when dtlength=="long" and dtprefix=0 otherwise.

    qqprefix= Dictates whether quarter quad tiles should be prefixed with
      "qq". Useful if they're going to be used as variable names. Valid
      values:
        qqprefix=0      No prefix added (default)
        qqprefix=1      Prefix added

  The 10km/2km/1km/250m tiling structure can resulting in ambiguous tile
  names. If the tile has a prefix of i_, q_, or c_, then it is parsed as an
  index tile, quad tile, or cell tile, respectively.  Otherwise, it is parsed
  as a data tile. If the string contains both a data tile and quarter quad
  name, the data tile name takes precedence. Tiles without parseable names
  will yield the nil string.
*/
  default, dtlength, "short";
  default, qqprefix, 0;
  qq = extract_qq(text, qqprefix=qqprefix);
  dt = extract_dt(text, dtlength=dtlength, dtprefix=dtprefix);

  prefix = strpart(text, 1:2);
  is_it = "i_" == prefix;

  result = array(string, dimsof(text));

  w = where(strlen(dt) > 0 & is_it);
  if(numberof(w))
    result(w) = dt2it(dt(w), dtlength=dtlength, dtprefix=dtprefix);

  w = where(strlen(dt) > 0 & !strlen(result));
  if(numberof(w))
    result(w) = dt(w);

  w = where(strlen(qq) > 0 & !strlen(result));
  if(numberof(w))
    result(w) = qq(w);

  return result;
}

func tile_tiered_path(tile, scheme) {
/* DOCUMENT tile_tiered_path(tile, scheme)

  This constructs the tiered path for a given tile. The most common example
  would be for the usual 10km/2km tile scheme: with scheme.path="it/dt", tile
  "t_e232_n4058_16" would yield "i_e230_n4060_16/e232_n4058_16".

  The scheme.path setting should be a forward-slash ("/") delimited series of
  tile types.  The following are valid options for tile types: qq, it, dt.  An
  example of a valid scheme.path is "it/dt". You can also mix quarter quads
  with the UTM tiles (such as "qq/dt"), though the utility of that is
  questionable at best.

  The centroid of the specified tile is used when calculating new tile names. So
  if you pass in an index tile and use a scheme of "it/dt" it will work, but
  the result may not be what you were hoping for.

  As a special case, "-" means "no path" and will result in string(0) being
  returned.

  Options dtlength, dtprefix, and qqprefix are as for other tiling functions.
*/
  local north, east, zone;
  tile_scheme, scheme;

  if(scheme.path == "-") return string(0);

  types = strsplit(scheme.path, "/");
  splitary, tile2centroid(tile), north, east, zone;
  result = [];
  for(i = 1; i <= numberof(types); i++) {
    grow, result, utm2tile(east, north, zone, types(i), dtlength=scheme.dtlength,
      dtprefix=scheme.dtprefix, qqprefix=scheme.qqprefix);
  }
  return strjoin(result, "/");
}

func guess_tile(text, dtlength=, qqprefix=) {
/* DOCUMENT guess_tile(text, dtlength=, qqprefix=)
  Calls extract_tile and returns its result if it finds a valid tile name.
  Otherwise, attempts to guess a 2km tile name from the string. This
  currently will catch 2km tile names that do not have a zone identifier in
  the string.
*/
  local e, n, z;
  extern curzone;

  tile = extract_tile(text);
  w = where(!tile);
  if(numberof(w)) {
    regmatch, "e([1-9][0-9]{2}).*n([1-9][0-9]{3})", text(w), , e, n;
    wen = where(!(!e) & !(!n));
    if(numberof(wen)) {
      zone = curzone ? curzone : 15;
      if(!curzone)
        write, "Curzone not set! Using zone 15 to dummy tile names.";
      tile(w(wen)) = swrite(format="e%s_n%s_%d", e(wen), n(wen), zone);
    }
  }
  return tile;
}

func tile_type(text) {
/* DOCUMENT tile_type(text)
  Returns string indicating the type of tile used.  The return result (scalar
  or array, depending on the input) will have strings that mean the following:
    "dt" - Two-kilometer data tile
    "it" - Ten-kilometer index tile
    "qq" - Quarter quad tile
    (nil) - Unparseable
  See extract_tile for information about how ambiguity is handled.
*/
  dt = dt_tile_type(text);
  qq = qq_tile_type(text);
  return dt + qq;
}

func tile_size(text) {
/* DOCUMENT tile_size(text)
  Returns the size (width or height) in meters of the tile. This only works for
  the square UTM-based tiling schemes (data tiles, index tiles, etc.). Anything
  else will return 0.
*/
  sizes = save(it=10000, dt=2000);
  type = tile_type(text);
  if(sizes(*,type)) return sizes(noop(type));
  return 0;
}

func utm2tile(east, north, zone, type, dtlength=, dtprefix=, qqprefix=) {
/* DOCUMENT utm2tile(east, north, zone, type, dtlength=, dtprefix=, qqprefix=)
  Returns the tile name for each set of east/north/zone. Wrapper around
  utm2dt, utm2it, and utm2qq.
*/
  dtfuncs = h_new(dt=utm2dt, it=utm2it);
  if(h_has(dtfuncs, type))
    return dtfuncs(type)(east, north, zone, dtlength=dtlength,
      dtprefix=dtprefix);
  if(type == "qq")
    return utm2qq(east, north, zone, qqprefix=qqprefix);
  return [];
}

func utm2tile_names(east, north, zone, type, dtlength=, dtprefix=, qqprefix=) {
/* DOCUMENT utm2tile_names(east, north, zone, type, dtlength=, dtprefix=,
  qqprefix=)
  Returns the unique tile names for the eastings/northings/zone. Wrapper
  around utm2dt_names, utm2it_names, and utm2qq_names.
*/
  dtfuncs = h_new(dt=utm2dt_names, it=utm2it_names);
  if(h_has(dtfuncs, type))
    return dtfuncs(type)(east, north, zone, dtlength=dtlength,
      dtprefix=dtprefix);
  if(type == "qq")
    return utm2qq_names(east, north, zone, qqprefix=qqprefix);
  return [];
}

func tile2uz(tile) {
/* DOCUMENT tile2uz(tile)
  Attempts to return a UTM zone for each tile in the array given. This is a
  wrapper around dt2uz and qq2uz. If both yield a result, then dt2uz wins
  out. 0 indicates that neither yielded a result.
*/
  tile = extract_tile(tile);

  dt = dt2uz(tile);
  qq = qq2uz(tile);

  result = dt;
  w = where(result == 0 & qq != 0);
  if(numberof(w)) {
    if(dimsof(result)(1))
      result(w) = qq(w);
    else
      result = qq;
  }

  return result;
}

func tile2bbox(tile) {
/* DOCUMENT bbox = tile2bbox(tile)
  Returns the bounding box for a tile: [south,east,north,west].
*/
  type = tile_type(tile);
  funcs = h_new(dt=dt2utm, it=it2utm, qq=qq2utm);

  if(h_has(funcs, type))
    return funcs(type)(tile, bbox=1);
  return [];
}

func tile2centroid(tile) {
/* DOCUMENT centroid = tile2centroid(tile)
  Returns the centroid for a tile: [north,east,zone].
*/
  type = tile_type(tile);
  funcs = h_new(dt=dt2utm, it=it2utm, qq=qq2utm);

  if(h_has(funcs, type))
    return funcs(type)(tile, centroid=1);
  return [];
}

func plot_tile(tile, color=, width=) {
/* DOCUMENT plot_tile, tile, color=, width=
  Simple wrapper around tile2bbox + plg that plots a tile boundary.
*/
  bbox = tile2bbox(tile);
  plg, bbox([1,3,3,1,1]), bbox([2,2,4,4,2]), color=color, width=width, closed=1;
}

func show_grid_location(m) {
/* DOCUMENT show_grid_location, win
  -or- show_grid_location, point
  Displays information about the grid location for a given point. If provided
  a scalar value WIN, the user will be prompted to click on a location in that
  window. Otherwise, the location POINT is used. Will display the index tile,
  data tile, quad name, and cell name.
  SEE ALSO: draw_grid
*/
  extern curzone;
  local quad, cell;
  if(!curzone) {
    write, "Please define curzone.";
    return;
  }

  if(is_scalar(m) || is_void(m)) {
    wbkp = current_window();
    window, m;
    m = mouse();
    window_select, wbkp;
  }

  write, format="Location: %.2f east, %.2f north, zone %d\n", m(1), m(2),
    curzone;

  fmt = "%15s: %-25s -or- %s\n";
  write, format=fmt, "Quarter Quad",
    utm2qq(m(1), m(2), curzone, qqprefix=0),
    utm2qq(m(1), m(2), curzone, qqprefix=1);
  write, format=fmt, "10km Index Tile",
    utm2it(m(1), m(2), curzone, dtlength="long"),
    utm2it(m(1), m(2), curzone, dtlength="short");
  write, format=fmt, "2km Data Tile",
    utm2dt(m(1), m(2), curzone, dtlength="long"),
    utm2dt(m(1), m(2), curzone, dtlength="short");
}

func extract_for_tile(east, north, zone, tile, buffer=) {
/* DOCUMENT idx = extract_for_tile(east, north, zone, tile, buffer=);
  Returns an index into north/east of all coordinates that fall within the
  bounds of the given tile. The buffer= option specifies a value to extend
  around the tile and defaults to 100. Set buffer=0 to disable buffer.

  When buffer=0, points that fall on tile boundaries are only included in one
  tile (each tiling scheme defines where such points go).
*/
  local xmin, xmax, ymin, ymax;
  default, buffer, 100;
  tile = extract_tile(tile);
  type = tile_type(tile);
  if(is_scalar(zone))
    zone = array(zone, dimsof(north));

  if(type == "qq") {
    return extract_for_qq_tile(east, north, zone, tile, buffer=buffer);
  } else if(!type) {
    error, "Unknown tiling type.";
  } else {
    return extract_for_dt_tile(east, north, zone, tile, buffer=buffer);
  }
}

func data_extract_for_tile(data, tile, zone=, mode=, buffer=, idx=) {
/* DOCUMENT data_extract_for_tile(data, tile, zone=, mode=, buffer=, idx=)
  Wrapper around extract_for_tile for point cloud data.

  Options:
    zone= Zone of data. If omitted, then it is assumed that the data is in the
      same zone as TILE. May be array or scalar.
    mode= Mode of data (fs, be, ba).
    buffer= Buffer to extend around the tile, defaults to 100. Set buffer=0 to
      disable buffer.
    idx= By default, the data in the tile will be returned. Use idx=1 to return
      an index into data instead.
*/
  default, idx, 0;
  local x, y;
  if(is_void(zone)) zone = tile2uz(tile);
  data2xyz, data, x, y, mode=mode;
  w = extract_for_tile(x, y, zone, tile, buffer=buffer);
  return idx ? w : data(w);
}

func extract_match_tile(east, north, zone, tile) {
/* DOCUMENT idx = extract_match_tile(east, north, zone, tile)
  Wrapper around extract_for_tile with buffer=0.
*/
  return extract_for_tile(east, north, zone, tile, buffer=0);
}

func data_extract_match_tile(data, tile, zone=, mode=, idx=) {
/* DOCUMENT data_extract_match_tile(data, tile, zone=, mode=, idx=)
  Wrapper around data_extract_for_tile with buffer=0.
*/
  return data_extract_for_tile(data, tile, zone=zone, mode=mode, idx=idx, buffer=0);
}

func restrict_data_extent(data, tile, buffer=, exact=, mode=) {
/* DOCUMENT data = restrict_data_extent(data, tile, buffer=, exact=, mode=)
  Restricts the extent of the data based on its tile.

  Parameters:
    data: An array of EAARL data (VEG__, GEO, etc.).
    tile: The name of the tile. Works for both 2k, 10k, and qq tiles.
      This can be the exact tile name (ie. "t_e123_n4567_12") or the tile
      name can be embedded (ie. "t_e123_n3456_12_n88.pbd").

  Options:
    buffer= A buffer in meters to apply around the tile. Default is 0, which
      constrains to the exact tile boundaries. A larger buffer will include
      more data.
    exact= Contrains the data to exactly the tile specified. This ignores
      buffer=. This differs from buffer=0 in how border points are handled.
      With buffer=0, border points go into both adjacent tiles; with exact=1,
      border points only go into exactly one tile.
    mode= The mode of the data. Can be any setting valid for data2xyz.
      "fs": First surface
      "be": Bare earth (default)
      "ba": Bathy
*/
  local e, n, idx;
  default, buffer, 0;
  default, mode, "be";

  data2xyz, data, e, n, mode=mode;
  zone = tile2uz(tile);
  if(exact)
    idx = extract_match_tile(e, n, zone, tile);
  else
    idx = extract_for_tile(e, n, zone, tile, buffer=buffer);
  return numberof(idx) ? data(idx) : [];
}

func partition_by_tile(east, north, zone, type, buffer=, dtlength=, dtprefix=,
qqprefix=) {
/* DOCUMENT partition_by_tile(east, north, zone, type, buffer=, dtlength=,
  dtprefix=, verbose=)
  Partitions data given by east, north, and zone into the given TYPE of tiles.
  Type may be one of the following values:
    "qq" --> quarter quads
    "it" --> index tiles
    "dt" --> data tiles
*/
  default, buffer, 100;
  names = [];
  if(buffer) {
    for(i = -1; i <= 1; i++) {
      for(j = -1; j <= 1; j++) {
        grow, names, utm2tile_names(east + (i * buffer), north + (j * buffer),
          zone, type, dtlength=dtlength, dtprefix=dtprefix, qqprefix=qqprefix);
      }
    }
  } else {
    names = utm2tile_names(east, north, zone, type, dtlength=dtlength,
      dtprefix=dtprefix, qqprefix=qqprefix);
  }
  names = set_remove_duplicates(names);
  tiles = h_new();
  count = numberof(names);
  for(i = 1; i <= count; i++) {
    idx = extract_for_tile(east, north, zone, names(i), buffer=buffer);
    if(numberof(idx))
      h_set, tiles, names(i), idx;
  }
  return tiles;
}

func partition_type_summary(north, east, zone, buffer=, schemes=) {
/* DOCUMENT partition_type_summary, north, east, zone, buffer=, schemes=
  Displays a summary of what the results would be for each of the
  partitioning schemes.
*/
  default, schemes, ["it", "qq", "dt"];
  for(i = 1; i <= numberof(schemes); i++) {
    tiles = partition_by_tile(east, north, zone, schemes(i), buffer=buffer);
    write, format="Summary for: %s\n", schemes(i);
    tile_names = h_keys(tiles);
    write, format="  Number of tiles: %d\n", numberof(tile_names);
    counts = array(long, numberof(tile_names));
    for(j = 1; j <= numberof(tile_names); j++) {
      counts(j) = numberof(tiles(tile_names(j)));
    }
    qs = long(quartiles(counts));
    write, format="  Images per tile:%s", "\n";
    write, format="            Minimum: %d\n", counts(min);
    write, format="    25th percentile: %d\n", qs(1);
    write, format="    50th percentile: %d\n", qs(2);
    write, format="    75th percentile: %d\n", qs(3);
    write, format="            Maximum: %d\n", counts(max);
    write, format="               Mean: %d\n", long(counts(avg));
    write, format="                RMS: %.2f\n", counts(rms);
    write, format="%s", "\n";
  }
}

func save_data_to_tiles(data, zone, dest_dir, scheme=, mode=, suffix=, buffer=,
flat=, uniq=, overwrite=, verbose=, split_zones=, split_days=, day_shift=,
dtlength=, dtprefix=, qqprefix=, restrict_tiles=) {
/* DOCUMENT save_data_to_tiles, data, zone, dest_dir, scheme=, mode=, suffix=,
  buffer=, flat=, uniq=, overwrite=, verbose=, split_zones=, split_days=,
  day_shift=, dtlength=, dtprefix=, qqprefix=, restrict_tiles=

  Given an array of data (which must be in an ALPS data structure such as
  VEG__) and a scalar or array of zone corresponding to it, this will create
  PBD files in dest_dir partitioned using the given scheme.

  Parameters:
    data: Array of data in ALPS data struct
    zone: Scalar or array of UTM zone of data
    dest_dir: Destination directory for output pbd files

  Options:
    scheme= Should be one of the following; defaults to "10k2k".
      "qq" - Quarter quad tiles
      "dt" - 2km data tiles
      "it" - 10km index tiles
      "itdt" - Two-tiered index tile/data tile
    mode= Specifies the data mode to use. Can be any value valid for
      data2xyz.
        mode="fs"   First surface
        mode="ba"   Bathymetry
        mode="be"   Bare earth
    suffix= Specifies the suffix to use when naming the files. By default,
      files are named (tile-name).pbd. If suffix is provided, they will be
      named (tile-name)_(suffix).pbd. (Without the parentheses.)
    buffer= Specifies a buffer to include around each tile, in meters.
      Defaults to 100.
    flat= If set to 1, then no directory structure will be created. Instead,
      all files will be created directly into dest_dir.
    uniq= With the default value of uniq=1, only unique data points
      (determined by soe) will be stored in the output pbd files; duplicates
      will be removed. Set uniq=0 to keep duplicate data points.
    overwrite= By default, data will be appended to any existing pbd files.
      Set overwrite=1 to clobber them instead.
    verbose= By default, progress information will be provided. Set verbose=0
      to silence it.
    split_zones= This can be set to one of the following three values:
        split_zones=0  Never split data out by zone. This is the default
                  for most schemes.
        split_zones=1  Split data out by zone if there are multiple zones
                  present. This is the default for the qq scheme.
        split_zones=2  Always split data out by zone, even if only one zone
                  is present.
      Note: If flat=1, split_zones is ignored.
    split_days= Enables splitting the data by day. If enabled, the per-day
      files for each tile will be kept together and will be differentiated
      by date in the filename.
        split_days=0      Do not split by day. (default)
        split_days=1      Split by days, adding _YYYYMMDD to filename.
    day_shift= Specifies an offset in seconds to apply to the soes when
      determining their YYYYMMDD value for split_days. This can be used to
      shift time periods into the previous/next day when surveys are flown
      close to UTC midnight. The value is added to soe only for determining
      the date; the actual soe values remain unchanged.
        day_shift=0          No shift; UTC time (default)
        day_shift=-14400     -4 hours; EDT time
        day_shift=-18000     -5 hours; EST and CDT time
        day_shift=-21600     -6 hours; CST and MDT time
        day_shift=-25200     -7 hours; MST and PDT time
        day_shift=-28800     -8 hours; PST and AKDT time
        day_shift=-32400     -9 hours; AKST time
    dtlength= Specifies whether to use the short or long form for data tile
      (and related) schemes.
        dtlength="long"      Use long form: t_e234000_n3456000_15
        dtlength="short"     Use short form: e234_n3456_15
    dtprefix= Specifies whether to include the type prefix for data tile (and
      related) schemes. When enabled, index tiles are prefixed by i_, data
      tiles by t_, quad tiles by q_, and cell tiles by c_.
        dtprefix=0  Exclude prefix (default for dt when dtlength=="short")
        dtprefix=1  Include prefix (default for everything else)
    qqprefix= Specifies whether to prepend "qq" to the beginning of quarter
      quad names.
        qqprefix=0  Exclude prefix (default)
        qqprefix=1  Include prefix
    restrict_tiles= If specified, this must be a list of tile names that
      output should be restricted to. Only tiles in this list will be
      created.  Please make sure that these tiles have the same dtlength,
      dtprefix, and qqprefix settings; comparisons will be made as-is.

  SEE ALSO: batch_tile
*/
  local n, e;
  default, scheme, "itdt";
  default, mode, "fs";
  default, suffix, string(0);
  default, buffer, 100;
  default, flat, 0;
  default, uniq, 1;
  default, overwrite, 0;
  default, verbose, 1;
  default, split_zones, scheme == "qq";
  default, split_days, 0;
  default, day_shift, 0;

  aliases = h_new("10k2k", "itdt", "2k", "dt", "10k", "it");
  if(h_has(aliases, scheme))
    scheme = aliases(scheme);

  bilevel = scheme == "itdt";
  if(bilevel) scheme = "dt";

  data2xyz, data, e, n, mode=mode;

  if(numberof(zone) == 1)
    zone = array(zone, dimsof(data));

  if(verbose)
    write, "Partitioning data...";
  tiles = partition_by_tile(e, n, zone, scheme, buffer=buffer,
    dtlength=dtlength, dtprefix=dtprefix, qqprefix=qqprefix);

  tile_names = h_keys(tiles);
  if(!is_void(restrict_tiles))
    tile_names = set_intersection(tile_names, restrict_tiles);
  if(!numberof(tile_names)) {
    if(verbose)
      write, "No tiles found in list of permitted tiles (restrict_tiles=)";
    return;
  }
  tile_names = tile_names(sort(tile_names));

  if(verbose)
    write, format=" Creating files for %d tiles...\n", numberof(tile_names);

  tile_zones = long(tile2uz(tile_names));
  uniq_zones = numberof(set_remove_duplicates(tile_zones));
  if(uniq_zones == 1 && split_zones == 1)
    split_zones = 0;
  for(i = 1; i <= numberof(tile_names); i++) {
    curtile = tile_names(i);
    idx = tiles(curtile);
    if(bilevel) {
      tiledir = file_join(dt2it(curtile, dtlength=dtlength,
        dtprefix=dtprefix), curtile);
    } else {
      tiledir = curtile;
    }
    vdata = data(idx);
    vzone = zone(idx);
    vname = (scheme == "qq") ? curtile : extract_dt(curtile);
    tzone = tile_zones(i);

    // Coerce zones
    rezone_data_utm, vdata, vzone, tzone;

    outpath = dest_dir;
    if(!flat && split_zones)
      outpath = file_join(outpath, swrite(format="zone_%d", tzone));
    if(!flat && tiledir)
      outpath = file_join(outpath, tiledir);
    mkdirp, outpath;

    if(split_days) {
      dates = soe2date(vdata.soe + day_shift);
      date_uniq = set_remove_duplicates(dates);
      for(j = 1; j <= numberof(date_uniq); j++) {
        date_suffix = "_" + regsub("-", date_uniq(j), "", all=1);
        outfile = curtile + date_suffix;
        if(suffix) outfile += "_" + suffix;
        if(strpart(outfile, -3:) != ".pbd")
          outfile += ".pbd";

        outdest = file_join(outpath, outfile);

        if(overwrite && file_exists(outdest))
          remove, outdest;

        dname = vname + date_suffix;
        dw = where(dates == date_uniq(j));

        pbd_append, outdest, dname, vdata(dw), uniq=uniq;

        if(verbose)
          write, format=" %d: %s\n", i, outfile;
      }
    } else {
      outfile = curtile;
      if(suffix) outfile += "_" + suffix;
      if(strpart(outfile, -3:) != ".pbd")
        outfile += ".pbd";

      outdest = file_join(outpath, outfile);

      if(overwrite && file_exists(outdest))
        remove, outdest;

      pbd_append, outdest, vname, vdata, uniq=uniq;

      if(verbose)
        write, format=" %d: %s\n", i, outfile;
    }
  }
}

func batch_tile(srcdir, dstdir, scheme=, mode=, searchstr=, suffix=,
remove_buffers=, buffer=, uniq=, verbose=, zone=, shorten=, flat=,
split_zones=, split_days=, day_shift=, dtlength=, dtprefix=, qqprefix=,
verify_tiles=) {
/* DOCUMENT batch_tile, srcdir, dstdir, scheme=, mode=, searchstr=, suffix=,
  remove_buffers=, buffer=, uniq=, verbose=, zone=, shorten=, flat=,
  split_zones=, split_days=, day_shift=, dtlength=, dtprefix=, qqprefix=,
  verify_tiles=

  Loads the data in srcdir that matches searchstr= and partitions it into
  tiles, which are created in dstdir.

  Note: This operates in an "append" mode. If there are already files that
  have the same names as the files you are trying to create, they will be
  appended to. If you do not want that... delete them first!

  Parameters:
    srcdir: Directory of PBD data you want to tile.
    dstdir: Directory where your tiled data should go.

  Options:
    scheme= Partioning scheme to use. Valid values:
        scheme="itdt"     Tiered 10km/2km structure (default)
        scheme="dt"       2km structure
        scheme="it"       10km structure
        scheme="qq"       Quarter quad structure
    mode= Mode of data. Valid values include:
        mode="fs"         First surface (default)
        mode="be"         Bare earth
        mode="ba"         Bathy
    searchstr= Search string to use when locating input data. Example:
        searchstr="*.pbd"    (default)
    suffix= Suffix to append to file names when creating them. If your suffix
      does not end in .pbd, it will be auto-appended. Examples:
        suffix=".pbd"        (default)
        suffix="w84_fs"
        suffix="n88_g09_merged_be.pbd"
    remove_buffers= By default, it is assumed that your input data are
      already tiled and that any buffer regions on those tiles is
      redundant--and probably not well manually filtered. Thus, by default
      the buffers around the input tiles are removed. If your file names
      cannot be parsed as tile names, you'll get a warning message but
      they'll still be tiled (without removing anything). Valid settings:
        remove_buffers=1     Attempt to remove source data buffers
                      (default)
        remove_buffers=0     Use source data as is
    buffer= By default, output tiles will have a 100m buffer added to them.
      You can change that with this setting. Examples:
        buffer=100     Include 100m buffer (default)
        buffer=250     Include 250m buffer
        buffer=0       Do not include a buffer
    uniq= Specifies whether to discard points with matching soe values.
        uniq=1   Discard points with matching soe values (default)
        uniq=0   Keep all points, even duplicates
    verbose= Specifies how much output should go to the screen.
        verbose=2   Keeps you extremely well-informed
        verbose=1   Provides estimated time to completion (default)
        verbose=0   No screen output at all
    zone= By default, the zone will be determined on a file-by-file basis
      based on the file's name. If no parseable tile name can be determined,
      the file will be ignored. You can specify a zone to use for all files
      with this option.
        zone=[]     No zone provided, autodetect (default)
        zone=17     Force all input data to be treated as being in zone 17
        zone=-1     After loading the data, use data.zone (useful for ATM)
    shorten= By default (shorten=0), the long form of dt, it, and itdt tile
      names will be used. If shorten=1, the short forms will be used. This
      is shorthand for dtlength settings:
        shorten=0   -->   dtlength="long"
        shorten=1   -->   dtlength="short"
    flat= By default, files will be created in a directory structure. This
      settings lets you force them all into a single directory.
        flat=0   Put files in tired directory structure. (default)
        flat=1   Put files all directly into dstdir.
    split_zones= Specifies how to handle multiple-zone data. This is ignored
      if flat=1. Valid settings:
        split_zones=0     Never split data by zone. (default for most
                    schemes)
        split_zones=1     Split by zone if multiple zones found (default
                    for qq)
        split_zones=2     Always split by zone, even if only one found
    split_days= Enables splitting the data by day. If enabled, the per-day
      files for each tile will be kept together and will be differentiated
      by date in the filename.
        split_days=0      Do not split by day. (default)
        split_days=1      Split by days, adding _YYYYMMDD to filename.
    day_shift= Specifies an offset in seconds to apply to the soes when
      determining their YYYYMMDD value for split_days. This can be used to
      shift time periods into the previous/next day when surveys are flown
      close to UTC midnight. The value is added to soe only for determining
      the date; the actual soe values remain unchanged.
        day_shift=0          No shift; UTC time (default)
        day_shift=-14400     -4 hours; EDT time
        day_shift=-18000     -5 hours; EST and CDT time
        day_shift=-21600     -6 hours; CST and MDT time
        day_shift=-25200     -7 hours; MST and PDT time
        day_shift=-28800     -8 hours; PST and AKDT time
        day_shift=-32400     -9 hours; AKST time
    dtlength= Specifies whether to use the short or long form for data tile
      (and related) schemes. By default, this is set based on shorten=.
        dtlength="long"      Use long form: t_e234000_n3456000_15
        dtlength="short"     Use short form: e234_n3456_15
    dtprefix= Specifies whether to include the type prefix for data tile (and
      related) schemes. When enabled, index tiles are prefixed by i_, data
      tiles by t_, quad tiles by q_, and cell tiles by c_.
        dtprefix=0  Exclude prefix (default for dt when dtlength=="short")
        dtprefix=1  Include prefix (default for everything else)
    qqprefix= Specifies whether to prepend "qq" to the beginning of quarter
      quad names.
        qqprefix=0  Exclude prefix (default)
        qqprefix=1  Include prefix
    verify_tiles= By default, tiles are verified to ensure that no files get
      created for a tile that only has data in a buffer region. This
      requires a second pass across the input data. To disable this and
      possibly result in files with data only in the buffer region, use
      verify_tiles=0.
        verify_tiles=1    Run two passes (default if buffer > 0)
        verify_tiles=0    Run one pass only (default if buffer == 0)

  SEE ALSO: save_data_to_tiles
*/
  t0 = array(double, 3);
  timer, t0;

  default, mode, "fs";
  default, scheme, "10k2k";
  default, searchstr, "*.pbd";
  default, remove_buffers, 1;
  default, buffer, 100;
  default, verbose, 1;
  default, dtlength, (shorten ? "short" : "long");
  default, verify_tiles, (buffer > 0);

  // Locate files
  files = find(srcdir, searchstr=searchstr);

  // Get zones
  zones = tile2uz(file_tail(files));
  if(!is_void(zone))
    zones(*) = zone;

  // Check for missing zones
  if(noneof(zones)) {
    write, "None of the file names contained a parseable zone. Please use the zone= option.";
    return;
  } if(nallof(zones)) {
    w = where(zones == 0)
    write, "The following file names did not contain a parseable zone and will be skipped.\n (Consider using zone= to avoid this.)";
    write, format=" - %s\n", file_tail(files(w));
    write, "";

    files = files(w);
    zones = zones(w);
  }

  srt = msort(zones, files);
  zones = zones(srt);
  files = files(srt);

  // Check for missing tiles, if we need them.
  tiles = extract_tile(file_tail(files));
  if(remove_buffers && nallof(tiles)) {
    w = where(!tiles);
    write, "The following file names did not contain a parseable tile name. They will be\n retiled, but they cannot have any buffers removed; remove_buffers=1 will be\n ignored for these files."
    write, format=" - %s\n", file_tail(files(w));
    write, "";
  }

  restrict_tiles = [];
  if(verify_tiles) {
    if(verbose)
      write, format="Scanning data to determine tile coverage...%s", "\n";
    restrict_tiles = file_tile_coverage(files=files, zone=zones,
      scheme=scheme, remove_buffers=remove_buffers, dtlength=dtlength,
      dtprefix=dtprefix, qqprefix=qqprefix, verbose=1);
  }

  count = numberof(files);
  sizes = double(file_size(files));
  if(count > 1)
    sizes = sizes(cum)(2:);

  write, format="Tiling data...%s", "\n";
  t1 = tp = t0;
  timer, t1;
  passverbose = max(0, verbose-1);
  for(i = 1; i <= count; i++) {
    if(verbose > 1)
      write, format="\n----------\nRetiling %d/%d: %s\n", i, count,
        file_tail(files(i));

    data = pbd_load(files(i));

    if(remove_buffers && tiles(i) && numberof(data)) {
      filezone = zones(i);
      if(filezone < 0) {
        filezone = data.zone;
      }
      e = n = [];
      data2xyz, data, e, n, mode=mode;
      idx = extract_for_tile(e, n, filezone, tiles(i), buffer=0);
      e = n = [];
      if(numberof(idx))
        data = data(idx);
      else
        data = [];
    }

    if(!numberof(data)) {
      if(verbose > 1)
        write, " - Skipping, no data found for tile";
      continue;
    }

    filezone = zones(i);
    if(filezone < 0) {
      filezone = data.zone;
    }
    save_data_to_tiles, data, filezone, dstdir, scheme=scheme,
      suffix=suffix, buffer=buffer, flat=flat, uniq=uniq,
      verbose=passverbose, split_zones=split_zones, split_days=split_days,
      day_shift=day_shift, dtlength=dtlength, dtprefix=dtprefix,
      qqprefix=qqprefix, restrict_tiles=restrict_tiles;
    data = filezone = [];

    if(verbose)
      timer_remaining, t1, sizes(i), sizes(0), tp, interval=10;
  }

  if(verbose)
    timer_finished, t0;
}

func file_tile_coverage(dir, searchstr=, files=, scheme=, zone=,
remove_buffers=, dtlength=, dtprefix=, qqprefix=, mode=, verbose=) {
/* DOCUMENT file_tile_coverage(dir, searchstr=, files=, scheme=, zone=,
  remove_buffers=, dtlength=, dtprefix=, qqprefix=, mode=, verbose=)

  Returns an array of the tiles covered by the given data.

  Parameters:
    dir: Directory of PBD data you want to examine.

  Options:
    searchstr= Search string to use when locating data. Example:
        searchstr="*.pbd"    (default)
    files= List of files to analyze. If provided, dir and searchstr= are
      ignored.
    scheme= Partioning scheme to use. Valid values:
        scheme="dt"    2km structure
        scheme="it"    10km structure
        scheme="qq"    Quarter quad structure
    zone= By default, the zone will be determined on a file-by-file basis
      based on the file's name. If no parseable tile name can be determined,
      the file will be ignored. You can specify a zone to use for all files
      with this option.
        zone=[]     No zone provided, autodetect (default)
        zone=17     Force all input data to be treated as being in zone 17
        zone=-1     After loading the data, use data.zone (useful for ATM)
    remove_buffers= By default, it is assumed that your data are already
      tiled and that any buffer regions on those tiles is redundant--and
      probably not well manually filtered. Thus, by default the buffers
      around the input tiles are removed. If your file names cannot be
      parsed as tile names, they'll still be tiled without removing
      anything. Valid settings:
        remove_buffers=1     Attempt to remove source data buffers
                      (default)
        remove_buffers=0     Use source data as is
    dtlength= Specifies whether to use the short or long form for data tile
      (and related) schemes. By default, this is set based on shorten=.
        dtlength="long"      Use long form: t_e234000_n3456000_15
        dtlength="short"     Use short form: e234_n3456_15
    dtprefix= Specifies whether to include the type prefix for data tile (and
      related) schemes. When enabled, index tiles are prefixed by i_, data
      tiles by t_, quad tiles by q_, and cell tiles by c_.
        dtprefix=0  Exclude prefix
        dtprefix=1  Include prefix
    qqprefix= Specifies whether to prepend "qq" to the beginning of quarter
      quad names.
        qqprefix=0  Exclude prefix
        qqprefix=1  Include prefix
    mode= Mode of data. Valid values include:
        mode="fs"   First surface (default)
        mode="be"   Bare earth
        mode="ba"   Bathy
    verbose= Specifies how much output should go to the screen.
        verbose=2   Keeps you extremely well-informed
        verbose=1   Provides estimated time to completion (default)
        verbose=0   No screen output at all
*/
  local e, n;
  default, searchstr, "*.pbd";
  default, remove_buffers, 1;
  default, mode, "fs";
  default, scheme, "10k2k";
  default, verbose, 1;

  aliases = h_new("10k2k", "dt", "2k", "dt", "10k", "it");
  if(h_has(aliases, scheme))
    scheme = aliases(scheme);

  if(is_void(files))
    files = find(dir, searchstr=searchstr);

  count = numberof(files);
  file_tiles = extract_tile(file_tail(files));

  sizes = double(file_size(files));
  if(count > 1)
    sizes = sizes(cum)(2:);

  zones = tile2uz(file_tail(files));
  if(!is_void(zone))
    zones(*) = zone;

  // Quick scan of the data to get tile information
  tile_lists = array(pointer, count);

  t0 = array(double, 3);
  timer, t0;
  tp = t0;

  for(i = 1; i <= count; i++) {
    data = pbd_load(files(i));

    if(remove_buffers && file_tiles(i) && numberof(data)) {
      filezone = zones(i);
      if(filezone < 0) {
        filezone = data.zone;
      }
      data2xyz, data, e, n, mode=mode;
      idx = extract_for_tile(e, n, filezone, file_tiles(i), buffer=0);
      e = n = [];
      if(numberof(idx))
        data = data(idx);
      else
        data = [];
    }

    if(!numberof(data)) {
      continue;
    }

    filezone = zones(i);
    if(filezone < 0) {
      filezone = data.zone;
    }

    data2xyz, data, e, n, mode=mode;

    temp = partition_by_tile(e, n, filezone, scheme, buffer=0,
      dtlength=dtlength, dtprefix=dtprefix, qqprefix=qqprefix);
    tile_lists(i) = &h_keys(temp);
    temp = [];

    if(verbose)
      timer_remaining, t0, sizes(i), sizes(0), tp, interval=10;
  }

  return set_remove_duplicates(merge_pointers(tile_lists));
}

func tile_extent_shapefile(fn, dir, searchstr=, files=, usedirnames=, restrict=) {
/* DOCUMENT tile_extent_shapefile(fn, dir, searchstr=, usedirnames=, restrict=)
  -or- tile_extent_shapefile(fn, files=, usedirnames=, restrict=)

  Creates an ASCII shapefile with polygons for each tile represented by the
  given data. Each tile will have a closed polygon (a square) created with
  associated attributes for the tile's name as well as its number in sequence.

  Parameters:
    fn: Output filename for the ASCII shapefile to create.
    dir: Directory to search (using searchstr=) for file tile information.
  Options:
    searchstr= Search string to use with dir to find files.
        searchstr="*.pbd"    Default
    files= Specifies a list of files to use. This causes dir and searchstr=
      to be ignored. This should be an array of strings. Each string should
      be a filename. (You can also provide an array of tile names and that
      will also work.)
    usedirnames= When enabled, tile names will be parsed from the directory
      names as well as the file names. This is recusive to all parent
      directories.
        usedirnames=0        Do not use directory names for tiles (default)
        usedirnames=1        Attempt to use directory names for tiles
    restrict= Restrict the type of tiles that will be detected.
        restrict=[]       (or omitted) Do not restrict, default
        restrict="dt"     Restrict to 2km tiles
        restrict="2km"    Restrict to 2km tiles
        restrict="it"     Restrict to 10km tiles
        restrict="10km"   Restrict to 10km tiles
  Notes:
    - This is only intended for use on 2km and 10km tiles.
    - This will not work for quarter-quads. Attempting to use for
      quarter-quads will provoke an error.
    - This will not work properly for 1km quads or 250m cells. The tile
      polygons and names will be correct, but the numbering will not be
      correct.
    - This will not work properly if there are multiple zones present. You
      will have to handle each zone separately.
    - If a searchstr= yields several files for the same tile, that tile will
      only occur once in the output.
*/
  default, searchstr, "*.pbd";
  default, usedirnames, 0;

  if(is_void(files))
    files = find(dir, searchstr=searchstr);
  if(!numberof(files))
    error, "No files found";
  tiles = extract_tile(file_tail(files), dtlength="short", dtprefix=1);
  if(nallof(tiles) && usedirnames) {
    dirs = files;
    tiles = [&tiles];
    while(numberof(dirs)) {
      dirs = set_remove_duplicates(file_dirname(dirs));
      grow, tiles, &extract_tile(file_tail(dirs), dtlength="short", dtprefix=1);
      dirs = set_difference(dirs, [".", "/"]);
    }
    tiles = merge_pointers(tiles);
  }
  tiles = tiles(where(tiles));
  if(!numberof(tiles))
    error, "No tiles found";
  tiles = set_remove_duplicates(tiles);
  if(restrict == "dt" || restrict == "2km") {
    w = where(strpart(tiles, 1:2) == "t_");
    tiles = numberof(w) ? tiles(w) : [];
  }
  if(restrict == "it" || restrict == "10km") {
    w = where(strpart(tiles, 1:2) == "i_");
    tiles = numberof(w) ? tiles(w) : [];
  }
  if(!numberof(tiles))
    error, "No tiles found";

  key = strsplit(tiles, "_");
  // First, descending by northing
  key1 = -atoi(strpart(key(,3), 2:));
  // Then, ascending by easting
  key2 = atoi(strpart(key(,2), 2:));
  tiles = tiles(msort(key1, key2));
  key = key1 = key2 = [];

  count = numberof(tiles);
  shp = array(pointer, count);
  meta = array(string, count);
  for(i = 1; i <= count; i++) {
    bbox = tile2bbox(tiles(i));
    shp(i) = &double(bbox([[2,3],[2,1],[4,1],[4,3],[2,3]]));
    meta(i) = swrite(format="TILE_NAME=%s\n", tiles(i));
    meta(i) += swrite(format="TILE_NUMBER=%d\n", i);
    meta(i) += swrite(format="LABEL_POS=%.2f,%.2f\n",
      bbox([2,4])(avg), bbox([1,3])(avg));
    meta(i) += "CLOSED=YES\n";
  }

  write_ascii_shapefile, shp, fn, meta=meta;
}
