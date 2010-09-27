// vim: set ts=3 sts=3 sw=3 ai sr et:
require, "eaarl.i";

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

// CIR/JGW COMPONENTS

func kml_jgw_make_levels(dir, levels=, searchstr=, update=, fast=, quality=) {
/* DOCUMENT kml_jgw_make_levels, dir, levels=, searchstr=, update=, fast=,
   quality=

   Generates downsampled images for multiple view levels for a CIR dataset.
   Each level is half the width and half the height of the previous level.

   This ONLY generates the images. It must be run independently of the actual
   kml generation.

   Parameter:
      dir: The directory to find images in.

   Options:
      levels= The number of levels to generate.
            levels=7          Seven levels (default)
      searchstr= Search pattern to find images with.
            searchstr="*-cir.jpg"      Default
      update= Whether to skip existing images or not.
            update=0          Re-create existing images, overwriting
            update=1          Skip images that already exist (default)
      fast= Passed through to jpg_shrink.
      quality= Passed through to jpg_shrink.

   SEE ALSO: kml_jgw_make_levels_single, jpg_shrink
*/
   default, searchstr, "*-cir.jpg";
   files = find(dir, glob=searchstr);
   num = numberof(files);
   t0 = array(double, 3);
   timer, t0;
   tp = t0;
   for(i = 1; i <= num; i++) {
      kml_jgw_make_levels_single, files(i), levels=levels, update=update,
         fast=fast, quality=quality;
      timer_remaining, t0, i, num, tp, interval=15;
   }
   timer_finished, t0;
}

func kml_jgw_make_levels_single(jpg, levels=, update=, fast=, quality=) {
/* DOCUMENT kml_jgw_make_levels_single, jpg, levels=, update=, fast=, quality=
   Generates downsampled images for multiple view levels for a single jpg
   image. Each level is half the width and height of the previous level.
   Options are as documented in kml_jgw_make_levels. This is not normally run
   directly; most users will want to use kml_jgw_make_levels.
*/
   default, levels, 7;
   default, update, 1;
   reduces = 2^indgen(1:levels);
   ljpgs = file_rootname(jpg) + swrite(format="_d%d.jpg", indgen(levels));
   w = indgen(levels);
   if(update)
      w = where(!file_exists(ljpgs));
   if(numberof(w))
      jpg_shrink, jpg, ljpgs(w), reduces(w), fast=fast, quality=quality;
}

func kml_jgw_tree(dir, ofn, root=, name=, searchstr=) {
/* DOCUMENT kml_jgw_tree, dir, ofn, root=, name=, searchstr=
   Generates a KML product for a directory tree of CIR imagery. All existing
   CIR kml files in the given path will be located. They will be organized into
   a single master KML file that loads all of them.

   This approach is deprecated as it demands a lot of overhead, since all of
   the individual kml files must immediately be loaded. Consider using
   kml_jgw_build_product instead, as it consolidates everything into a single
   KML file without the need for referring to external kml files.

   Parameters:
      dir: Path to the images
      ofn: Path and filename for the output kml file.
   Options:
      root= If provided, this is a path to prefix to the links for purposes of
         putting on the web. Examples:
            root="http://localhost:8080/"
            root="http://getafix.er.usgs.gov/data/"
         When applying the root, it will basically sub in for "dir". So when
         you upload to your web server, make sure that you put the contents of
         "dir" into "root".
      name= A name to apply to the top-level container in the KML file,
         describing the dataset as a whole.
      searchstr= Search string used to find kml files.
            searchstr="*-cir.kml"   (default)

   SEE ALSO: kml_jgw_build_product
*/
   default, root, "";
   default, searchstr, "*-cir.kml";
   default, name, file_tail(file_rootname(ofn));
   contents = kml_jgw_tree_recurse(dir, root, searchstr);
   kml_save, ofn, contents, name=name;
}

func kml_jgw_tree_recurse(dir, root, searchstr) {
/* DOCUMENT kml_jgw_tree_recurse, dir, root, searchstr
   Worker function for kml_jgw_tree. Do not call directly.
*/
   local files, subdirs;
   fix_dir, dir;
   fix_dir, root;
   result = [];
   files = lsdir(dir, subdirs);
   for(i = 1; i <= numberof(subdirs); i++) {
      grow, result, &strchar(kml_Folder(
         kml_jgw_tree_recurse(dir+subdirs(i), root+subdirs(i), searchstr),
         name=subdirs(i)));
   }
   if(numberof(files))
      files = files(where(strglob(searchstr, files)));
   for(i = 1; i <= numberof(files); i++) {
      grow, result, &strchar(kml_NetworkLink(
         kml_Link(href=root+files(i)),
         name=file_rootname(files(i))+".jpg"));
   }
   return strchar(merge_pointers(result));
}

