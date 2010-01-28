/* vim: set tabstop=3 softtabstop=3 shiftwidth=3 autoindent shiftround expandtab: */
require, "eaarl.i";
require, "photo.i";

// OLD STYLE KML FUNCTIONS

func kml_write_line(dest, lat, lon, elv, name=, description=, visibility=,
   Open=, linecolor=, linewidth=, segment=) {
/* DOCUMENT kml_write_line, dest, lat, lon, elv, name=, description=,
   visibility=, Open=, linecolor=, linewidth=, segment=

   Creates a kml file as dest for a line defined by lat and lon, which should
   be arrays of floats or doubles.

   All options except segment should be strings.

   Parameters:
      dest: Destination file for created KML.
      lat: Array of latitude coordinates.
      lon: Array of longitude coordinates.
      elv: Array of elevation values, in meters.
   Options:
      name= A name for the linestring. Defaults to dest's filename.
      description= A description for the linestring. Defaults to name's value.
      visibility= Whether or not the line is visible when loaded. Default is 1.
      Open= Whether or not the folder is open when loaded. Default is 0.
      linecolor= The color of the line, in AABBGGRR format
         (alpha-blue-green-red).  Default is ff00ffff.
      linewidth= The width of the line. Default is 1.
      segment= An array that matches the dimensions of lat and lon. This should
         be an array of values that partitions the coordinates into separate
         lines. All points one line might have the value 1 and all points in
         another might have the value 2, for instance.

   Original David Nagle 2008-03-26
*/

   default, name, file_tail(dest);
   default, description, name;
   default, visibility, "1";
   default, Open, "0";
   default, linecolor, "ff00ff00";
   default, linewidth, "1";
   default, segment, array(0, numberof(lat));

   segvals = set_remove_duplicates(segment);

   lines = [];
   for(i = 1; i <= numberof(segvals); i++) {
      idx = where(segment==segvals(i));
      grow, lines, kml_LineString(lon(idx), lat(idx), elv(idx),
         altitudeMode="absolute");
   }

   kml_save, dest, kml_Placemark(
      kml_Style(kml_LineStyle(color=linecolor, width=linewidth)),
      kml_MultiGeometry(lines),
      name=name, Open=Open, visibility=visibility, description=description
   );
}

func ll_to_kml(lat, lon, elv, output, name=, description=, linecolor=,
   sample_thresh=, segment_thresh=) {
/* DOCUMENT ll_to_kml, lat, lon, elv, kml_file, name=, description=,
      linecolor=, sample_thresh=, segment_thresh=
   Creates kml_file for the given lat/lon/elv info.

   Parameters:
      lat, lon, elv: The XYZ data to generate the KML with. Elv should be in
         meters.
      output: Path/filename to a destination .kml file.

   Options:
      name= A name for the kml linestring. Defaults to the output filename.
      description= A description for the kml linestring. Defaults to name's
         value.
      sample_thresh= The distance threshold to use to downsample the line.
      segment_threshold= The distance threshold to use to segment a line.
      linecolor= The color of the line, in AABBGGRR format
         (alpha-blue-green-red).

   Original David Nagle 2008-03-26
*/
   kml_downsample, lat, lon, elv, threshold=sample_thresh;
   seg = kml_segment(lat, lon, threshold=segment_thresh);
   kml_write_line, output, lat, lon, elv, segment=seg, name=name,
      description=description, linecolor=linecolor;
}

func kml_downsample(&lat, &lon, &elv, threshold=) {
/* DOCUMENT kml_downsample, lat, lon, elv, threshold=
   Downsamples lat/lon/elv coordinates by distance to reduce the size of a KML
   file. For each pair of points that are less than threshold (default: 100m)
   distance from each other, the first of the pair is removed. This repeats
   until all point pairs are at least threshold distance apart.

   Lat, lon, and elv are updated in place. Nothing is returned.

   Original David Nagle 2008-03-26
*/
   default, threshold, 5.;
   utm = fll2utm(lat, lon);
   n = utm(1,);
   e = utm(2,);

   idx = downsample_line(e, n, maxdist=threshold, idx=1);

   lat = lat(idx);
   lon = lon(idx);
   elv = elv(idx);
}

