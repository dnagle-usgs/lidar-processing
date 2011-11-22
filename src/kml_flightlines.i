// vim: set ts=2 sts=2 sw=2 ai sr et:
require, "eaarl.i";

// PNAV/MISSION ORIENTED FUNCTIONS

func batch_kml_mission(datadir, outdir, searchstr=, outfile=, webdest=) {
/* DOCUMENT batch_kml_mission, datadir, outdir, searchstr=, outfile=, webdest=
  This is used to create kml/kmz files for a collection of missions.

  Parameters:
    datadir: The directory (or array of directories) to search for missions
      in.
    outdir: The directory where the created kml/kmz files will go.

  Options:
    searchstr= The search string to use for finding mission json files.
      Default: searchstr="flightlines.json"
    outfile= The name of the overall kml file to create, for the entire
      collection. Default: outfile="eaarl.kml"
    webdest= The destination directory on the web. If this is used, then all
      of the KML files will be updated to use full URL references, prefixing
      this to what they'd normally have used.
*/
  default, searchstr, "flightlines.json";
  default, outfile, "eaarl.kml";

  if(!is_void(webdest))
    fix_dir, webdest;

  jsons = paths = [];
  for(i = 1; i <= numberof(datadir); i++) {
    cur = find(datadir(i), glob=searchstr);
    grow, jsons, cur;
    grow, paths, file_dirname(file_relative(datadir(i), cur));
  }

  srt = sort(paths);
  jsons = jsons(srt);
  paths = paths(srt);
  srt = [];

  jsons = strchar(jsons);
  paths = strchar(paths);

  jidx = grow(0, where(jsons == 0));
  pidx = grow(0, where(paths == 0));

  missiondata_cache, "disable";
  missiondata_cache, "clear";

  mission_kmls = day_kmls = part_kmls = array(pointer, numberof(jidx)-1);
  tree = h_new();
  webtree = h_new();

  t0 = array(double, 3);
  timer, t0;

  for(i = 1; i < numberof(jidx); i++) {
    json = strchar(jsons(jidx(i)+1:jidx(i+1)));
    path = strchar(paths(pidx(i)+1:pidx(i+1)));

    passdest = [];
    if(!is_void(webdest))
      passdest = webdest + path + "/";
    result = kml_mission(conf_file=json, keepkml=1,
      outdir=file_join(outdir, path), webdest=passdest);
    if(is_void(result))
      continue;
    fn = file_join(file_dirname(json), (*result(1))(1));

    mission_kmls(i) = &(strchar(fn));
    day_kmls(i) = &(strchar(file_join(file_dirname(json), *result(2))));
    part_kmls(i) = &(strchar(file_join(file_dirname(json), *result(3))));
    result = [];

    treepath = strsplit(path, "/");
    node = tree;
    for(j = 1; j < numberof(treepath); j++) {
      if(!h_has(node, treepath(j))) {
        h_set, node, treepath(j), h_new();
      }
      node = node(treepath(j));
    }
    h_set, node, treepath(0), kml_NetworkLink(
      kml_Link(href=file_relative(outdir, fn)),
      name=treepath(0)
    );

    if(!is_void(webdest)) {
      node = webtree;
      for(j = 1; j < numberof(treepath); j++) {
        if(!h_has(node, treepath(j))) {
          h_set, node, treepath(j), h_new();
        }
        node = node(treepath(j));
      }
      h_set, node, treepath(0), kml_NetworkLink(
        kml_Link(href=webdest + file_relative(outdir, fn)),
        name=treepath(0)
      );
    }

    timer_remaining, t0, i, numberof(jidx);
  }

  write, format="\n----------\nProcessing %s\n", "everything";
  outname = file_join(outdir, outfile);
  kml_save, outname, __batch_kml_mission_builder(tree), name="EAARL flightlines";

  // Convert pointer arrays into string arrays
  mission_kmls = strchar(merge_pointers(mission_kmls));
  day_kmls = strchar(merge_pointers(day_kmls));
  part_kmls = strchar(merge_pointers(part_kmls));

  kmz = file_rootname(outname) + ".kmz";
  kmz_create, kmz, outname, mission_kmls, day_kmls, part_kmls;

  if(!is_void(webdest)) {
    remove, outname;
    kml_save, outname, __batch_kml_mission_builder(webtree),
      name="EAARL flightlines";
    webify = grow(mission_kmls, day_kmls);
    for(i = 1; i <= numberof(webify); i++) {
      remove, webify(i);
      rename, file_rootname(webify(i)) + "-web.kml", webify(i);
    }
  }

  timer_finished, t0;
}

