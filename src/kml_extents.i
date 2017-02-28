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
*/

  default, searchstr, "*_tile_extents.xyz";
  default, desc, "Tile Extents";

  if (is_void(name)) autoname = 1;

  cur = find(datadir, searchstr=searchstr);
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

  type_names = save(
    dt="2km Tiles", it="10km Tiles", qq="Quarter Quad Tiles"
  );
  best_type = 4;
  for(i = 1; i <= numberof(shp); i++) {
    tile = meta(noop(i)).TILE_NAME;
    if(!tile) continue;
    type = tile_type(tile);
    if(!type) continue;
    if(type_names(*,type) < best_type) best_type = type_names(*,type);
    if(best_type == 1) break;
  }

  // Only let at most one type be visible at load
  vis = array(visibility, numberof(shp));
  if(best_type < 4 && visibility != "0") {
    for(i = 1; i <= numberof(vis); i++) {
      tile = meta(noop(i)).TILE_NAME;
      if(!tile) continue;
      type = tile_type(tile);
      if(!type) continue;
      if(type_names(*,type) != best_type) vis(i) = "0";
    }
  }

  tiles = save();
  marks = save();
  for(i = 1; i <= numberof(shp); i++) {
    ply = *shp(i);
    tile = meta(noop(i)).TILE_NAME;
    if(!tile) continue;
    type = tile_type(tile);
    if(!type) continue;
    zone = tile2uz(tile);
    ll = utm2ll(ply(2,), ply(1,), zone);

    mark = kml_Placemark(
      kml_Style(kml_LineStyle(color=linecolor, width=linewidth)),
      kml_LineString(ll(,1), ll(,2), altitudeMode="clampToGround"),
      name=tile, visibility=vis(i)
    );

    if(!tiles(*,type)) save, tiles, noop(type), save(boxes=[], marks=[]);
    save, tiles(noop(type)), boxes=grow(tiles(noop(type)).boxes, mark);

    spot = tile2centroid(tile);
    ll = utm2ll(spot(1), spot(2), spot(3));
    mark = kml_Placemark(kml_Point(ll(1), ll(2)), name=tile,
      styleUrl="#marker", visibility="0");

    save, tiles(noop(type)), marks=grow(tiles(noop(type)).marks, mark);
  }

  if(!tiles(*)) {
    write, "WARNING: No tile names detected, aborting";
    return;
  }

  for(i = 1; i <= tiles(*); i++) {
    tile = tiles(noop(i));
    type = type_names(tiles(*,i));
    visible = vis(type_names(*,type));
    save, tiles, noop(i), kml_Folder(
      kml_Folder(tile.boxes, name="Extents", visibility=visible),
      kml_Folder(tile.marks, name="Markers", visibility="0"),
      name=type_names(tiles(*,i)), visibility=visible
    );
  }

  style = kml_Style(
    kml_IconStyle(
      href="http://maps.google.com/mapfiles/kml/shapes/placemark_circle.png"
    ),
    id="marker"
  );
  folder = kml_Folder(obj2array(tiles), name=name, Open=Open,
    visibility=visibility, description=description);

  kml_save, dest, style, folder;
  kmz = file_rootname(dest) + ".kmz";
  kmz_create, kmz, dest;
}