func kml_segment(lat, lon, threshold=) {
/* DOCUMENT kml_segment(lat, lon, threshold=)
   Returns an array that can be used by kml_write_line to segment the points
   in lat/lon. The points will be segmented wherever the distance is greater
   than the threshold distance, in meters (default is 1000m).

   Original David Nagle 2008-03-26
*/
   default, threshold, 1000;
   seg = array(0, numberof(lat));
   if(numberof(n) < 2) return seg;

   utm = fll2utm(lat, lon);
   dist = sqrt(utm(1,)(dif)^2 + utm(2,)(dif)^2);

   w = where(dist > threshold);
   if(numberof(w)) {
      w = grow(0, w, numberof(lat));
      for(i=2; i <= numberof(w); i++) {
         seg(w(i-1)+1:w(i)) = i;
      }
   }

   return seg;
}

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
      write, format="\n----------\nProcessing %s\n", days(i);
      edb_file = mission_get("edb file", day=days(i));
      edb = soe_day_start = [];
      if(!is_void(edb_file)) {
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
      fn = file_join(outdir, days(i) + ".kml");
      if(!is_void(pnav) && !is_void(edb) && !is_void(soe_day_start)) {
         newfiles = kml_pnav(pnav, fn, name=days(i), edb=edb,
            soe_day_start=soe_day_start, webdest=webdest);
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

func kml_pnav(input, output, name=, edb=, soe_day_start=, webdest=) {
/* DOCUMENT kml_pnav, input, output, name=, edb=, soe_day_start=
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
      webdest= The destination directory on the web. Do not use directly; this
         is used by batch_mission_kml.

   Returns a array of the .kml files created. The first item is the main .kml,
   which was used a doc.kml inside the created .kmz.
*/
   local fn;
   default, name, file_rootname(file_tail(output));
   pnav = typeof(input) == "string" ? load_pnav(fn=input, verbose=0) : input;

   if(file_extension(output) == ".kmz")
      output = file_rootname(output) + ".kml";

   region = kml_pnav_region(pnav);
   outdir = file_dirname(output);

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
      grow, files, fn;
      reg = kml_Region(
         north=region.north, south=region.south,
         east=region.east, west=region.west,
         minLodPixels=lod_min, maxLodPixels=lod_max
      );
      grow, links, kml_NetworkLink(
         kml_Link(href=file_relative(outdir, fn)),
         reg
      );
      if(!is_void(webdest))
         grow, weblinks, kml_NetworkLink(
            kml_Link(href=webdest + file_relative(outdir, fn)),
            reg
         );
   }

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
   grow, files, fn;
   grow, links, kml_NetworkLink(
      kml_Link(href=file_relative(outdir, fn)),
      name="Elevated flightline", visibility=0
   );
   if(!is_void(webdest))
      grow, weblinks, kml_NetworkLink(
         kml_Link(href=webdest + file_relative(outdir, fn)),
         name="Elevated flightline", visibility=0
      );

   // TIMESTAMPS
   local timestampstyle, timestampfolder;
   assign, kml_pnav_timestamps(pnav), timestampstyle, timestampfolder;
   fn = file_rootname(output) + "_time.kml";
   kml_save, fn, *timestampstyle, *timestampfolder;
   grow, files, fn;
   grow, links, kml_NetworkLink(
      kml_Link(href=file_relative(outdir, fn)),
      name="Timestamps", visibility=0
   );
   if(!is_void(webdest))
      grow, weblinks, kml_NetworkLink(
         kml_Link(href=webdest + file_relative(outdir, fn)),
         name="Timestamps", visibility=0
      );

   // PDOP
   local pdopstyle, pdopfolder;
   assign, kml_pnav_pdop(pnav), pdopstyle, pdopfolder;
   fn = file_rootname(output) + "_pdop.kml";
   kml_save, fn, *pdopstyle, *pdopfolder;
   grow, files, fn;
   grow, links, kml_NetworkLink(
      kml_Link(href=file_relative(outdir, fn)),
      name="PDOP", visibility=0
   );
   if(!is_void(webdest))
      grow, weblinks, kml_NetworkLink(
         kml_Link(href=webdest + file_relative(outdir, fn)),
         name="PDOP", visibility=0
      );

   // EDB
   local edbstyle, edbfolder;
   edbstyle = edbfolder = &[string(0)];
   if(!is_void(edb) && !is_void(soe_day_start)) {
      assign, kml_pnav_edb(pnav, edb, soe_day_start), edbstyle, edbfolder;
      fn = file_rootname(output) + "_edb.kml";
      kml_save, fn, *edbstyle, *edbfolder;
      grow, files, fn;
      grow, links, kml_NetworkLink(
         kml_Link(href=file_relative(outdir, fn)),
         name="Lidar coverage", visibility=0
      );
      if(!is_void(webdest))
         grow, weblinks, kml_NetworkLink(
            kml_Link(href=webdest + file_relative(outdir, fn)),
            name="Lidar coverage", visibility=0
         );
   }

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
/* DOCUMENT [&style, &folder] = kml_pnav_timestamps(pnav, interval=)
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

func kml_pnav_pdop(pnav, maxdist=, visibility=) {
/* DOCUMENT [&styles, &folder] = kml_pnav_pdop(pnav, maxdist=)
   Generates KML data for the pdops in a pnav.
   Return value is an array of pointers.
*/
   // Threshold values and settings
   conf = _lst(
      h_new(low=0.0, high=2.0, name="pdop &lt; 2",
         width=1, color=kml_color(0, 0, 255)),
      h_new(low=2.0, high=3.0, name="2 &lt;= pdop &lt; 3",
         width=2, color=kml_color(0, 255, 255)),
      h_new(low=3.0, high=4.0, name="3 &lt;= pdop &lt; 4",
         width=3, color=kml_color(0, 255, 0)),
      h_new(low=4.0, high=5.0, name="4 &lt;= pdop &lt; 5",
         width=4, color=kml_color(255, 255, 0)),
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

// GENERAL KML UTILITY

func kmz_create(dest, files, ..) {
/* DOCUMENT kmz_create, dest, mainfile, file, file, file ...
   Creates a kmz at dest. mainfile is used as doc.kml, any additional files are
   also included. Arguments may be scalar or array.
*/
   while(more_args())
      grow, files, next_arg();

   rmvdoc = 0;

   if(file_tail(files(1)) != "doc.kml") {
      dockml = file_join(file_dirname(files(1)), "doc.kml");
      if(file_exists(dockml))
         error, "doc.kml already exists!";
      file_copy, files(1), dockml;
      files(1) = dockml;
      rmvdoc = 1;
   }

   cmd = [];
   exe = popen_rdfile("which zip");
   if(numberof(exe)) {
      cmd = swrite(format="'%s' -X -9 '%%s' '%%s'", exe(1));
   } else {
      error, "Unable to zip command.";
   }

   files = file_relative(file_dirname(dest), files);

   if(file_exists(dest))
      remove, dest;

   cwd = get_cwd();
   cd, file_dirname(dest);
   dest = file_tail(dest);


   for(i = 1; i <= numberof(files); i++)
      system, swrite(format=cmd, dest, files(i));

   if(rmvdoc)
      remove, files(1);

   cd, cwd;
}

func kml_save(fn, items, .., id=, name=, visibility=, Open=, description=,
styleUrl=) {
   while(more_args())
      grow, items, next_arg();
   write, open(fn, "w"), format="%s\n", kml_Document(items, id=id, name=name,
      visibility=visibility, Open=Open, description=description,
      styleUrl=styleUrl);
}

__kml_randomcolor = random();
func kml_randomcolor(void) {
   extern __kml_randomcolor;
   __kml_randomcolor += 0.195 + random()/1000.;
   __kml_randomcolor %= 1.;
   rgb = hsl2rgb(__kml_randomcolor, random()*.2+.8, random()*.1+.45);
   return kml_color(rgb(1), rgb(2), rgb(3));
}


func kml_color(r, g, b, a) {
/* DOCUMENT kml_color(r, g, b, a)
   Given a color defined by r, g, b, and optionally a (all numbers), this will
   return the properly formatted colorcode per the KML spec.

   If alpha is omitted, it defaults to fully opaque (255).
*/
   default, a, array(short(255), dimsof(r));
   if(anyof(0 < r & r < 1))
      r = short(r * 255);
   if(anyof(0 < g & g < 1))
      g = short(g * 255);
   if(anyof(0 < b & b < 1))
      b = short(b * 255);
   if(anyof(0 < a & a < 1))
      a = short(a * 255);
   return swrite(format="%02x%02x%02x%02x", short(a), short(b), short(g), short(r));
}

// GENERIC KML COMPONENT FUNCTIONS

func kml_Document(items, .., id=, name=, visibility=, Open=, description=,
styleUrl=) {
   while(more_args())
      grow, items, next_arg();

   Document = kml_Feature("Document", items, id=id, description=description,
      name=name, visibility=visibility, Open=Open, styleUrl=styleUrl);

   return swrite(format="\
<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n\
<kml xmlns=\"http://earth.google.com/kml/2.2\">\n\
%s\n\
</kml>", Document);
}

func kml_Style(items, .., id=) {
   while(more_args())
      grow, items, next_arg();
   return kml_element("Style", items, id=id);
}

func kml_IconStyle(void, id=, color=, colorMode=, scale=, heading=, href=, x=,
y=, xunits=, yunits=) {
   elems = [];
   grow, elems, kml_element("color", color);
   grow, elems, kml_element("colorMode", colorMode);
   grow, elems, kml_element("scale", scale);
   grow, elems, kml_element("heading", heading);
   grow, elems, kml_element("Icon", kml_element("href", href));

   hotSpot = "";
   if(!is_void(x))
      hotSpot += swrite(format=" x=\"%s\"", x);
   if(!is_void(y))
      hotSpot += swrite(format=" y=\"%s\"", y);
   if(!is_void(xunits))
      hotSpot += swrite(format=" xunits=\"%s\"", xunits);
   if(!is_void(yunits))
      hotSpot += swrite(format=" yunits=\"%s\"", yunits);
   if(strlen(hotSpot) > 0)
      grow, elems, swrite(format="<hotSpot%s />\n", hotSpot);

   return kml_element("IconStyle", elems, id=id);
}

func kml_LineStyle(void, id=, color=, colorMode=, width=) {
   elems = [];
   grow, elems, kml_element("color", color);
   grow, elems, kml_element("colorMode", colorMode);
   grow, elems, kml_element("width", width);
   return kml_element("LineStyle", elems, id=id);
}

func kml_ListStyle(void, id=, listItemType=, bgColor=, state=, href=) {
   elems = [];
   grow, elems, kml_element("listItemType", listItemType);
   grow, elems, kml_element("bgColor", bgColor);

   iconelems = [];
   grow, iconelems, kml_element("state", state);
   grow, iconelems, kml_element("href", href);
   grow, elems, kml_element("ItemIcon", iconelems);

   return kml_element("ListStyle", elems, id=id);
}

func kml_PolyStyle(void, id=, color=, colorMode=, fill=, outline=) {
   elems = [];
   grow, elems, kml_element("color", color);
   grow, elems, kml_element("colorMode", colorMode);
   grow, elems, kml_element("fill", fill);
   grow, elems, kml_element("outline", outline);
   return kml_element("PolyStyle", elems, id=id);
}

func kml_Folder(items, .., id=, name=, visibility=, Open=, description=,
styleUrl=) {
   while(more_args())
      grow, items, next_arg();
   return kml_Feature("Folder", items, id=id, description=description,
      name=name, visibility=visibility, Open=Open, styleUrl=styleUrl);
}

func kml_Placemark(items, .., id=, name=, description=, visibility=, Open=,
styleUrl=) {
   while(more_args())
      grow, items, next_arg();
   return kml_Feature("Placemark", items, id=id, description=description,
      name=name, visibility=visibility, Open=Open, styleUrl=styleUrl);
}

func kml_NetworkLink(items, .., id=, name=, description=, visibility=, Open=,
styleUrl=) {
   while(more_args())
      grow, items, next_arg();
   return kml_Feature("NetworkLink", items, id=id, description=description,
      name=name, visibility=visibility, Open=Open, styleUrl=styleUrl);
}

func kml_Feature(type, items, .., id=, name=, visibility=, Open=, description=,
styleUrl=) {
   while(more_args())
      grow, items, next_arg();
   elems = [];
   grow, elems, kml_element("name", name);
   grow, elems, kml_element("visibility", visibility);
   grow, elems, kml_element("open", Open);
   grow, elems, kml_element("description", description);
   grow, elems, kml_element("styleUrl", styleUrl);
   return kml_element(type, elems, items, id=id);
}

func kml_MultiGeometry(items, .., id=) {
   while(more_args())
      grow, items, next_arg();
   return kml_element("MultiGeometry", items, id=id);
}

func kml_LineString(lon, lat, alt, id=, extrude=, tessellate=, altitudeMode=) {
   elems = [];
   grow, elems, kml_element("extrude", extrude);
   grow, elems, kml_element("tessellate", tessellate);
   grow, elems, kml_element("altitudeMode", altitudeMode);
   grow, elems, kml_coordinates(lon, lat, alt);
   return kml_element("LineString", elems, id=id);
}

func kml_Point(lon, lat, alt, id=, extrude=, altitudeMode=) {
   elems = [];
   grow, elems, kml_element("extrude", extrude);
   grow, elems, kml_element("altitudeMode", altitudeMode);
   grow, elems, kml_coordinates(lon, lat, alt);
   return kml_element("Point", elems, id=id);
}

func kml_coordinates(lon, lat, alt) {
   if(is_void(alt))
      coordinates = swrite(format="%.5f,%.5f", lon, lat);
   else
      coordinates = swrite(format="%.5f,%.5f,%.2f", lon, lat, alt);
   return kml_element("coordinates", strwrap(strjoin(coordinates, " ")));
}

func kml_Link(items, .., id=, href=) {
   while(more_args())
      grow, items, next_arg();
   return kml_element("Link", kml_element("href", href), items, id=id);
}

func kml_Region(items, .., id=, north=, south=, east=, west=, minAltitude=,
maxAltitude=, altitudeMode=, minLodPixels=, maxLodPixels=, minFadeExtent=,
maxFadeExtent=) {
   elems = [];
   grow, elems, kml_element("north", north);
   grow, elems, kml_element("south", south);
   grow, elems, kml_element("east", east);
   grow, elems, kml_element("west", west);
   grow, elems, kml_element("minAltitude", minAltitude);
   grow, elems, kml_element("maxAltitude", maxAltitude);
   grow, elems, kml_element("altitudeMode", altitudeMode);
   LatLonAltBox = kml_element("LatLonAltBox", elems);

   elems = [];
   grow, elems, kml_element("minLodPixels", minLodPixels);
   grow, elems, kml_element("maxLodPixels", maxLodPixels);
   grow, elems, kml_element("minFadeExtent", minFadeExtent);
   grow, elems, kml_element("maxFadeExtent", maxFadeExtent);
   Lod = kml_element("Lod", elems);

   return kml_element("Region", LatLonAltBox, Lod, id=id);

}

func kml_element(name, items, .., id=) {
   while(more_args())
      grow, items, next_arg();

   if(is_void(items))
      return [];

   id = is_void(id) ? "" : swrite(format=" id=\"%s\"", id);

   if(numberof(items) == 1 && !is_string(items(1))) {
      items = items(1);
      if(is_integer(items))
         items = swrite(format="%d", items);
      if(is_real(items)) {
         len = 0;
         while(len < 6 && long(items * 10 ^ len)/(10. ^ len) != items)
            len++;
         fmt = swrite(format="%%.%df", len);
         items = swrite(format=fmt, items);
      }
      if(!is_string(items))
         items = swrite(items);
   }

   single = numberof(items) == 1;

   if(single)
      single = !strmatch(items(1), "\n");

   if(single)
      single = (strpart(items(1), 1:1) != "<");

   if(single)
      single = strlen(name) * 2 + strlen(id) + strlen(items(1)) <= 66;

   if(single) {
      items = items(1);
      fmt = "<%s%s>%s</%s>";
   } else {
      items = strindent(strjoin(items, "\n"), "  ");
      fmt = "<%s%s>\n%s\n</%s>";
   }

   return swrite(format=fmt, name, id, items, name);
}