func __batch_kml_mission_builder(node) {
  keys = h_keys(node);
  keys = keys(sort(keys));
  children = [];
  for(i = 1; i <= numberof(keys); i++) {
    val = node(keys(i));
    if(!is_string(val)) {
      val = kml_Folder(
        __batch_kml_mission_builder(val),
        name=keys(i)
      );
    }
    grow, children, val;
  }
  return children;
}

func kml_mission(void, conf_file=, outdir=, name=, keepkml=, webdest=) {
/* DOCUMENT kml_mission, conf_file=, outdir=, name=
  Creates kml/kmz files for a mission, based on the currently defined mission
  configuration.

  To create for the currently loaded mission, just run:
    kml_mission;
  This will create a kml subdirectory for the mission that contains all the
  relevant files. A KMZ will be created for each mission day, plus a KMZ will
  be created that contains all of the mission days together.

  Options:
    conf_file= This specifies the path of a json mission configuration file
      to load and use, instead of the currently loaded mission
      configuration.
    outdir= The output directory to put the results in. This defaults to a
      "kml" subdirectory in the mission directory.
    name= Name of the mission. Used in creating the full mission KML/KMZ
      file's filename and also used to label things in the file. Defaults to
      the last component of the mission path.
    keepkml= By default, your final result will be just KMZ files. However,
      these KMZ files were generated by a whole lot of KML files. If you
      want the KML files to stick around, set keepkml=1. This is useful if
      you'll be serving the flightlines from a web interface or integrating
      the kml results into a single larger KMZ file, for example.
    webdest= The destination directory on the web. Do not use directly; this
      is used by batch_mission_kml.

  As an example, if your mission path is /data/0/EAARL/raw/NorIda, then you'll
  get these as defaults:
    outdir="/data/0/EAARL/raw/NorIda/kml/", name="NorIda"
  The full-mission kmz file would then be:
    /data/0/EAARL/raw/NorIda/kml/NorIda.kmz
*/
  extern pnav;

  if(!is_void(conf_file))
    mission_load, conf_file;

  default, outdir, file_join(mission_path(), "kml");
  default, name, file_tail(mission_path());
  default, keepkml, !is_void(webdest);

  mkdirp, outdir;

  days = missionday_list();
  if(is_void(days)) {
    write, "No mission days defined, skipping!";
    return [];
  }
  days = days(sort(days));

  masters = files = links = weblinks = [];

  for(i = 1; i <= numberof(days); i++) {
    pause, 1;
    write, format="\n----------\nProcessing %s\n", days(i);
    edb_file = mission_get("edb file", day=days(i));
    edb = soe_day_start = [];
    if(!is_void(edb_file) && file_exists(edb_file)) {
      f = edb_open(edb_file, verbose=0);
      edb = (f.records);
      close, f;
      w = where(edb.seconds > time2soe([2000,0,0,0,0,0]));
      if(!numberof(w)) {
        edb = [];
      } else {
        tmp = soe2time(edb(w(1)).seconds);
        tmp(3:) = 0;
        soe_day_start = time2soe(tmp);
      }
      determine_gps_time_correction, edb_file, verbose=1;
    }
    missiondata_load, "pnav", day=days(i), noerror=1;
    missiondata_load, "ins", day=days(i), noerror=1;
    fn = file_join(outdir, days(i) + ".kml");
    if(!is_void(pnav) && !is_void(edb) && !is_void(soe_day_start)) {
      newfiles = kml_pnav(pnav, fn, name=days(i), edb=edb,
        soe_day_start=soe_day_start, ins_header=iex_head, webdest=webdest);
      grow, masters, newfiles(1);
      grow, files, newfiles(2:);
      newfiles = [];
      grow, links, kml_NetworkLink(
        kml_Link(href=file_relative(outdir, fn)),
        name=days(i)
      );
      if(!is_void(webdest))
        grow, weblinks, kml_NetworkLink(
          kml_Link(href=webdest + file_relative(outdir, fn)),
          name=days(i)
        );
    } else {
      write, "No data, skipped!";
    }
  }

  write, format="\n----------\nProcessing %s\n", name;

  if(is_void(links)) {
    write, "No kmls created, skipped!";
    return [];
  }

  outname = file_join(outdir, name + ".kml");
  kml_save, outname, links;
  kmz = file_rootname(outname) + ".kmz";
  kmz_create, kmz, outname, masters, files;

  if(!is_void(webdest))
    kml_save, file_rootname(outname) + "-web.kml", weblinks;

  if(!keepkml) {
    for(i = 1; i <= numberof(files); i++)
      remove, files(i);
    for(i = 1; i <= numberof(masters); i++)
      remove, masters(i);
    remove, outname;
  }

  return [&[outname], &masters, &files];
}

