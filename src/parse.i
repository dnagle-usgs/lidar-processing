// vim: set ts=4 sts=4 sw=4 ai sr et:

require, "eaarl.i";

func extract_tile(text, dtlength=, qqprefix=) {
/* DOCUMENT extract_tile(text, dtlength=, qqprefix=)
    Attempts to extract a tile name from each string in the given array of text.

    Options:
        dtlength= Dictates which kind of data tile name is returned when a data
            tile is detected. (Note: This has no effect on index tile names.)
            Valid values:
                dtlength="short"  Returns short form (default)
                dtlength="long"   Returns long form

        qqprefix= Dictates whether quarter quad tiles should be prefixed with
            "qq". Useful if they're going to be used as variable names. Valid
            values:
                qqprefix=0      No prefix added (default)
                qqprefix=1      Prefix added

    If a tile has an ambiguous name, then index tile names take priority over
    data tile names and data tile names take priority over quarter quad names.
    If a tile does not contain a parseable name, then a nil string is yielded.
*/
// Original David Nagle 2009-12-09
    default, dtlength, "short";
    default, qqprefix, 0;
    qq = extract_qq(text);
    dt = (dtlength == "short") ? dt_short(text) : dt_long(text);
    it = "i_" == strpart(text, 1:2);

    result = array(string, dimsof(text));

    w = where(strlen(dt) > 0 & it);
    if(numberof(w))
        result(w) = get_dt_itcodes(dt(w));

    w = where(strlen(dt) > 0 & !strlen(result));
    if(numberof(w))
        result(w) = dt(w);

    w = where(strlen(qq) > 0 & !strlen(result));
    if(numberof(w))
        result(w) = (qqprefix ? "qq" : "") + qq(w);

    return result;
}

func guess_tile(text, dtlength=, qqprefix=) {
    local e, n, z;
    extern curzone;

    tile = extract_tile(text);
    w = where(!tile);
    if(numberof(w)) {
        regmatch, "e([1-9][0-9]{2}).*n([1-9][0-9]{3})", text(w), , e, n;
        wen = where(!(!e) & !(!n));
        if(numberof(wen))
            tile(w(wen)) = swrite(format="e%s_n%s_%d", e(wen), n(wen), curzone);
    }
    return tile;
}

func tile_type(text) {
/* DOCUMENT tile_type(text)
    Returns string indicating the type of tile used.

    The return result (scalar or array, depending on the input) will have
    strings that mean the following:

        "dt" - Two-kilometer data tile
        "it" - Ten-kilometer index tile
        "qq" - Quarter quad tile
        (nil) - Unparseable
*/
    qq = extract_qq(text);
    dt = dt_short(text);
    it = "i_" == strpart(text, 1:2);

    result = array(string, dimsof(text));

    w = where(strlen(dt) > 0 & it);
    if(numberof(w))
        result(w) = "it";

    w = where(strlen(dt) > 0 & !strlen(result));
    if(numberof(w))
        result(w) = "dt";

    w = where(strlen(qq) > 0 & !strlen(result));
    if(numberof(w))
        result(w) = "qq";

    return result;
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
    tile = extract_tile(tile, dtlength="long", qqprefix=1);
    key = strpart(tile, 1:1);

    if(key == "q") {
        zone = qq2uz(tile);
        ll = qq2ll(tile, bbox=1); // [south, east, north, west]
        lats = ll([1,3,1,3]);
        lons = ll([2,4,4,2]);
        norths = easts = [];
        fll2utm, lats, lons, norths, easts, force_zone=zone;
        return [norths(min), easts(max), norths(max), easts(min)];
    } else if(key == "t") {
        return dt2utm(tile, bbox=1);
    } else if(key == "i") {
        return it2utm(tile, bbox=1);
    } else {
        return [];
    }
}

