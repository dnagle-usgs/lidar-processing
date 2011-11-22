// vim: set ts=2 sts=2 sw=2 ai sr et:
require, "eaarl.i";

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