func kml_pnav(input, output, name=, edb=, soe_day_start=, ins_header=,
webdest=, keepkml=) {
/* DOCUMENT kml_pnav, input, output, name=, edb=, soe_day_start=, ins_header,
  keepkml=, webdest=
  Creates KML/KMZ files for a PNAV file.

  Parameters:
    input: The pnav to use. This can be the path to the pnav data to load, or
      it can be a loaded array of PNAV data.
    output: The desired output filename. This should be something.kml or
      something.kmz. (Both a .kml and a .kmz will be created, so either
      extension is fine here.)

  Options:
    name= The name to use for the flightline, for descriptive purposes.
      Defaults to the output file's name, without leading directories and
      without extension.
    edb= An array of edb data to use.
    soe_day_start= The soe_day_start value associated with that edb data.
    ins_header= The header data from the INS file.
    keepkml= Specifies whether the .kml files should be kept after the .kmz
      has been created.
        keepkml=0      default when output ends with .kmz
        keepkml=1      default when output ends with .kml
    webdest= The destination directory on the web. Do not use directly; this
      is used by batch_mission_kml. This option also forces keepkml=1.

  Returns a array of the .kml files created. The first item is the main .kml,
  which was used a doc.kml inside the created .kmz.
*/
  local fn;
  default, name, file_rootname(file_tail(output));
  default, keepkml, (file_extension(output) == ".kml");
  if(!is_void(webdest))
    keepkml = 1;
  pnav = typeof(input) == "string" ? load_pnav(fn=input, verbose=0) : input;

  if(file_extension(output) == ".kmz")
    output = file_rootname(output) + ".kml";

  region = kml_pnav_region(pnav);
  outdir = file_dirname(output);
  mkdirp, outdir;

  // FLIGHTLINE
  color = kml_randomcolor();
  width = sqrt(region.area);

  maxdists = [5, 25, 125, 625, 10000];
  files = links = weblinks = [];
  for(i = 1; i < numberof(maxdists); i++) {
    // Estimate the pixel range that this maxdist is appropriate for
    lod_max = long(width/maxdists(i));
    lod_min = long(width/maxdists(i+1));

    if(is_void(files))
      lod_max = -1;
    if(lod_max > -1 && lod_max <= 16)
      continue;

    if(lod_min <= 16 || i + 1 == numberof(maxdists))
      lod_min = 4;

    fn = swrite(format="%s_l%d.kml", file_rootname(output), maxdists(i));
    kml_save, fn, kml_pnav_flightline(pnav, maxdist=maxdists(i), color=color);
    grow, files, &strchar(fn);
    reg = kml_Region(
      north=region.north, south=region.south,
      east=region.east, west=region.west,
      minLodPixels=lod_min, maxLodPixels=lod_max
    );
    grow, links, &strchar(kml_NetworkLink(
      kml_Link(href=file_relative(outdir, fn)),
      reg
    ));
    if(!is_void(webdest))
      grow, weblinks, &strchar(kml_NetworkLink(
        kml_Link(href=webdest + file_relative(outdir, fn)),
        reg
      ));
  }

  links = strchar(merge_pointers(links));
  if(!is_void(weblinks))
    weblinks = strchar(merge_pointers(weblinks));

  flightline = kml_Folder(
    links,
    kml_Style(kml_ListStyle(listItemType="checkHideChildren")),
    name="Flightline"
  );

  if(!is_void(webdest))
    webflightline = kml_Folder(
      weblinks,
      kml_Style(kml_ListStyle(listItemType="checkHideChildren")),
      name="Flightline"
    );

  links = weblinks = [];

  // Elevated Flightline
  fn = file_rootname(output) + "_elev.kml";
  kml_save, fn, kml_pnav_flightline(pnav, maxdist=10, color=color, alt=1);
  grow, files, &strchar(fn);
  grow, links, &strchar(kml_NetworkLink(
    kml_Link(href=file_relative(outdir, fn)),
    name="Elevated flightline", visibility=0
  ));
  if(!is_void(webdest))
    grow, weblinks, &strchar(kml_NetworkLink(
      kml_Link(href=webdest + file_relative(outdir, fn)),
      name="Elevated flightline", visibility=0
    ));

  // TIMESTAMPS
  local timestampstyle, timestampfolder;
  assign, kml_pnav_timestamps(pnav), timestampstyle, timestampfolder;
  fn = file_rootname(output) + "_time.kml";
  kml_save, fn, *timestampstyle, *timestampfolder;
  grow, files, &strchar(fn);
  grow, links, &strchar(kml_NetworkLink(
    kml_Link(href=file_relative(outdir, fn)),
    name="Timestamps", visibility=0
  ));
  if(!is_void(webdest))
    grow, weblinks, &strchar(kml_NetworkLink(
      kml_Link(href=webdest + file_relative(outdir, fn)),
      name="Timestamps", visibility=0
    ));

  // BASESTATIONS
  if(!is_void(ins_header)) {
    local stationstyle, stationfolder;
    assign, kml_ins_basestations(ins_header), stationstyle, stationfolder;
    if(!is_void(stationfolder)) {
      fn = file_rootname(output) + "_base.kml";
      kml_save, fn, *stationstyle, *stationfolder;
      grow, files, &strchar(fn);
      grow, links, &strchar(kml_NetworkLink(
        kml_Link(href=file_relative(outdir, fn)),
        name="Basestations", visibility=0
      ));
      if(!is_void(webdest))
        grow, weblinks, &strchar(kml_NetworkLink(
          kml_Link(href=webdest + file_relative(outdir, fn)),
          name="Basestations", visibility=0
        ));
    }
  }

  // PDOP
  local pdopstyle, pdopfolder;
  assign, kml_pnav_pdop(pnav), pdopstyle, pdopfolder;
  fn = file_rootname(output) + "_pdop.kml";
  kml_save, fn, *pdopstyle, *pdopfolder;
  grow, files, &strchar(fn);
  grow, links, &strchar(kml_NetworkLink(
    kml_Link(href=file_relative(outdir, fn)),
    name="PDOP", visibility=0
  ));
  if(!is_void(webdest))
    grow, weblinks, &strchar(kml_NetworkLink(
      kml_Link(href=webdest + file_relative(outdir, fn)),
      name="PDOP", visibility=0
    ));

  // EDB
  local edbstyle, edbfolder;
  edbstyle = edbfolder = &[string(0)];
  if(!is_void(edb) && !is_void(soe_day_start)) {
    assign, kml_pnav_edb(pnav, edb, soe_day_start), edbstyle, edbfolder;
    fn = file_rootname(output) + "_edb.kml";
    kml_save, fn, *edbstyle, *edbfolder;
    grow, files, &strchar(fn);
    grow, links, &strchar(kml_NetworkLink(
      kml_Link(href=file_relative(outdir, fn)),
      name="Lidar coverage", visibility=0
    ));
    if(!is_void(webdest))
      grow, weblinks, &strchar(kml_NetworkLink(
        kml_Link(href=webdest + file_relative(outdir, fn)),
        name="Lidar coverage", visibility=0
      ));
  }

  links = strchar(merge_pointers(links));
  files = strchar(merge_pointers(files));
  if(!is_void(weblinks))
    weblinks = strchar(merge_pointers(weblinks));

  supplemental = kml_Folder(
    kml_Style(kml_ListStyle(listItemType="checkOffOnly")),
    links,
    name="Supplemental layers",
    Open=0,
    visibility=0
  );
  kml_save, output, flightline, supplemental, name=name;

  kmz = file_rootname(output) + ".kmz";
  kmz_create, kmz, output, files;

  if(!is_void(webdest)) {
    supplemental = kml_Folder(
      kml_Style(kml_ListStyle(listItemType="checkOffOnly")),
      weblinks,
      name="Supplemental layers",
      Open=0,
      visibility=0
    );
    kml_save, file_rootname(output)+"-web.kml", webflightline, supplemental,
      name=name;
  }

  if(!keepkml) {
    for(i = 1; i <= numberof(files); i++)
      remove, files(i);
    remove, output;
  }

  return grow(output, files);
}