func extract_qq(text) {
/* DOCUMENT extract_qq(text)

    Extract the quarter quad string from a text string. The text string will
    probably be a filename or similar. The expected rules it will follow:

    - The QQ name may be optionally preceeded by other text, but must be
      separated by an underscore if so.
    - The QQ name may be optionally followed by other text, but must be
      separated by either an underscore or a period if so.
    - The QQ name must be exactly 8 characters in length, and must use lowercase
      alpha instead of uppercase alpha where relevant.

    This function will work on scalars or arrays. The returned result will be
    the quarter quad name(s). If there is no quarter quad to extract, it will
    be string(0).
*/
//  Original David Nagle 2008-07-17
    regmatch, "(^|_|qq)([0-9][0-9][0-1][0-9][0-9][a-h][1-8][a-d])(\.|_|$)", text, , , qq;
    return qq;
}

func dt_short(dtcodes) {
/* DOCUMENT shortnames = dt_short(dtcodes)
    Returns abbreviated names for an array of data tile codes. Strings that
    aren't data tile codes become string(0).

    Example:

        > dt_short("t_e466000_n3354000_16")
        "e466_n3354_16"
*/
//  Original David Nagle 2008-07-21
    e = n = z = []; // prevents the next line from making them externs
    regmatch, "(^|_)e([1-9][0-9]{2})(000)?_n([1-9][0-9]{3})(000)?_z?([1-9][0-9]?)[c-hj-np-xC-HJ-NP-X]?(_|\\.|$)", dtcodes, , , e, , n, , z;
    w = where( !(!e) & !(!n) & !(!z) );
    result = array(string(0), dimsof(dtcodes));
    if(numberof(w))
        result(w) = swrite(format="e%s_n%s_%s", e(w), n(w), z(w));
    return result;
}

func dt_long(dtcodes) {
/* DOCUMENT longnames = dt_long(dtcodes)
    Returns full names for an array of data tile codes. Strings that aren't
    data tile codes become string(0).

    Example:

        > dt_long("e466_n3354_16")
        "t_e466000_n3354000_16"
*/
//  Original David Nagle 2008-08-07
    e = n = z = []; // prevents the next line from making them externs
    regmatch, "(^|_)e([1-9][0-9]{2})(000)?_n([1-9][0-9]{3})(000)?_z?([1-9][0-9]?)[c-hj-np-xC-HJ-NP-X]?(_|\\.|$)", dtcodes, , , e, , n, , z;
    w = where( !(!e) & !(!n) & !(!z) );
    result = array(string(0), dimsof(dtcodes));
    if(numberof(w))
        result(w) = swrite(format="t_e%s000_n%s000_%s", e(w), n(w), z(w));
    return result;
}

func dt2uz(dtcodes) {
/* DOCUMENT dt2uz(dtcodes)
    Returns the UTM zone(s) for the given dtcode(s).
*/
// Original David Nagle 2009-07-06
    zone = [];
    dt2utm, dtcodes, , , zone;
    return zone;
}

func dt2utm(dtcodes, &north, &east, &zone, bbox=, centroid=) {
/* DOCUMENT dt2utm(dtcodes, bbox=, centroid=)
    dt2utm, dtcodes, &north, &east, &zone

    Returns the northwest coordinates for the given dtcodes as an array of
    [north, west, zone].

    If bbox=1, then it instead returns the bounding boxes, as an array of
    [south, east, north, west, zone].

    If centroid=1, then it returns the tile's central point.

    If called as a subroutine, it sets the northwest coordinates of the given
    output variables.
*/
//  Original David Nagle 2008-07-21
    e = n = z = []; // prevents the next line from making them externs
    regmatch, "(^|_)e([1-9][0-9]{2})(000)?_n([1-9][0-9]{3})(000)?_z?([1-9][0-9]?)[c-hj-np-xC-HJ-NP-X]?(_|\\.|$)", dtcodes, , , e, , n, , z;
    w = where( ! (!(!e) & !(!n) & !(!z)) );
    if(numberof(w)) {
        e(w) = "0";
        n(w) = "0";
        z(w) = "0";
    }
    e = atoi(e + "000");
    n = atoi(n + "000");
    z = atoi(z);

    if(am_subroutine()) {
        north = n;
        east = e;
        zone = z;
    }

    if(is_void(z))
        return [];
    else if(bbox)
        return [n - 2000, e + 2000, n, e, z];
    else if(centroid)
        return [n - 1000, e + 1000, z];
    else
        return [n, e, z];
}

