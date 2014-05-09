// vim: set ts=2 sts=2 sw=2 ai sr et:

func kml_jgw_make_levels(util, dir, levels=, searchstr=, jgw=, update=, fast=,
quality=) {
/* DOCUMENT kml_jgw_make_levels, dir, levels=, searchstr=, jgw=, update=,
  fast=, quality=

  Generates downsampled images for multiple view levels for a CIR dataset.
  Each level is half the width and half the height of the previous level.

  This ONLY generates the images. It must be run independently of the actual
  kml generation.

  Parameter:
    dir: The directory to find images in.

  Options:
    levels= The number of levels to generate. Alternately, this may be an array
      of the specific levels to generate.
        levels=7          Generate seven levels (default)
        levels=[3,5]      Only generate levels 3 and 5
    searchstr= Search pattern to find images with.
        searchstr="*-cir.jpg"      Default
    jgw= Instead of searching for jpg files, search for jgw files. Then use the
      corresponding jpg files. This also changes the meaning of searchstr= to
      target jgw (and changes its default to "*.jgw").
        jgw=1             Use jpgs alongside jgw files that match searchstr=.
        jgw=0             Search for files matching searchstr=.
    update= Whether to skip existing images or not.
        update=0          Re-create existing images, overwriting
        update=1          Skip images that already exist (default)
    fast= Passed through to jpg_shrink.
    quality= Passed through to jpg_shrink.

  SEE ALSO: kml_jgw_make_levels_single, jpg_shrink
*/
  default, searchstr, (jgw ? "*.jgw" : "*-cir.jpg");
  default, levels, 7;
  default, update, 1;

  if(is_scalar(levels)) {
    levels = indgen(0:levels);
  } else {
    levels = levels(sort(levels));
    levels = grow(0, levels);
  }
  factors = 2^levels(dif);
  levels = levels(2:);
  nlevels = numberof(levels);

  t0 = array(double, 3);
  timer, t0;

  write, "Finding files...";
  files = find(dir, searchstr=searchstr);

  if(jgw) {
    write, "Finding corresponding images...";
    files = file_rootname(files) + ".jpg";
    w = where(file_exists(files));
    files = files(w);
  }
  num = numberof(files);
  write, format=" Found %d images.\n", num;

  ljpgs = file_rootname(files) + swrite(format="_d%d.jpg", levels)(-,);
  if(update) {
    write, "Detecting existing images...";
    exists = file_exists(ljpgs);
  } else {
    write, "Deleting existing images...";
    for(i = 1; i <= num; i++) for(j = 1; j <= nlevels; j++) remove, ljpgs(i,j);
  }

  conf = save();
  write, "Building jobs...";
  for(i = 1; i <= num; i++) {
    if(update && allof(exists(i,))) continue;
    tmp = (nlevels > 1 ? ljpgs(i,1)+".tmp" : []);
    raw = util.cmd(files(i), ljpgs(i,1), factors(1), tmp, init=1);
    for(j = 2; j <= nlevels; j++) {
      prev = ljpgs(i,j-1)+".tmp";
      tmp = (j < nlevels ? ljpgs(i,j)+".tmp" : []);
      raw += " ; " + util.cmd(prev, ljpgs(i,j), factors(j), tmp);
    }
    save, conf, string(0), save(
      input=files(i),
      output=ljpgs(i,),
      raw
    );
  }
  if(!am_subroutine()) return conf;
  if(!conf(*)) {
    write, "All images already exist, aborting.";
    return;
  }
  write, "Running jobs...";
  makeflow_run, conf, interval=15;
  timer_finished, t0;
}

scratch = save(scratch, kml_jgw_make_levels_cmd);

func kml_jgw_make_levels_cmd(in, out, factor, tmp, init=) {
  if(init) {
    cmd = swrite(format="jpegtopnm -dct fast -nosmooth '%s' 2>/dev/null | ", in);
  } else {
    cmd = swrite(format="cat '%s' | ", in);
  }
  cmd += swrite(format="pnmscalefixed -reduce %d - 2> /dev/null | ", factor);
  if(tmp) cmd += swrite(format="tee '%s' | ", tmp);
  cmd += swrite(format="pnmtojpeg -optimize -quality 70 -dct fast > '%s'", out);
  if(!init) {
    cmd += swrite(format=" ; rm -f '%s'", in);
  }
  return cmd;
}