func kml_jgw_build_product(dir, zone, kml, levels=, searchstr=, root=,
timediff=, name=, cir_soe_offset=) {
/* DOCUMENT kml_jgw_build_product, dir, zone, kml, levels=, searchstr=, root=,
   timediff=, name=, cir_soe_offset=

   Builds a KML product for a directory of CIR imagery. The result is a single
   large KML file that organizes all of the imagery with the following layers:

      Product
       - ( ) Images
       |      + ( ) Organized by fltline/10km/2km
       |      + ( ) Organized by 10km/2km/fltline
       + [ ] Placemarks

   The two layers under Image are radiobutton selections so that only one may
   be selected at a time. Both contain all of the available images, but
   organized by different schemes as noted.

   The Placemarks layer puts a marker at the center of each image with a
   balloon that provides various information on the image.

   This function will build the KML to render the image at different view
   levels based on the levels= option. However, it does *not* generate the
   subsampled images. You must run kml_jgw_make_levels to create the images.

   Parameters:
      dir: The path where the imagery is located.
      zone: The UTM zone of the imagery.
      kml: The kml file to create as output.
   Options:
      levels= Specifies how many view levels to render. If not specified, it
         will detect what's present and use that. However, it is recommended
         that you specify this option explicitly.
            levels=3    Use three view levels
            levels=7    Use seven view levels
         Generally speaking, a view level of 2-5 is typically sufficient. View
         levels higher than 7 are generally inefficient since a level 7 CIR is
         only 13x9 pixels, and further reductions gain nothing.
      searchstr= The searchstring to use to locate the jgw files.
            searchstr="*.jgw"    Default
      root= The root path where the product will be uploaded on a web server.
         The path specified by "dir" will be replaced by "root" in all links.
         When you upload to the web server, make sure the contents of "dir" go
         into "root". Examples:
            root="http://localhost:8080/"
            root="http://getafix.er.usgs.gov/data/"
      timediff= Time threshold for determining breaks in flightlines. Any
         series of images with gaps less than or equal to timediff will be
         considered a single flightline. Value is in seconds.
            timediff=60       Use a one-minute threshold. (default)
      name= The name to use for the top-level folder in the product. Defaults
         to the base name of the output kml file, without extension.
      cir_soe_offset= A time offset to apply to the CIR imagery timestamps,
         passed through to cir_to_soe.
            cir_soe_offset=1.12     1.12 seconds offset (default for cir_to_soe)
*/
   default, searchstr, "*.jgw";
   default, root, string(0);
   default, timediff, 60;
   default, name, file_tail(file_rootname(kml));

   fix_dir, root;

   t0all = array(double, 3);
   timer, t0all;

   // Find files, calculate timestamps
   files = find(dir, glob=searchstr);
   soes = cir_to_soe(file_rootname(file_tail(files))+".jpg", offset=cir_soe_offset);
   numfiles = numberof(files);

   // Put everything in SOE order.
   srt = sort(soes);
   files = files(srt);
   soes = soes(srt);
   srt = [];

   // Relative path to each file
   relpath = file_relative(dir, files);

   // --- Establish styles ---
   styles = [];
   balloon = \
"<![CDATA[\
<b>$[name]</b><br/>\
$[description]\
]]>";
   grow, styles, &strchar(kml_Style(
      kml_IconStyle(
         scale=0.8, color="bf00ffff",
         href="http://maps.google.com/mapfiles/kml/shapes/shaded_dot.png"
      ),
      kml_BalloonStyle(text=unref(balloon)),
      id="pmk"));

   // --- Generate overlays ---

   write, format="-- Generating overlay data --%s", "\n";

   t0 = array(double, 3);
   timer, t0;
   tp = t0;

   // Generate overlays and calculate parameters for images
   rotation = centerx = centery = array(double, dimsof(files));
   links = array(string, dimsof(files));
   overlays = array(pointer, dimsof(files));
   for(i = 1; i <= numfiles; i++) {
      curroot = fix_dir(root + file_dirname(relpath(i)));
      overlays(i) = &kml_jgw_image(files(i), zone, params, levels=levels,
         root=curroot);
      rotation(i) = params.rotation;
      centerx(i) = params.centerx;
      centery(i) = params.centery;
      links(i) = curroot + file_rootname(file_tail(files(i)))+".jpg";
      params = [];
      timer_remaining, t0, i, numfiles, tp, interval=15;
   }

   // Calculcate center coordinates in lat/lon
   centerlat = centerlon = [];
   utm2ll, centery, centerx, zone, centerlon, centerlat;

   // To ensure that images layer nicely, we want each overlay to have a unique
   // drawoder. The drawfactor lets us sequence them so that they do not
   // overlap; each image is always stacked the same with respect to other
   // images, regardless of view level.
   //
   // If level is provided, then drawfactor=level+2. If not provided, then we
   // have to autodetect. For simplicity, we just autodetect.
   drawfactor = 0;
   for(i = 1; i <= numfiles; i++)
      drawfactor = max(drawfactor, numberof(*overlays(i)));

   // --- Generate structures ---
   img_fltline = array(string, dimsof(soes));
   sptr = split_sequence_by_gaps(soes, gap=timediff);
   fmt = swrite(format="%%0%dd", long(log10(numberof(sptr))) + 1);
   numptr = numberof(sptr);
   snums = swrite(format=fmt, indgen(numptr));
   for(i = 1; i <= numptr; i++)
      img_fltline(*sptr(i)) = snums(i);
   img_dt = "t_" + utm2dt(centerx, centery, zone);
   img_it = utm2it(centerx, centery, zone);


   // --- Calculate fltlines and tiles ---
   img_fltline = array(string, dimsof(soes));
   ptr = split_sequence_by_gaps(soes, gap=timediff);
   fmt = swrite(format="%%0%dd", long(log10(numberof(ptr))) + 1);
   numptr = numberof(ptr);
   for(i = 1; i <= numptr; i++)
      img_fltline(*ptr(i)) = swrite(format=fmt, i);
   img_tiledt = "t_" + utm2dt(centerx, centery, zone);
   img_tileit = utm2it(centerx, centery, zone);
   img_id = file_tail(file_rootname(files));
   img_drawoffset = drawfactor * (indgen(numberof(files))-1);

   write, format="%s-- Generating overlay trees --\n", "\n";

   fltlinetree = &strchar(kml_Folder(
      __kml_jgw_build_product_img_tree([img_fltline, img_tileit, img_tiledt,
      img_id], overlays, zone, img_drawoffset, 1),
      name="Organized by fltline/10km/2km", visibility=1));

   itiletree = &strchar(kml_Folder(
      __kml_jgw_build_product_img_tree([img_tileit, img_tiledt, img_fltline,
      img_id], overlays, zone, img_drawoffset, 0),
      name="Organized by 10km/2km/fltline", visibility=0));

   // Placemarks
   write, "\n-- Generating placemarks --";

   placemarks = array(pointer, dimsof(files));
   descriptions = pointer(swrite(
      format= \
"<![CDATA[Acquired: %s<br />\
Organized by fltline/10km/2km at:<br />\
&nbsp;&nbsp;&nbsp;&nbsp;%s &raquo; %s &raquo; %s<br />\
Organized by 10km/2km/fltline at:<br />\
&nbsp;&nbsp;&nbsp;&nbsp;%s &raquo; %s &raquo; %s<br />\
On filesystem at:<br />\
&nbsp;&nbsp;&nbsp;&nbsp;%s<br />\
<a href=\"%s\">Download full resolution image</a>]]>",
      soe2iso8601(long(soes)),
      img_fltline, img_tileit, img_tiledt,
      img_tileit, img_tiledt, img_fltline,
      file_rootname(relpath)+".jpg",
      links));

   pmkflts = &strchar(kml_Folder(
      __kml_jgw_build_product_pmk_tree([img_fltline, img_tileit, img_tiledt,
      img_id], centerlat, centerlon, descriptions),
      name="Organized by fltline/10km/2km", visibility=0));

   pmktiles = &strchar(kml_Folder(
      __kml_jgw_build_product_pmk_tree([img_tileit, img_tiledt, img_fltline,
      img_id], centerlat, centerlon, descriptions),
      name="Organized by 10km/2km/fltline", visibility=0));

   write, "\n-- Finalizing --";

   trees = kml_Folder(
      kml_Style(kml_ListStyle(listItemType="radioFolder")),
      strchar(merge_pointers([unref(fltlinetree), unref(itiletree)])),
      name="Images", visibility=1, Open=1
   );

   placemarks = kml_Folder(
      kml_Style(kml_ListStyle(listItemType="radioFolder")),
      strchar(merge_pointers([unref(pmkflts), unref(pmktiles)])),
      name="Placemarks", visibility=0, Open=0
   );

   kml_save, kml, strchar(merge_pointers(unref(styles))),
      kml_Style(kml_ListStyle(listItemType="check")),
      trees, placemarks, name=name, visibility=1, Open=1;

   write, "\nKML generation complete.";
   timer_finished, t0all;
}