func it2utm(itcodes, bbox=, centroid=) {
/* DOCUMENT it2utm(itcodes, bbox=, centroid=)
    Returns the northwest coordinates for the given itcodes as an array of
    [north, west, zone].

    If bbox=1, then it instead returns the bounding boxes, as an array of
    [south, east, north, west, zone].

    If centroid=1, then it returns the tile's central point.
*/
//  Original David Nagle 2008-07-21
    u = dt2utm(itcodes);
    
    if(is_void(u))
        return [];
    else if(bbox)
        return [u(..,1) - 10000, u(..,2) + 10000, u(..,1), u(..,2), u(..,3)];
    else if(centroid)
        return [u(..,1) -  5000, u(..,2) +  5000, u(..,3)];
    else
        return u;
}


func get_utm_dtcodes(north, east, zone) {
/* DOCUMENT dt = get_utm_dtcodes(north, east, zone)
    For a set of UTM northings, eastings, and zones, this will calculate each
    coordinate's data tile name and return an array of strings that correspond
    to them.
*/
//  Original David Nagle 2008-07-21
    return swrite(format="t_e%.0f000_n%.0f000_%d",
        floor(east /2000.0)*2,
        ceil (north/2000.0)*2,
        int(zone));
}

func get_utm_dtcode_coverage(north, east, zone) {
/* DOCUMENT dt = get_utm_dtcode_coverage(north, east, zone)
    For a set of UTM northings, eastings, and zones, this will calculate the
    set of data tiles that encompass all the points.

    This is equivalent to
        dt = set_remove_duplicates(get_utm_dtcodes(north,east,zone))
    but works much more efficiently (and faster).
*/
// Original David Nagle 2009-07-09
    east = long(floor(unref(east)/2000.0));
    north = long(ceil(unref(north)/2000.0));
    code = long(unref(zone)) * 1000 * 10000 + unref(east) * 10000 + unref(north);
    code = set_remove_duplicates(unref(code));
    north = code % 10000;
    code /= 10000;
    east = code % 1000;
    zone = code / 1000;
    return swrite(format="t_e%d000_n%d000_%d", east*2, north*2, zone);
}

func get_utm_itcodes(north, east, zone) {
/* DOCUMENT it = get_utm_itcodes(north, east, zone)
    For a set of UTM northings, eastings, and zones, this will calculate each
    coordinate's index tile name and return an array of strings that correspond
    to them.
*/
//  Original David Nagle 2009-07-09
    return swrite(format="i_e%.0f000_n%.0f000_%d",
        floor(east /10000.0)*10,
        ceil (north/10000.0)*10,
        int(zone));
}

func get_utm_itcode_coverage(north, east, zone) {
/* DOCUMENT it = get_utm_itcode_coverage(north, east, zone)
    For a set of UTM northings, eastings, and zones, this will calculate the
    set of index tiles that encompass all the points.

    This is equivalent to
        it = set_remove_duplicates(get_utm_itcodes(north,east,zone))
    but works much more efficiently (and faster).
*/
// Original David Nagle 2009-07-09
    east = long(floor(unref(east)/10000.0));
    north = long(ceil(unref(north)/10000.0));
    code = long(unref(zone)) * 10000000 + unref(east) * 10000 + unref(north);
    code = set_remove_duplicates(unref(code));
    north = code % 10000;
    code /= 10000;
    east = code % 1000;
    zone = code / 1000;
    return swrite(format="i_e%d0000_n%d0000_%d", east, north, zone);
}

func get_dt_itcodes(dtcodes) {
/* DOCUMENT it = get_dt_itcodes(dtcodes)
    For an array of data tile codes, this will return the corresponding index
    tile codes.

    Original David Nagle 2008-07-21
*/
    north = east = zone = [];
    dt2utm, dtcodes, north, east, zone;
    north = int(ceil(north/10000.)*10000.);
    east = int(floor(east/10000.)*10000.);
    return swrite(format="i_e%i_n%i_%i", east, north, zone);
}