// PNAV KML COMPONENTS

func kml_pnav_flightline(pnav, color=, maxdist=, alt=) {
/* DOCUMENT placemark = kml_pnav_flightline(pnav, color=)
  Generates KLM data for the pnav flightline.
  Return value is a string.
  color= defaults to a random color
  alt= specifies whether to include altitude, default is 0
*/
  if(is_void(color))
    color = kml_randomcolor();
  return kml_Placemark(
    kml_Style(kml_LineStyle(color=color, width=2)),
    kml_pnav_LineString(pnav, maxdist=maxdist, alt=alt),
    name="Flightline"
  );
}

func kml_pnav_region(pnav) {
/* DOCUMENT region = kml_pnav_region(pnav)
  Returns a Yeti hash with five keys:
    region.north \
    region.south  \ The bounding box for this
    region.east   / pnav data, in lat/lon.
    region.west  /
    region.area     The area of the bounding box, in meters.
*/
  north = pnav.lat(max);
  south = pnav.lat(min);
  east = pnav.lon(max);
  west = pnav.lon(min);
  u = fll2utm([north, north, south, south], [east, west, east, west]);
  z = long(median(u(3,)));
  if(anyof(u(3,) != z))
    u = fll2utm([north, north, south, south], [east, west, east, west],
      force_zone=z);
  area = (u(1,max) - u(1,min)) * (u(2,max) - u(2,min));
  return h_new(north=north, east=east, south=south, west=west, area=area);
}