func __kml_jgw_build_product_image(name, raw, zone, offset, vis) {
/* DOCUMENT __kml_jgw_build_product_image, name, raw, zone, offset, vis
   Worker function for kml_jgw_build_product. Do not use directly.
*/
   order = offset + indgen(numberof(raw):1:-1);
   overlays = [];
   for(i = 1; i <= numberof(raw); i++)
      grow, overlays, &strchar(kml_GroundOverlay(strchar(*raw(i)),
         drawOrder=order(i), visibility=vis));
   return kml_Folder(
      kml_Style(kml_ListStyle(listItemType="checkHideChildren")),
      strchar(merge_pointers(overlays)), name=name, visibility=vis);
}

func __kml_jgw_build_product_img_tree(tiers, raw, zone, offset, vis) {
   curtier = tiers(..,1);
   if(dimsof(tiers)(3) > 1) {
      names = set_remove_duplicates(curtier);
      names = names(sort(names));
      count = numberof(names);
      ptrs = array(pointer, count);
      for(i = 1; i <= count; i++) {
         w = where(curtier == names(i));
         ptrs(i) = &strchar(kml_Folder(
            __kml_jgw_build_product_img_tree(tiers(w,2:), raw(w), zone,
            offset(w), vis), name=names(i), visibility=vis));
      }
      return strchar(merge_pointers(ptrs));
   } else {
      count = numberof(curtier);
      ptrs = array(pointer, count);
      for(i = 1; i <= count; i++) {
         ptrs(i) = &strchar(__kml_jgw_build_product_image(curtier(i), *raw(i), zone,
            offset(i), vis));
      }
      return strchar(merge_pointers(ptrs));
   }
}