func get_date(text) {
/* DOCUMENT get_date(text)
    Given an arbitrary string of text, this will parse out the date and return
    it in YYYY-MM-DD format.

    This will match using the following rules:
    * The date must be at the beginning of the string.
    * The date may be in YYYY-MM-DD or YYYYMMDD format. (But cannot be in
      YYYY-MMDD or YYYYMM-DD format.)
    * If there are any characters following the date, the first must not be a
      number. (So 20020101pm is okay but 200201019 is not.)

    If text is an array of strings, then an array of strings (with the same
    dimensions) will be returned.

    If a string does not contain a parseable date, then the nil string
    (string(0)) will be returned instead.
*/
    // Original David Nagle 2008-12-24 (as part of ytime.i's
    // determine_gps_time_correction)
    // The year may be in the range 1970 to 2099.
    yreg = "19[789][0-9]|20[0-9][0-9]";
    // The month may be in the range 01 to 12.
    mreg = "0[1-9]|1[0-2]";
    // The day may be in the range 01 to 31.
    dreg = "0[1-9]|[12][0-9]|3[01]";

    full_reg = swrite(format="^(%s)(-?)(%s)\\2(%s)($|[^0-9])", yreg, mreg, dreg);

    m_full = m_year = m_dash = m_month = m_day = [];
    w = where(regmatch(full_reg, text, m_full, m_year, m_dash, m_month, m_day));
    
    result = array(string(0), dimsof(text));
    if(numberof(w)) {
        result(w) = swrite(format="%s-%s-%s", m_year(w), m_month(w), m_day(w));
    }

    return result;
}

func cir_to_soe(filename, offset=) {
/* DOCUMENT cir_to_soe(filename, offset=)
    Parses a CIR image's filename and returns the second of the epoch from when
    it was taken.

    offset specifies an offset to apply to the raw soe value. By default,
    offset=1.12, which should correct the raw CIR filename timestamp to the
    correct time value.
*/
// Original David B. Nagle 2009-02-23
    default, offset, 1.12;

    dmreg = "0[0-9]|1[01]";             // (date) month reg exp 00-11
    ddreg = "0[1-9]|[12][0-9]|3[01]";   // (date) day reg exp 01-31
    dyreg = "[890123][0-9]";            // (date) year reg exp 80-39
    threg = "[01][0-9]|2[0-3]";         // (time) hour reg exp 00-23
    tmreg = "[0-5][0-9]";               // (time) minute reg exp 00-59
    tsreg = "[0-5][0-9]";               // (time) second reg exp 00-59

    full_reg = swrite(format="^(%s)(%s)(%s)-(%s)(%s)(%s)-cir.jpg$",
        dmreg, ddreg, dyreg, threg, tmreg, tsreg);
    
    m_full = m_dm = m_dd = m_dy = m_th = m_tm = m_ts = [];
    w = where(regmatch(full_reg, filename, m_full,
        m_dm, m_dd, m_dy, m_th, m_tm, m_ts));

    result = array(double(-1), dimsof(filename));
    if(numberof(w)) {
        yy = atod(m_dy(w));
        c20 = yy > 60; // 20th century
        yyyy = array(double, dimsof(yy));
        if(numberof(where(c20)))
            yyyy(where(c20)) = yy(where(c20)) + 1900;
        if(numberof(where(!c20)))
            yyyy(where(!c20)) = yy(where(!c20)) + 2000;

        result(w) = ymd2soe(
            yyyy, atod(m_dm(w))+1, atod(m_dd(w)),
            hms2sod(atod(m_th(w)), atod(m_tm(w)), offset + atod(m_ts(w))));
    }

    return result;
}

