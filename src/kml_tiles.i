func kml_tiles(kml, tiles, name=, visibility=, Open=, description=) {
/* DOCUMENT kml_tiles, kml, tiles, name=, visibility=, Open=, description=

  Creates a KML file for the given tiles.

  Parameters:
    kml: The destination file name
    tiles: An array of 2km or 10km tile names (for best results, do not mix 2km and 10km)
  Options:
    All options are passed through to kml_save.
*/
  style = kml_Style("<IconStyle><Icon /></IconStyle>", id="marker");

  marks = kml_Folder(
    kml_tiles_grid_marks(tiles, visibility="1", styleUrl="#marker"),
    name="Labels", visibility="1");

  lines = kml_Placemark(
    kml_tiles_grid_lines(tiles),
    name="Grid", visibility="1");

  kml_save, kml, style, lines, marks, name=name, visibility=visibility,
    Open=Open, description=description;
}

func kml_tiles_grid_marks(tiles, styleUrl=, visibility=) {
/* DOCUMENT kml_tiles_grid_marks(tiles, styleUrl=, visibility=)

  Creates an array of placemarks for the given tiles. Each placemark will be
  placed at the center of its tile and will be labeled with the tile's name.

  Parameter:
    tiles: An array of 2km or 10km tile names (for best results, do not mix 2km and 10km)
  Options:
    All options are passed through to kml_Placemark for each tile.

  Returns: An array of strings. Each entry is a placemark that corresponds to a
  tile in tiles.
*/
  lat = lon = [];
  ntiles = numberof(tiles);
  marks = array(pointer, ntiles);
  for(i = 1; i <= ntiles; i++) {
    c = tile2centroid(tiles(i));
    utm2ll, c(1), c(2), c(3), lon, lat;

    marks(i) = &kml_Placemark(
      kml_Point(lon, lat),
      name=tiles(i),
      styleUrl=styleUrl, visibility=visibility);
  }

  return merge_pointers(marks);
}

func kml_tiles_grid_lines(tiles) {
/* DOCUMENT kml_tiles_grid_lines(tiles)

  Creates a MultiGeometry that illustrates the bounds of the specified tiles.

  Parameter:
    tiles: An array of 2km or 10km tile names (for best results, do not mix 2km and 10km)

  Returns: A string. The string will be a MultiGeometry element containing
  multiple LineString elements.
*/
  ntiles = numberof(tiles);
  s = x = y = z = array(long, ntiles);
  for(i = 1; i <= ntiles; i++) {
    s(i) = tile_size(tiles(i));
    c = tile2centroid(tiles(i));
    x(i) = c(2);
    y(i) = c(1);
    z(i) = c(3);
  }

  idx = munique(s, z, x, y);
  s = s(idx);
  x = x(idx);
  y = y(idx);
  z = z(idx);

  lat = lon = [];
  lines = [];

  us = set_remove_duplicates(s);
  nus = numberof(us);
  for(is = 1; is <= nus; is++) {
    ws = where(s == us(is));

    uz = set_remove_duplicates(z(ws));
    nuz = numberof(uz);
    for(iz = 1; iz <= nuz; iz++) {
      wz = ws(where(z(ws) == uz(iz)));

      segs = kml_tiles_grid_lines_segments(x(wz), y(wz), us(is));
      nsegs = numberof(segs);
      curlines = array(pointer, nsegs);
      for(j = 1; j <= nsegs; j++) {
        seg = *segs(j);
        utm2ll, seg(,2), seg(,1), uz(iz), lon, lat;
        curlines(j) = &kml_LineString(lon, lat, tessellate=1);
      }
      grow, lines, &curlines;

      segs = kml_tiles_grid_lines_segments(y(wz), x(wz), us(is));
      nsegs = numberof(segs);
      curlines = array(pointer, nsegs);
      for(j = 1; j <= nsegs; j++) {
        seg = *segs(j);
        utm2ll, seg(,1), seg(,2), uz(iz), lon, lat;
        curlines(j) = &kml_LineString(lon, lat, tessellate=1);
      }
      grow, lines, &curlines;
    }
  }

  return kml_MultiGeometry(merge_pointers(merge_pointers(lines)));
}

func kml_tiles_grid_lines_segments(x1, x2, size) {
/* DOCUMENT kml_tiles_grid_lines_segments(x1, x2, size)
  Helper function for kml_tiles_grid_lines.
*/
  hsize = size / 2;

  // Get lower left and upper right corners
  x1 = grow(x1 - hsize, x1 + hsize);
  x2 = grow(x2 - hsize, x2 - hsize);

  // Merge lower and upper lines that are the same
  idx = munique(x1, x2);
  x1 = x1(idx);
  x2 = x2(idx);

  x1breaks = where(x1(dif));
  x2breaks = where(x2(dif) != size);
  breaks = set_remove_duplicates(grow(x1breaks, x2breaks));

  b0 = grow(1, breaks+1);
  b1 = grow(breaks, numberof(x1));
  nb = numberof(b0);
  segments = array(pointer, nb);

  for(i = 1; i <= nb; i++) {
    cx1 = x1(b0(i):b1(i));
    cx2 = x2(b0(i):b1(i));

    grow, cx1, cx1(0);
    grow, cx2, cx2(0) + size;

    segments(i) = &[cx1, cx2]
  }

  return segments;
}