func kml_pnav_timestamps(pnav, interval=, visibility=) {
/* DOCUMENT [&style, &folder] = kml_pnav_timestamps(pnav, interval=, visibility=)
  Generates KML data for the timestamps in a pnav.
  Return value is an array of pointers.
  Interval defaults to 900 seconds (15 minutes).
*/
  default, interval, 900.;
  spots = grow(1, where(floor(pnav.sod / interval)(dif) == 1) + 1, numberof(pnav));
  spots = pnav(set_remove_duplicates(spots));
  hms = sod2hms(spots.sod);
  msg = swrite(format="%s: %02d:%02d:%02d", name, hms(,1), hms(,2), hms(,3));

  style = kml_Style(
    kml_IconStyle(
      href="http://maps.google.com/mapfiles/kml/shapes/placemark_circle.png"
    ),
    id="timestamp"
  );

  timestamps = array(string, numberof(spots));
  for(i = 1; i <= numberof(spots); i++) {
    timestamps(i) = kml_Placemark(
      kml_Point(spots(i).lon, spots(i).lat),
      name=msg(i), styleUrl="#timestamp", visibility=visibility
    );
  }

  return [&style, &timestamps];
}

func kml_ins_basestations(header, visibility=) {
/* DOCUMENT [&style, &folder] = kml_ins_basestations(header, visibility=)
  Generates KML data for the basestations.
  Return value is an array of pointers.
*/
  data = parse_iex_basestations(header);
  if(is_void(data))
    return [];
  keys = h_keys(data);
  if(!numberof(keys))
    return [];

  style = [
    kml_Style(
      kml_IconStyle(
        href="http://maps.google.com/mapfiles/kml/shapes/donut.png"
      ),
      id="base_on"
    ),
    kml_Style(
      kml_IconStyle(
        href="http://maps.google.com/mapfiles/kml/shapes/forbidden.png"
      ),
      id="base_off"
    )
  ];

  stations = array(string, numberof(keys));
  for(i = 1; i <= numberof(stations); i++) {
    cur = data(keys(i));
    curstyle = cur.enabled ? "#base_on" : "#base_off";
    desc = strjoin(strsplit(cur.desc, "\n"), "<br />");
    desc = "<![CDATA[<tt><pre>" + desc + "</pre></tt>]]>";
    stations(i) = kml_Placemark(
      kml_Point(cur.lon, cur.lat),
      name=cur.name, styleUrl=curstyle, description=desc,
      visibility=visibility
    );
  }

  return [&style, &stations];
}