func cam_to_soe(filename, offset=) {
/* DOCUMENT cam_to_soe(filename, offset=)
    Parses an RGB image's filename and returns the second of the epoch from when
    it was taken.

    offset specifies an offset to apply to the raw soe value. By default,
    offset=0.
*/
    default, offset, 0;

    dmreg = "0[1-9]|1[02]";             // (date) month reg exp 01-12
    ddreg = "0[1-9]|[12][0-9]|3[01]";   // (date) day reg exp 01-31
    dyreg = "[12][90][890123][0-9]";    // (date) year reg exp 1980-2039
    threg = "[01][0-9]|2[0-3]";         // (time) hour reg exp 00-23
    tmreg = "[0-5][0-9]";               // (time) minute reg exp 00-59
    tsreg = "[0-5][0-9]";               // (time) second reg exp 00-59

    reg = "^cam1(47|)_(CAM1_|)";
    reg += swrite(format="(%s)(-|_)(%s)(-|)(%s)_", dyreg, dmreg, ddreg);
    reg += swrite(format="(%s)(%s)(%s)([-_][0-9][0-9]|)\.jpg$", threg, tmreg, tsreg);

    m_full = m_dm = m_dd = m_dy = m_th = m_tm = m_ts = m_no = [];
    w = where(regmatch(reg, filename, m_full,
        m_no, m_no, m_dy, m_no, m_dm, m_no, m_dd, m_th, m_tm, m_ts, m_no));

    result = array(double(-1), dimsof(filename));
    if(numberof(w)) {
        result(w) = ymd2soe(
            atod(m_dy(w)), atod(m_dm(w)), atod(m_dd(w)),
            hms2sod(atod(m_th(w)), atod(m_tm(w)), offset+atod(m_ts(w))));
    }

    return result;
}

func parse_rn(rn) {
/* DOCUMENT parse_rn(rn)
    Simple wrapper that returns [rasterno, pulseno] for the given rn.
*/
// Original David Nagle 2009-07-21
    return [rn&0xffffff, rn/0xffffff];
}

func parse_datum(text) {
/* DOCUMENT parse_datum(text)
    Given a text string, this parses the datum information out of it if possible.

    This expects to find the datum formatted in one of the following kinds of
    ways:

        WGS-84:
            *_w84_* *_w84.* w84_*
        NAD-83:
            *_n83_* *_n83.* n83_*
        NAVD-88 without geoid:
            *_n88_* *_n88.* n88_*
        NAVD-88 with geoid:
            *_n88_g96_* *_n88_g96.* n88_g96_*
            *_n88_g99_* *_n88_g99.* n88_g99_*
            *_n88_g03_* *_n88_g03.* n88_g03_*
            *_n88_g03dep_* *_n88_g03dep.* n88_g03dep_*
            *_n88_g06_* *_n88_g06.* n88_g06_*
            *_n88_g09_* *_n88_g09.* n88_g09_*

    Four pieces of information will be returned: [datum, geoid, prefix, suffix]
    These pieces are:
        datum: The datum string, one of "w84", "n83", or "n88".
        geoid: The geoid string, one of "96", "99", "03", "03dep", "06", or
            "09". ("03dep" is for the deprecated version of GEOID03.)
        prefix: Anything in "text" that came before the datum/geoid.
        suffix: Anything in "text" that came after the datum/geoid.

    If no datum could be parsed, then all four values will be (nil).
    If no geoid could be parsed or if it is not applicable, it will be (nil).

    This can handle array input as well as scalar. For arrays, you can index
    the results as follows:
        result(..,1) - datum
        result(..,2) - geoid
        result(..,3) - prefix
        result(..,4) - suffix
*/
// Original David Nagle 2009-12-24
    scalar = is_scalar(text);

    part1 = part2 = part3 = datum = geoid = [];
    regmatch, "(^.*?(^|_))(w84|n83|n88)((\.|_|$).*$)", text, , part1, , datum, part2;
    regmatch, "^_g(96|99|03dep|03|06|09)((\.|_|$).*$)", part2, , geoid, part3;

    w = where(datum != "n88");
    if(numberof(w)) {
        if(scalar)
            geoid = string(0);
        else
            geoid(w) = string(0);
    }

    w = where(strlen(geoid));
    if(numberof(w)) {
        if(scalar)
            part2 = part3;
        else
            part2(w) = part3(w);
    }

    part3 = [];

    return [datum, geoid, part1, part2];
}