func __kml_jgw_build_product_pmk_tree(tiers, lat, lon, desc) {
   curtier = tiers(..,1);
   if(dimsof(tiers)(3) > 1) {
      names = set_remove_duplicates(curtier);
      names = names(sort(names));
      count = numberof(names);
      ptrs = array(pointer, count);
      for(i = 1; i <= count; i++) {
         w = where(curtier == names(i));
         ptrs(i) = &strchar(kml_Folder(
            __kml_jgw_build_product_pmk_tree(tiers(w,2:), lat(w), lon(w),
            desc(w)), name=names(i)));
      }
      return strchar(merge_pointers(ptrs));
   } else {
      count = numberof(curtier);
      ptrs = array(pointer, count);
      for(i = 1; i <= count; i++) {
         ptrs(i) = &strchar(kml_Placemark(
            kml_Point(lon(i), lat(i)),
            kml_Snippet("", maxLines=0),
            name=curtier(i), visibility=0, styleUrl="#pmk",
            description=strchar(*desc(i))
         ));
      }
      return strchar(merge_pointers(ptrs));
   }
}

func batch_kml_jgw(dir, zone, levels=, searchstr=) {
/* DOCUMENT batch_kml_jgw, dir, zone, levels=, searchstr=
   Runs kml_jgw in batch mode. This creates individual per-image KML files for
   each image. This function is deprecated in favor of kml_jgw_build_product/
*/
   default, searchstr, "*.jgw";
   files = find(dir, glob=searchstr);
   t0 = array(double, 3);
   timer, t0;
   tp = t0;
   n = numberof(files);
   for(i = 1; i <= n; i++) {
      kml_jgw, files(i), zone, levels=levels;
      timer_remaining, t0, i, n, tp, interval=10;
   }
   timer_finished, t0;
}