func kml_pnav_pdop(pnav, maxdist=, visibility=) {
/* DOCUMENT [&styles, &folder] = kml_pnav_pdop(pnav, maxdist=)
  Generates KML data for the pdops in a pnav.
  Return value is an array of pointers.
*/
  // Threshold values and settings
  conf = _lst(
    h_new(low=0.0, high=2.0, name="pdop &lt; 2",
      width=1, color=kml_color(99, 200, 57)),
    h_new(low=2.0, high=3.5, name="2 &lt;= pdop &lt; 3.5",
      width=2, color=kml_color(65, 143, 145)),
    h_new(low=3.5, high=5.0, name="3.5 &lt;= pdop &lt; 5",
      width=4, color=kml_color(222, 190, 61)),
    h_new(low=5.0, high=1e100, name="5 &lt;= pdop",
      width=5, color=kml_color(255, 0, 0))
  );

  count = _len(conf);

  // Condense pdops into discrete values
  pdopi = array(short, numberof(pnav));
  for(i = 1; i <= count; i++) {
    cur = _car(conf, i);
    // Find all points that match the current range
    match = cur.low <= pnav.pdop & pnav.pdop < cur.high;

    // No matches? Nothing to do
    if(noneof(match))
      continue;

    pdopi(where(match)) = i;
  }

  // Calculate point-to-point distances
  n = e = [];
  fll2utm, pnav.lat, pnav.lon, n, e;
  dist = ppdist([e(:-1), n(:-1)], [e(2:), n(2:)], tp=1)(cum);
  n = e = [];

  // Smooth
  pdopi = level_short_dips(pdopi, dist=dist, thresh=100.0);

  folders = styles = array(string, count);
  for(i = 1; i <= count; i++) {
    cur = _car(conf, i);

    // Find all points that match the current range
    match = pdopi == i;

    // No matches? Nothing to do
    if(noneof(match))
      continue;

    // Calculate our range start/stop indices
    r0 = r1 = [];
    if(allof(match)) {
      // If everything matches, then it's very simple...
      r0 = [1];
      r1 = [numberof(pnav)];
    } else {
      // Pick out the start and stop of each range
      r0 = where(match(dif) == 1);
      r1 = where(match(dif) == -1);

      // Sanitize r0 and r1
      if(!numberof(r0)) r0 = [];
      if(!numberof(r1)) r1 = [];

      // Special case: if the first element is part of the range
      if(match(1))
        r0 = grow(1, r0);

      // Special case: if the last element is part of the range
      if(match(0))
        grow, r1, numberof(pnav);
    }

    // Add style information
    styles(i) = kml_Style(
      kml_LineStyle(width=cur.width, color=cur.color),
      id=swrite(format="pdop%d", i)
    );

    // Generate placemarks for each range
    segments = array(string, numberof(r0));
    for(j = 1; j <= numberof(r0); j++) {
      pnavseg = pnav(r0(j):r1(j));
      hms0 = sod2hms(pnavseg(1).sod);
      hms1 = sod2hms(pnavseg(0).sod);
      segname = swrite(format="%02d:%02d:%02d - %02d:%02d:%02d",
        hms0(1), hms0(2), hms0(3), hms1(1), hms1(2), hms1(3));
      segments(j) = kml_Placemark(
        kml_pnav_LineString(pnavseg, maxdist=maxdist),
        name=segname, visibility=visibility,
        styleUrl=swrite(format="#pdop%d", i)
      );
    }

    // Put placemarks in a folder
    folders(i) = kml_Folder(
      segments,
      name=cur.name, visibility=visibility
    );
  }

  // Eliminate anything we skipped
  folders = folders(where(folders));
  styles = styles(where(styles));

  return [&styles, &folders];
}