kml_jgw_make_levels = closure(kml_jgw_make_levels,
  save(cmd=kml_jgw_make_levels_cmd));
restore, scratch;

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
  files = find(dir, searchstr=searchstr);
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
  img_dt = utm2dt(centerx, centery, zone, dtprefix=1);
  img_it = utm2it(centerx, centery, zone);

  // --- Calculate fltlines and tiles ---
  img_fltline = array(string, dimsof(soes));
  ptr = split_sequence_by_gaps(soes, gap=timediff);
  fmt = swrite(format="%%0%dd", long(log10(numberof(ptr))) + 1);
  numptr = numberof(ptr);
  for(i = 1; i <= numptr; i++)
    img_fltline(*ptr(i)) = swrite(format=fmt, i);
  img_tiledt = utm2dt(centerx, centery, zone, dtprefix=1);
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
      drawOrder=order(i), visibility=1));
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
        name=curtier(i), visibility=0, styleUrl="#pmk",
        description=strchar(*desc(i))
      ));
    }
    return strchar(merge_pointers(ptrs));
  }
}

func batch_kml_jgw(dir, zone, levels=, searchstr=, footprint=) {
/* DOCUMENT batch_kml_jgw, dir, zone, levels=, searchstr=
  Runs kml_jgw in batch mode. This creates individual per-image KML files for
  each image. This function is deprecated in favor of kml_jgw_build_product.
*/
  default, searchstr, "*.jgw";
  files = find(dir, searchstr=searchstr);
  n = numberof(files);
  files = files(sort(files));
  status, start, msg="Generating KML files...";
  for(i = 1; i <= n; i++) {
    kml_jgw, files(i), zone, levels=levels, footprint=footprint;
    status, progress, i, n;
  }
  status, finished;
}

