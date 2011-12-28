require, "dir.i";
require, "kml.i";

func batch_kml_extents(datadir, outdir, searchstr=, name=, desc=, 
  visibility=, Open=, linecolor=, linewidth=) {
/* DOCUMENT batch_kml_extents, datadir, outdir, searchstr=, visibility=, 
  Open=, linecolor=, linewidth=

  Parameters:
    datadir: The directory to search for extents shapefiles.
    outdir: The directory where the created kml will go.
      Default is the same location as the input shapefile.

  Options:
    searchstr= The search string to use for finding extents shapefiles.
      Default: searchstr="*_tile_extents.xyz"
    name= Name of the kml. If there's more than one shapefile each will 
      have the same name if one is supplied on the commandline. If none 
      is supplied, it will try to parse the year and survey name from 
      the xyz file path.
    desc= Description of the contents of each kml file. 
      Default: desc="Tile Extents".
    visibility= Whether or not the line is visible when loaded. 
      Default=1.
    Open= Whether or not the folder is open when loaded.
      Default=0.
    linecolor= The color of the line, in AABBGGRR format
      (alpha-blue-green-red). Defaults to random color.
    linewidth= The width of the line. Default=1.

  Original Christine Kranenburg 2011-12-13
*/

  default, searchstr, "*_tile_extents.xyz";
  default, desc, "Tile Extents";

  if (is_void(name)) autoname = 1;

  cur = find(datadir, glob=searchstr);
  if (numberof(cur) == 0) 
    write, "\nNo _tile_extents.xyz files found!\n";


  for (i=1; i <= numberof(cur); i++) {
    path = fix_dir(file_dirname(cur(i)));
    outfile = file_rootname(file_tail(cur(i))) + ".kml";

// If name was not supplied, attempt to parse year and survey name 
// out of the file path. If unable to find year, name tag is empty.
    if (autoname) {
      name = "";
      treepath = strsplit(path, "/");
      idx = where(atoi(treepath) > 1980);
      if (numberof(idx) >= 1)
	 name = strjoin(treepath(idx(1):), "_");
      }

    if (!is_void(outdir)) {
      subpath=file_relative(datadir, path);
      path = file_join(outdir, subpath);
      mkdirp, path;
    }
    outfile = file_join(path, outfile);

    kml_extents, cur(i), outfile, name=name, description=desc, 
      visibility=visibility, Open=Open, linecolor=kml_randomcolor(), 
      linewidth=linewidth;
  }
}


func kml_extents(filename, dest, name=, description=, visibility=, 
  Open=, linecolor=, linewidth=) {
/* DOCUMENT kml_extents, filename, dest, visibility=, Open=, linecolor=, 
  linewidth=

  Creates a kml file from an ascii shapefile. Intended for generating 
  kml extents for RGB/CIR imagery.

  Shapefile coordinates are assumed to be UTM and curzone must be set.

  Parameters:
    filename: filename (including path) of ascii extent shapefile. 
      Usually named level_x_tile_extents.xyz, where x is the processing 
      level.
    dest: Destination filename for created KML.

  Options:
    name= A name for the linestring. Defaults to source filename.
    description= A description for the linestring.
      Defaults to "Tile Extents".
    visibility= Whether or not the line is visible when loaded. 
      Default is 1.
    Open= Whether or not the folder is open when loaded. Default is 0.
    linecolor= The color of the line, in AABBGGRR format
      (alpha-blue-green-red).  Default is ffff0000.
    linewidth= The width of the line. Default is 1.

  Original Christine Kranenburg 2011-11-30
*/

  default, visibility, "1";
  default, Open, "0";
  default, linecolor, "ffff0000";
  default, linewidth, "1";
  default, description, "Tile Extents";
  default, name, file_tail(filename);

  shp = read_ascii_shapefile(filename, meta);
  if ((*shp(1))(1) < 1000) {
    write, "\nWARNING: Shapefile coordinates are not UTM!! Exiting...\n";
    return;
  }

  polys = [];
  for (i = 1; i <= numberof(shp); i++) {
    ply = *shp(i);
    id=meta(noop(i)).TILE_NAME;
    curzone = atoi(strsplit(id, "_")(4));	// get curzone from tilename
    ll = utm2ll(ply(2,), ply(1,), curzone);
    grow, polys, kml_LineString(ll(,1), ll(,2), id=id, altitudeMode="clampToGround");
  }

  kml_save, dest, kml_Placemark(kml_Style(kml_LineStyle(color=linecolor, 
    width=linewidth)), kml_MultiGeometry(polys), name=name, 
    Open=Open, visibility=visibility, description=description);
}