func kml_pnav_edb(pnav, edb, soe_day_start, maxdist=, visibility=) {
/* DOCUMENT [&style, &folder] = kml_pnav_edb(pnav, edb, soe_day_start, maxdist=)
  Generates KML data for the edb coverage on the given pnav.
  Return value is an array of pointers.
*/
  sod_edb = edb.seconds - soe_day_start;

  segw = where(sod_edb(dif) > 300);
  if(numberof(segw)) {
    segw = grow(0, segw, numberof(sod_edb));
  } else {
    segw = [0, numberof(sod_edb)];
  }
  lines = array(string, numberof(segw) - 1);
  for(i = 1; i < numberof(segw); i++) {
    seg_sod = sod_edb(segw(i)+1:segw(i+1));
    edb_min = seg_sod(min);
    edb_max = seg_sod(max);
    w = where(edb_min <= pnav.sod & pnav.sod <= edb_max);
    if(!numberof(w))
      continue;
    pnavseg = pnav(w);
    hms0 = sod2hms(pnavseg(1).sod);
    hms1 = sod2hms(pnavseg(0).sod);
    segname = swrite(format="%02d:%02d:%02d - %02d:%02d:%02d",
      hms0(1), hms0(2), hms0(3), hms1(1), hms1(2), hms1(3));
    lines(i) = kml_Placemark(
      kml_pnav_LineString(pnavseg, maxdist=maxdist),
      name=segname, visibility=visibility, styleUrl="#edb"
    );
  }
  lines = lines(where(lines));

  style = kml_Style(
    kml_LineStyle(width=6, color=kml_color(102,255,0)),
    id="edb"
  );

  return [&style, &lines];
}

func kml_pnav_LineString(pnav, maxdist=, alt=) {
/* DOCUMENT kml_pnav_LineString(pnav, maxdist=)
  Given an array of PNAV data, this will return a <LineString> element
  representing its trajectory. Option maxdist= is passed to downsample_line
  and defaults to 10.
*/
  default, maxdist, 10;
  default, alt, 0;
  utm = fll2utm(pnav.lat, pnav.lon);
  idx = downsample_line(utm(2,), utm(1,), maxdist=maxdist, idx=1);
  if(alt)
    return kml_LineString(pnav(idx).lon, pnav(idx).lat, pnav(idx).alt,
      altitudeMode="absolute");
  else
    return kml_LineString(pnav(idx).lon, pnav(idx).lat, tessellate=1);
}