func kml_jgw(jgw, zone, kml=, levels=) {
/* DOCUMENT kml_jgw, jgw, zone, kml=, levels=
   Generates a KML file for a JGW file.

   Parameters:
      jgw: The JGW file to use
      zone: UTM zone
   Options:
      kml= Where to create the kml file. Default is same as JGW with .kml
         extension.
      levels= How many view levels to incorporate.
*/
   local lon, lat;
   default, levels, 0;
   default, kml, file_rootname(jgw)+".kml";

   raw_overlays = kml_jgw_image(jgw, zone, levels=levels);
   order = indgen(numberof(raw_overlays):1:-1);

   overlays = [];
   for(i = 1; i <= numberof(raw_overlays); i++)
      grow, overlays, &strchar(kml_GroundOverlay(strchar(*raw_overlays(i)),
         drawOrder=order(i)));
   overlays = strchar(merge_pointers(overlays));
   kml_save, kml, overlays, name=file_rootname(file_tail(jgw))+".jpg";
}

func kml_jgw_image(jgw, zone, &params, levels=, root=) {
/* DOCUMENT overlays = kml_jgw_image(jgw, zone, &params, levels=, root=)
   Returns an array of pointers to arrays of characters. Each array of
   characters represents an array of strings that comprise the ground overlay
   components for a view level.

   overlays(1) -> Full resolution image
   overlays(2) -> First downsampling (*_d1.jpg)
   overlays(3) -> Second downsampling (*_d2.jpg)
   ...
   overlays(0) -> Translucent footprint of area covered by image

   It is intended that the overlay be converted to string, then passed to
   GroundOverlay to actually create the overlay. The overlay components do not
   include a "drawOrder" component, so the calling function should supply one.

   The params parameter is an output parameter that will be populated with the
   result from jgw_decompose for the image's jgw file.

   Parameters:
      jgw: The jgw file.
      zone: The UTM zone for the image.
   Output parameter:
      params: Will be populated with the result from jgw_decompose for the
         image's jgw file.
   Options:
      levels= The number of levels to generate. By default, uses whatever's
         available.
      root= Prefix to attach to icon links. By default, none is used.
*/
   local lon, lat;
   default, root, string(0);
   fix_dir, root;

   // If levels is not provided, then determine based on available images
   if(is_void(levels)) {
      ljpgs = find(file_dirname(jgw), file_rootname(file_tail(jgw))+"_d*.jpg");
      levels = numberof(ljpgs);
      ljpgs = [];
   }

   jpg = file_rootname(jgw)+".jpg";

   // Read JGW parameters
   jgw = read_ascii(jgw)(*);
   dims = image_size(jpg);
   params = jgw_decompose(jgw, dims);

   // Calculate where the overlay should be displayed. This uses the overlay's
   // actual size plus a rotation factor.
   utmx = params.centerx + params.width * [-0.5,-0.5,0.5,0.5];
   utmy = params.centery + params.height * [-0.5,0.5,0.5,-0.5];
   utm2ll, utmy, utmx, zone, lon, lat;
   onorth = lat(max);
   osouth = lat(min)
   oeast = lon(max);
   owest = lon(min);
   rotation = params.rotation;
   while(rotation > 180)
      rotation -= 360;
   while(rotation < -180)
      rotation += 360;

   // Calculate that view region for display loading. This is the bounding box
   // of the overlay.
   utmx = [params.xmin, params.xmin, params.xmax, params.xmax];
   utmy = [params.ymin, params.ymax, params.ymax, params.ymin];
   utm2ll, utmy, utmx, zone, lon, lat;
   rnorth = lat(max);
   rsouth = lat(min);
   reast = lon(max);
   rwest = lon(min);

   utmx = utmy = lon = lat = [];

   // All of them get the same latlonbox
   latlonbox = kml_LatLonBox(north=onorth, south=osouth, east=oeast,
      west=owest, rotation=rotation);

   overlays = [];

   // the "lod" value is based on the square root of the area of pixels
   // viewable on screen. The lodbasis allows us to calculate values with
   // respect to that.
   lodbasis = sqrt(dims(1)*dims(2));

   // The full resolution image gets 64 pixel lod if there are no subsequent
   // layers
   minlod = levels ? long(lodbasis/(2.^.5)) : 64;
   region = kml_Region(north=rnorth, south=rsouth, east=reast, west=rwest,
      minLodPixels=minlod);
   icon = kml_Icon(href=root + file_tail(jpg));
   overlay = [region, latlonbox, icon];
   grow, overlays, &strchar(strjoin(overlay, "\n"));

   // Add additional layers, in decreasing resolution order
   if(levels) {
      ljpgs = file_rootname(jpg) + swrite(format="_d%d.jpg", indgen(levels));
      for(i = 1; i <= levels; i++) {
         ljpg = ljpgs(i);
         minlod = long(lodbasis/(2.^(i+.5)));
         region = kml_Region(north=rnorth, south=rsouth, east=reast, west=rwest,
            minLodPixels=minlod);
         icon = kml_Icon(href=root + file_tail(ljpg));
         overlay = [region, latlonbox, icon];
         grow, overlays, &strchar(strjoin(overlay, "\n"));
      }
   }

   // Last layer is a blue box that shows footprint and should be viewable at
   // all view levels
   region = kml_Region(north=rnorth, south=rsouth, east=reast, west=rwest,
      minLodPixels=0);
   overlay = [region, latlonbox, kml_element("color", kml_color(0,0,255,127))];
   grow, overlays, &strchar(strjoin(overlay, "\n"));

   return overlays;
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

   listing = dest + ".listing";

   cmd = [];
   exe = popen_rdfile("which zip");
   if(numberof(exe)) {
      cmd = swrite(format="cd '%s' && cat '%s' | '%s' -X -9 -@ '%s'; rm -f '%s'",
         file_dirname(dest), listing, exe(1), file_tail(dest), listing);
   } else {
      error, "Unable to zip command.";
   }

   files = file_relative(file_dirname(dest), files);

   if(file_exists(dest))
      remove, dest;

   cwd = get_cwd();
   cd, file_dirname(dest);

   // Write out the list of files
   f = open(listing, "w");
   write, f, format="%s\n", files;
   close, f;

   system, cmd;

   // In case we're using sysafe, which runs async
   while(file_exists(listing))
      pause, 1;

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

func kml_BalloonStyle(void, id=, bgColor=, textColor=, text=, displayMode=) {
   elems = [];
   grow, elems, kml_element("bgColor", bgColor);
   grow, elems, kml_element("textColor", textColor);
   grow, elems, kml_element("text", text);
   grow, elems, kml_element("displayMode", displayMode);
   return kml_element("BalloonStyle", elems, id=id);
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

func kml_Snippet(text, maxLines=) {
   if(is_void(maxLines))
      return swrite(format="<Snippet>%s</Snippet>", text);
   else
      return swrite(format="<Snippet maxLines=\"%d\">%s</Snippet>", maxLines, text);
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

func kml_LatLonBox(items, .., north=, south=, east=, west=, rotation=) {
   while(more_args())
      grow, items, next_arg();
   grow, items, kml_element("north", north);
   grow, items, kml_element("south", south);
   grow, items, kml_element("east", east);
   grow, items, kml_element("west", west);
   grow, items, kml_element("rotation", rotation);
   return kml_element("LatLonBox", items);
}

func kml_Icon(void, href=) {
   return kml_element("Icon", kml_element("href", href));
}

func kml_GroundOverlay(items, .., id=, name=, visibility=, Open=, description=, styleUrl=, north=, south=, east=, west=, rotation=, drawOrder=, color=, href=) {
   while(more_args())
      grow, items, next_arg();

   grow, items, kml_LatLonBox(north=north, south=south, east=east, west=west,
      rotation=rotation);
   grow, items, kml_element("drawOrder", drawOrder);
   grow, items, kml_element("color", color);
   grow, items, kml_Icon(href=href);

   return kml_Feature("GroundOverlay", items, id=id, description=description,
      name=name, visibility=visibility, Open=Open, styleUrl=styleUrl);
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
      single = strlen(name) * 2 + strlen(id) + strlen(items(1)) <= 66;

   if(single)
      single = !strmatch(items(1), "\n");

   if(single)
      single = (strpart(items(1), 1:1) != "<");

   if(single) {
      items = items(1);
      fmt = "<%s%s>%s</%s>";
   } else {
      items = strjoin(unref(items), "\n");
      if(strlen(items) < 1000)
         items = strindent(unref(items), "  ");
      fmt = "<%s%s>\n%s\n</%s>";
   }

   return swrite(format=fmt, name, id, items, name);
}
