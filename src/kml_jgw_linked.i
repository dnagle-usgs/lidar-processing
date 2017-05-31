func kml_jgw_build_linked_product(dir, zone, levels=, searchstr=, timediff=,
name=, cir_soe_offset=, scan=, update=) {
  default, timediff, 60;

  if(is_void(scan)) {
    scan = jgw_scan(dir, searchstr=searchstr);
  }

  // Assign each image a timestamp for when its flightline starts
  soes = cir_to_soe(file_rootname(file_tail(scan.jgws))+".jpg", offset=cir_soe_offset);
  ptr = split_sequence_by_gaps(soes, gap=timediff);
  nptr = numberof(ptr);
  line_start = array(string, dimsof(soes));
  for(i = 1; i <= nptr; i++) {
    line_start(*ptr(i)) = soe2iso8601(soes(*ptr(i))(1));
  }

  // Create a KML for each line segment of each tile
  kml_seg = file_join(dir, file_dirname(scan.jgws), "doc.kml");

  seg_start = array(string, dimsof(soes));
  kml_segs = set_remove_duplicates(kml_seg);
  nsegs = numberof(kml_segs);
  for(i = 1; i <= nsegs; i++) {
    w = where(kml_seg == kml_segs(i));
    seg_start(w) = soe2iso8601(soes(w)(1));

    if(update && file_exists(kml_segs(i))) continue;

    subscan = obj_index(scan, w);
    overlays = kml_jgw_scan_overlays(dir, subscan, zone, levels=levels);

    kml_save, kml_segs(i), merge_pointers(overlays), name=seg_start(w(1));
  }
  kml_segs = [];

  // No longer need to reference jgws... now just reference kml_seg
  idx = unique(seg_start);
  kml_seg = kml_seg(idx);
  line_start = line_start(idx);
  seg_start = seg_start(idx);

  kml_dt = file_join(file_dirname(file_dirname(kml_seg)), "doc.kml");
  doc_dt = file_join(dir, "tiles_dt.kml");
  _kml_jgw_build_linked_product_linker, doc_dt, kml_dt, kml_seg, line_start, seg_start, update=update,
    name=name;

  kml_it = file_join(file_dirname(file_dirname(kml_dt)), "doc.kml");
  doc_it = file_join(dir, "tiles_it.kml");
  _kml_jgw_build_linked_product_linker, doc_it, kml_it, kml_seg, line_start, seg_start, update=update,
    name=name;
}

func _kml_jgw_build_linked_product_linker(kml_doc, kml_outs, kml_ins, line_start, seg_start, update=, name=) {
  // Get relative paths for kml_ins
  rel_ins = file_relative(file_dirname(kml_outs), kml_ins);

  // iterate over each output file
  u_out = set_remove_duplicates(kml_outs);
  nu_out = numberof(u_out);
  for(i = 1; i <= nu_out; i++) {
    if(update && file_exists(u_out(i))) continue;
    w1 = where(kml_outs == u_out(i));

    // iterate over each line in the output file
    if(numberof(w1) > 1) {
      line_num = (w1(dif) > 1)(cum);
    } else {
      line_num = [1];
    }
    u_line = set_remove_duplicates(line_num);
    nu_line = numberof(u_line);
    lines = array(string, nu_line);
    for(j = 1; j <= nu_line; j++) {
      w2 = w1(where(line_num == u_line(j)));

      nseg = numberof(w2);
      links = array(string, nseg);
      for(k = 1; k <= nseg; k++) {
        links(k) = kml_NetworkLink(
          kml_Link(href=rel_ins(w2(k))),
          name=seg_start(w2(k)));
      }

      if(numberof(links) == 1) {
        lines(j) = links(1);
      } else {
        lines(j) = kml_Folder(links, name=seg_start(w2(1)));
      }
    }

    kml_save, u_out(i), lines, name=file_tail(file_dirname(u_out(i)));
  }

  kml_outs = file_relative(file_dirname(kml_doc), set_remove_duplicates(kml_outs));
  tiles = file_tail(file_dirname(kml_outs));
  idx = sort(tiles);
  tiles = tiles(idx);
  kml_outs = kml_outs(idx);

  marks = kml_tiles_grid_marks(tiles, styleUrl="#marker");
  lines = kml_Placemark(kml_tiles_grid_lines(tiles));
  grid = kml_Folder(marks, lines, styleUrl="#collapse", name="Grid");

  nkmls = numberof(kml_outs);
  links = array(string, nkmls);
  for(i = 1; i <= nkmls; i++) {
    links(i) = kml_NetworkLink(
      kml_Link(href=kml_outs(i)),
      name=tiles(i),
      visibility=0, Open=0);
  }

  links = kml_Folder(links, name="Tiles", Open=1, visibility=0);

  style = [
    kml_Style("<IconStyle><Icon /></IconStyle>", id="marker"),
    kml_Style(kml_ListStyle(listItemType="checkHideChildren"), id="collapse")
  ];

  kml_save, kml_doc, style, grid, links, name=name, Open=1;
}