func kml_jgw(jgw, zone, &params, kml=, levels=, footprint=, name=) {
/* DOCUMENT kml_jgw, jgw, zone, kml=, levels=, footprint=
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
  default, name, file_rootname(file_tail(jgw))+".jpg";

  raw_overlays = kml_jgw_image(jgw, zone, params, levels=levels,
    footprint=footprint);
  order = indgen(numberof(raw_overlays):1:-1);

  overlays = [];
  for(i = 1; i <= numberof(raw_overlays); i++)
    grow, overlays, &strchar(kml_GroundOverlay(strchar(*raw_overlays(i)),
      drawOrder=order(i)));
  overlays = strchar(merge_pointers(overlays));
  style = kml_Style(kml_ListStyle(listItemType="checkHideChildren"));
  kml_save, kml, style, overlays, name=name;
}

func kml_jgw_image(jgw, zone, &params, levels=, root=, footprint=) {
/* DOCUMENT overlays = kml_jgw_image(jgw, zone, &params, levels=, root=, footprint=)
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
      available. May be specified as a scalar number of levels or as an array
      of specific levels.
    root= Prefix to attach to icon links. By default, none is used.
    footprint= Specifies whether a blue footprint should be displayed when you
      are zoomed too far out for any existing view level.
        footprint=1     Default, show a blue footprint
        footprint=0     No footprint, show lowest resolution image instead
*/
  local lon, lat, tmp;
  default, root, string(0);
  default, footprint, 1;
  fix_dir, root;

  // If levels is not provided, then determine based on available images
  if(is_void(levels)) {
    ljpgs = find(file_dirname(jgw), searchstr=file_rootname(file_tail(jgw))+"_d*.jpg");
    valid = regmatch("_d([0-9]+)\\.jpg$", ljpgs, , tmp);
    if(nallof(valid)) error, "invalid downsampled image detected";
    levels = atoi(tmp);
    levels = levels(sort(levels));
    ljpgs = [];
  // If scalar, turn into array
  } else if(is_scalar(levels)) {
    levels = indgen(1:levels);
  // If array, ensure it is sorted
  } else {
    levels = levels(sort(levels));
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
  // layers and we are using a footprint
  if(numberof(levels)) {
    minlod = long(lodbasis/(2.^(levels(1)-.5)));
  } else {
    minlod = footprint ? 64 : 0;
  }
  region = kml_Region(north=rnorth, south=rsouth, east=reast, west=rwest,
    minLodPixels=minlod);
  icon = kml_Icon(href=root + file_tail(jpg));
  overlay = [region, latlonbox, icon];
  grow, overlays, &strchar(strjoin(overlay, "\n"));

  // Add additional layers, in decreasing resolution order
  if(numberof(levels)) {
    ljpgs = file_rootname(jpg) + swrite(format="_d%d.jpg", levels);
    nlevels = numberof(levels);
    for(i = 1; i <= nlevels; i++) {
      ljpg = ljpgs(i);
      if(i < nlevels) {
        minlod = long(lodbasis/2.^(levels(i+1)-.5));
      } else if(footprint) {
        minlod = long(lodbasis/2.^(levels(i)+.5));
      } else {
        minlod = 0;
      }
      region = kml_Region(north=rnorth, south=rsouth, east=reast, west=rwest,
        minLodPixels=minlod);
      icon = kml_Icon(href=root + file_tail(ljpg));
      overlay = [region, latlonbox, icon];
      grow, overlays, &strchar(strjoin(overlay, "\n"));
    }
  }

  // Last layer is a blue box that shows footprint and should be viewable at
  // all view levels
  if(footprint) {
    region = kml_Region(north=rnorth, south=rsouth, east=reast, west=rwest,
      minLodPixels=0);
    overlay = [region, latlonbox, kml_element("color", kml_color(0,0,255,127))];
    grow, overlays, &strchar(strjoin(overlay, "\n"));
  }

  return overlays;
}

func kml_jgw_index(dir, ofn, root=, name=, zone=, levels=, searchstr=) {
/* DOCUMENT kml_jgw_tree, dir, ofn, root=, name=, zone=, searchstr=
  Generates a KML product for a directory tree of imagery. All jgw files will
  be located and a placemark will be generated for each.

  Prerequisites:
    - Images must be organized by flightline. You should have created the
      directory using copy_cirdata_images_by_flightline (with jgw=1).
    - You must already have run kml_jgw_make_levels using levels=[2,3,5],
      jgw=1.

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
    searchstr= Search string used to find jgw files.
        searchstr="*.jgw"   (default)

  SEE ALSO: kml_jgw_build_product
*/
  default, root, "";
  default, searchstr, "*.jgw";
  default, name, file_tail(file_rootname(ofn));
  default, zone, curzone;
  fix_dir, dir;

  styles = [];
  grow, styles, kml_Style(
    kml_IconStyle(
      scale=0.5, color="bf00ffff",
      href="http://maps.google.com/mapfiles/kml/shapes/shaded_dot.png"
    ),
    id="pmk");
  grow, styles, kml_Style(
    kml_LineStyle(color="#ff00ff00", width=1),
    id="line");

  doc = kml_Placemark(
    name="Troubleshooting",
    description="If the links in the placemark balloons do not work, then your Google Earth is configured to prevent access to local files. To fix this, open the Google Earth Options window by going to the \"Tools\" menu and selecting \"Options...\". Then select the \"General\" tab. In the section labeled \"Placemark balloons\", make sure that \"Allow access to local files and personal data\" is checked/enabled."
    );

  local subdirs;
  lsdir, dir, subdirs;
  if(!numberof(subdirs)) error, "No subdirs found";
  subdirs = subdirs(sort(subdirs));
  nsub = numberof(subdirs);
  contents = array(pointer, nsub);
  status, start, msg="Processing folders...";
  for(i = 1; i <= nsub; i++) {
    contents(i) = &strchar(kml_jgw_index_folder(dir, root, subdirs(i), zone,
      searchstr, levels));
    status, progress, i, nsub;
  }
  status, finished;
  contents = kml_Folder(strchar(merge_pointers(contents)), name="Flightlines");

  kml_save, ofn, styles, doc, contents, name=name, visibility=1, Open=1;
}

func kml_jgw_index_folder(base, root, subdir, zone, searchstr, levels) {
  local lon, lat, params;

  files = find(base+subdir, searchstr=searchstr);
  if(!numberof(files)) return string(0);
  files = files(sort(files));
  nfiles = numberof(files);

  pmarks = array(pointer, nfiles);
  lons = array(double, nfiles);
  lats = array(double, nfiles);
  for(i = 1; i <= numberof(files); i++) {
    file = file_rootname(files(i));
    rel = file_relative(base, file);
    tail = file_tail(file);

    kml_jgw, file+".jgw", zone, params, levels=levels, footprint=0;
    utm2ll, params.centery, params.centerx, zone, lon, lat;
    lons(i) = lon;
    lats(i) = lat;

    desc = swrite(format= \
"<![CDATA[\
<b>%s</b><br />\
Acquired: %s UTC<br />\
<br />\
<img src=\"%s\" /><br />\
<br />\
<a href=\"%s\">Load in Google Earth</a><br />\
<a href=\"%s\">Download full resolution image</a>\
]]>",
      tail+".jpg",
      soe2iso8601(cir_to_soe(tail+".jpg")),
      root+rel+"_d3.jpg",
      root+rel+".kml",
      root+rel+".jpg"
      );

    pmarks(i) = &strchar(kml_Placemark(
      kml_Point(lon, lat),
      visibility=1, styleUrl="#pmk",
      description=desc
    ));
  }
  pmarks = strchar(merge_pointers(pmarks));

  line = kml_Placemark(
    kml_LineString(lons, lats, tessellate=1),
    visibility=1, styleUrl="#line",
    name="Flightline"
  );

  soeA = cir_to_soe(file_tail(file_rootname(files(1))+".jpg"));
  soeZ = cir_to_soe(file_tail(file_rootname(files(0))+".jpg"));
  dateA = soe2date(soeA);
  dateZ = soe2date(soeZ);
  timeA = soe2time(soeA);
  timeZ = soe2time(soeZ);
  name = "Flightline "+subdir;
  if(dateA == dateZ) {
    name += swrite(format=": %s %d:%02d - %d:%02d UTC",
      dateA, timeA(4), timeA(5), timeZ(4), timeZ(5));
  } else {
    name += swrite(format=": %s %d:%02d - %s %d:%02d UTC",
      dateA, timeA(4), timeA(5), dateB, timeZ(4), timeZ(5));
  }

  return kml_Folder(line, pmarks, name=name);
}

func kml_jgw_flight_index(dir, ofn=, name=, zone=, levels=) {
/* DOCUMENT kml_jgw_flight_index, dir, ofn=, name=, zone=, levels=
  Creates a flight imagery index KML.

  Prerequisites:
    - You must have the correct mission flight data loaded.
    - <dir> should be a date folder with images organized as thus:
        <dir>/photos/<type>/HHMM/<image>
      where <type> is rgb or nir. If you ise "Dump NIR" and "Dump RGB" from the
      Mission Configuration Manager, the files will end up organized that way.
    - You must have generated JGW files.
    - You must have run kml_jgw_make_levels to generate at least levels=[3].
      You may add additional levels optionally, but level 3 is required for the
      thumbnails.

  Options:
    ofn= Defaults to <dir>/index.kml
    zone= Defaults to curzone
    levels= Defaults to [3]
    name= Defaults to the last component of <dir>
*/
  t0 = array(double, 3);
  timer, t0;
  local types, minutes;

  default, ofn, file_join(dir, "index.kml");
  default, zone, curzone;
  default, levels, [3];
  default, name, file_tail(dir);

  // Downsample pnav to reduce overall size and complexity
  write, "Downsampling pnav...";
  utm = fll2utm(pnav.lat, pnav.lon);
  idx = downsample_line(utm(2,), utm(1,), idx=1, maxdist=2);
  pn = pnav(idx);
  utm = idx = [];

  // Sanity check
  photos_dir = file_join(dir, "photos");
  if(!file_exists(photos_dir)) error, "photos subdir does not exist";

  // Get a list of the types available
  lsdir, photos_dir, types;
  if(!numberof(types)) error, "no imagery folders under photos";
  types = types(sort(types));
  ntypes = numberof(types);

  write, "Finding images...";
  data = save();
  // For each type, get a list of the files available
  for(i = 1; i <= ntypes; i++) {
    files = find(file_join(photos_dir, types(i)), searchstr="*.jgw");
    if(!numberof(files)) continue;
    files = file_relative(photos_dir, files);
    base = file_rootname(files);
    stag = soe2iso8601(cir_to_soe(file_tail(base)+".jpg"));
    mtag = strpart(stag, :16);

    n = numberof(files);
    for(j = 1; j <= n; j++) {
      obj_hier_save, data, mtag(j), stag(j), types(i), base(j);
    }
  }

  // Static KML elements
  dot_style = kml_Style(
    kml_LabelStyle(scale=0),
    kml_IconStyle(
      scale=0.45, color="ff00ffff",
      href="http://maps.google.com/mapfiles/kml/shapes/shaded_dot.png"
    ),
    id="dot");

  write, "Building KML...";
  // Now build KMLs based on data in data obj
  minutes = data(*,);
  minutes = minutes(sort(minutes));
  bigdots = array(pointer, data(*));

  local placemark;
  status, start, msg="Building KML...";
  for(i = 1; i <= data(*); i++) {
    kml_jgw_flight_index_minute, photos_dir,
      data(minutes(i)), minutes(i), pn, levels,
      placemark;
    bigdots(i) = &strchar(placemark);

    status, progress, i, data(*);
  }
  status, finished;

  // Create KML for per-minute images
  minutefn = file_join(photos_dir, "images.kml");

  bigdots = strchar(merge_pointers(bigdots));

  write, "Finalizing images...";
  kml_save, minutefn, bigdots, name="Images", visibility=1, Open=0;

  // Create KML for main index

  doc = kml_Placemark(
    name="Troubleshooting",
    description="If the links in the placemark balloons do not work, then your Google Earth is configured to prevent access to local files. To fix this, open the Google Earth Options window by going to the \"Tools\" menu and selecting \"Options...\". Then select the \"General\" tab. In the section labeled \"Placemark balloons\", make sure that \"Allow access to local files and personal data\" is checked/enabled."
    );

  flight = kml_Placemark(
    kml_Style(kml_LineStyle(color="#ffff0000", width=2)),
    kml_LineString(pn.lon, pn.lat, tessellate=1),
    name="Flightline"
    );

  images = kml_NetworkLink(
    kml_Link(href="photos/images.kml"),
    name="Images");

  write, "Finalizing...";
  kml_save, ofn, style, doc, flight, images, name=name, visibility=1, Open=1;

  timer_finished, t0;
}

func kml_jgw_flight_index_minute(dir, data, mtag, pnav, levels, &placemark) {
// Worker function for a minute
// This calls _second for each second (producing KMLs for each JPG/JGW)
// This creates the minute's KML file, containing all seconds except the center
// This assigns the center placemark to &placemark

  seconds = data(*,);
  seconds = seconds(sort(seconds));

  imgs = 0;
  dots = array(string, data(*));
  sods = array(double, data(*));
  lon = array(double, data(*));
  lat = array(double, data(*));

  local desc, sod;
  for(i = 1; i <= data(*); i++) {
    sdata = data(seconds(i));

    kml_jgw_flight_index_second, dir, sdata, seconds(i), levels, desc, sod;

    imgs += sdata(*);
    dots(i) = desc;
    sods(i) = sod;
  }

  lat = interp(pnav.lat, pnav.sod, sods);
  lon = interp(pnav.lon, pnav.sod, sods);

  // mtag is YYYY-MM-DD HH:MM
  // mtagclean is YYYYMMDD_HHMM
  mtagclean = regsub(" ", regsub("-|:", mtag, "", all=1), "_");
  // output filename, if needed
  fn = file_join(dir, mtagclean+".kml");

  // Edge case: if there's only one entry for this minute, it only gets a big
  // dot.
  if(numberof(dots) == 1) {
    single = 1;
    w = 1;
    bigsod = sods(w);
    footer = "<i>No more images available during this minute.</i>";
  } else {
    single = 0;
    // Find dot closest to center (timewise) and pull it out for the big dot
    w = abs(sods - [sods(1),sods(0)](avg))(mnx);
    bigsod = long(abs(sods - sods(w))(max));
    footer = swrite(format=\
"<a href=\"%s\">Load %d additional nearby locations</a> \
representing %d images within +/- %d seconds",
      mtagclean+".kml", numberof(dots)-1,
      imgs, bigsod
    );
  }

  desc = swrite(format="<![CDATA[%s<hr />%s]]>", dots(w), footer);

  heading = interp(tans.heading, tans.somd, sods(w));
  // Force into range [0,360)
  heading = (heading + 360) % 360;

  // placemark is an output variable
  placemark = kml_Placemark(
    kml_Style(
      kml_LabelStyle(scale=0),
      kml_IconStyle(
        href="http://maps.google.com/mapfiles/kml/shapes/airports.png",
        scale=0.8, heading=heading
      )
    ),
    kml_Point(lon(w),lat(w)),
    visibility=1,
    name=mtag,
    description=desc
  );

  // For edge case of only one second, no KML file gets generated.
  if(single) return;

  // Get rid of the entry we used for the big dot
  keep = array(1, numberof(dots));
  keep(w) = 0;
  w = where(keep);
  dots = dots(w);
  seconds = seconds(w);

  // Now create placemarks for this minute
  n = numberof(dots);
  for(i = 1; i <= n; i++) {
    desc = swrite(format="<![CDATA[%s]]>", dots(i));
    dots(i) = kml_Placemark(
      kml_Point(lon(i),lat(i)),
      visibility=1, styleUrl="#dot",
      name=seconds(i),
      description=desc
    );
  }

  style = kml_Style(
    kml_LabelStyle(scale=0),
    kml_IconStyle(
      scale=0.45, color="ff00ffff",
      href="http://maps.google.com/mapfiles/kml/shapes/shaded_dot.png"
    ),
    id="dot");

  // Write out KML file for this minute
  kml_save, fn, style, dots, name=mtag, visibility=1, Open=0;
}

func kml_jgw_flight_index_second(dir, data, stag, levels, &desc, &sod) {
// Worker function for a single second
// This creates the KML files for each individual JPG/JGW
// This assigns description for this second to &desc
// This assigns the sod value to &sod

  thumbs = array(string, data(*));

  for(i = 1; i <= data(*); i++) {
    type = data(*,i);
    base = data(noop(i));
    full = file_join(dir, base);

    // Create KML for current image
    name = file_tail(full)+".jpg ("+type+")";
    kml_jgw, full+".jgw", zone, levels=levels, footprint=0, name=name;

    // Create cell content for placemark
    thumbs(i) = swrite(format=\
"<td>\
<center><b>%s</b></center>\
<img src=\"%s\" /><br />\
<br />\
<a href=\"%s\">Load in Google Earth</a><br />\
<a href=\"%s\">Download full resolution image</a>\
</td>",
      type,
      base+"_d3.jpg",
      base+".kml",
      base+".jpg");
  }

  // desc and sod are the output variables

  // Combine thumbs to make the placemark desc
  desc = swrite(format=\
"Acquired: %s UTC<br />\
<br />\
<table><tr valign=\"top\">%s</tr></table>",
    stag, thumbs(sum));

  // Determine sod value
  sod = cir_to_soe(file_tail(data(1))+".jpg") - soe_day_start;
}
