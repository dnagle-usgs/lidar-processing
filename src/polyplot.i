// vim: set ts=2 sts=2 sw=2 ai sr et:

local polyplot;
/* DOCUMENT polyplot
  Framework for working with poly data. Intended to be driven by the GUI.
*/

scratch = save(scratch);

// Avoid clobbering existing data in case the file is re-sourced after polys
// are added.
if(is_void(polyplot)) polyplot = save();
if(!polyplot(*,"data")) polyplot, data=save(Local=save());

// Cache regular expressions and mappings that are used a bunch
polyplot, re_color = regcomp("[rR][gG][bB]\\(([0-9]+),([0-9]+),([0-9]+)\\)");
polyplot, re_num = regcomp("[0-9]+$");
polyplot, colormap_val = [0x000000, 0xFFFFFF, 0xFF0000, 0x00FF00, 0x0000FF,
  0x00FFFF, 0xFF00FF, 0xFFFF00];
polyplot, colormap_name = ["black", "white", "red", "green", "blue",
  "cyan", "magenta", "yellow"];

save, scratch, poly_validate_name;
func polyplot_validate_name(name, extra=) {
/* DOCUMENT polyplot, validate_name, "<name>", extra=
  Primarly for internal use. Validates and, if necessary, changes the given
  NAME to ensure it does not conflict with any existing names. A restriction is
  imposed that requires that each name is unique across all polys and groups.

  If extra= is provided, it should be an array of strings. These are additional
  names that NAME should not collide with. This is intended for internal use
  when building up new data to be added.
*/
  use, data, re_num;

  // Collect poly names
  current = array(pointer, data(*));
  for(i = 1; i <= data(*); i++) {
    current(i) = &data(noop(i))(*,);
  }
  current = merge_pointers(current);
  // Add group names and extra names
  grow, current, data(*,);
  if(!is_void(extra)) grow, current, extra;

  // If NAME is unique, we're done
  if(noneof(current == name)) return name;

  // If NAME ends with a numerical string, separate it off. Otherwise, pretend
  // it ended in 1.
  num = [];
  if(regmatch(re_num, name, num)) {
    base = strpart(name, :-strlen(num));
    num = atoi(num);
  } else {
    base = name;
    num = 1;
  }

  // Search for the next numbered name that does not yet exist
  do {
    name = swrite(format="%s%d", base, ++num);
  } while(anyof(current == name));

  return name;
}
polyplot, validate_name=polyplot_validate_name;

save, scratch, polyplot_add;
func polyplot_add(group, name, win=, closed=) {
/* DOCUMENT polyplot, add, "<group>"
  -OR- polyplot, add, "<group>", "<name>", win=, closed=

  In the first form, adds a new group with the given name. If GROUP is not
  unique, the name will be updated to the next sequential name that is unique.

  In the second form, adds a new poly with the given name. The user will be
  prompted to draw a polyon in WIN. CLOSED specifies whether the new poly
  should be open or closed. GROUP must already exist. If NAME is not unique, it
  will be updated to the next sequential name that is unique.
*/
  use, data;

  if(!data(*,group)) {
    save, data, noop(group), save();

    if(is_void(name)) {
      use_method, tksync;
      use_method, tksel, group;
      return;
    }
  } else if(is_void(name)) {
    use_method, warn, "A group named \""+group+"\" already exists.";
    return;
  }

  ply = get_poly(closed=closed, win=win);
  if(is_void(ply)) return;

  orig_name = name;
  name = use_method(validate_name, name);
  if(orig_name != name) {
    use_method, warn, "A poly named \""+orig_name+"\" already exists; using \""+name+"\" instead.";
  }

  save, data(noop(group)), noop(name),
    save(ply, closed, color="black", width=1);

  use_method, tksync;
  use_method, tksel, name;

  next_name = use_method(validate_name, name);
  tkcmd, swrite(format="::plot::poly_add_callback {%s} {%s}", name, next_name);
}
polyplot, add=polyplot_add;

save, scratch, polyplot_remove;
func polyplot_remove(group, name) {
/* DOCUMENT polyplot, remove, "<group>"
  -OR- polyplot, remove, "<group>", "<name>"

  In the first form, removes a group (and all polys that it may contain).

  In the second form, removes a single poly.
*/
  use, data;

  if(is_void(group)) {
    error, "invalid call, must specify group";
  } else if(!data(*,group)) {
    use_method, warn, "No such group exists";
  } else if(is_void(name)) {
    data = obj_delete(data, noop(group));
    use_method, tksync;
  } else if(!data(noop(group),*,name)) {
    use_method, warn, "No such poly exists";
  } else {
    save, data, noop(group), obj_delete(data(noop(group)), noop(name));
    use_method, tksync;
  }
}
polyplot, remove=polyplot_remove;

save, scratch, polyplot_rename;
func polyplot_rename(a, b, c) {
/* DOCUMENT polyplot, rename, "<group_old>", "<group_new>"
  -OR- polyplot, rename, "<group>", "<name_old>", "<name_new>"

  In the first form, renames the specified group to a new name. The new name
  must be unique.

  In the second form, renames the specified poly to a new name. The new name
  must be unique.
*/
  use, data;

  if(is_void(a) || is_void(b)) {
    // error!
    return;
  }

  if(is_void(c)) {
    group_old = a;
    group_new = b;

    if(!data(*,group_old)) {
      // warn!
    } else if(data(*,group_new)) {
      // warn!
    } else {
      idx = indgen(data(*));
      save, data, noop(group_new), data(noop(group_old));
      idx(data(*,group_old)) = data(*);
      data = data(noop(idx));
      use_method, tksync;
    }
  } else {
    group = a;
    name_old = b;
    name_new = c;

    if(!data(*,group)) {
      // warn!
    } else if(!data(noop(group), *, noop(name_old))) {
      // warn!
    } else if(data(noop(group), *, noop(name_new))) {
      // warn!
    } else {
      grp = data(noop(group));
      idx = indgen(grp(*));
      save, grp, noop(name_new), grp(noop(name_old));
      idx(grp(*,name_old)) = grp(*);
      save, data, noop(group), grp(noop(idx));
      use_method, tksync;
    }
  }
}
polyplot, rename=polyplot_rename;

save, scratch, polyplot_update;
func polyplot_update(group, name, closed=, color=, width=) {
/* DOCUMENT polyplot, update, "<group>", closed=, color=, width=
  -OR- polyplot, update, "<group>", "<name>", closed=, color=, width=

  In the first form, all polys in the specified GROUP will be updated with the
  provided CLOSED, COLOR, and/or WIDTH values.

  In the second form, the specified poly will be updated with the provided
  CLOSED, COLOR, and/or WIDTH values.

  In both forms, any omitted options are left unchanged.
*/
  use, data;

  if(!is_void(closed)) {
    closed = atoi(closed);
  }
  if(!is_void(width)) {
    width = atoi(width);
  }

  grp = data(noop(group));
  if(is_void(name)) {
    name = grp(*,);
  }
  for(i = 1; i <= numberof(name); i++) {
    p = grp(name(i));
    if(!is_void(closed))
      save, p, closed;
    if(!is_void(color))
      save, p, color;
    if(!is_void(width))
      save, p, width;
  }
  use_method, tksync;
}
polyplot, update=polyplot_update;

save, scratch, polyplot_raise_or_lower;
func polyplot_raise_or_lower(dir, group, name) {
/* DOCUMENT polyplot, raise, "<group>"
  -OR- polyplot, lower, "<group>"
  -OR- polyplot, raise, "<group>", "<name>"
  -OR- polyplot, lower, "<group>", "<name>"

  In the first two forms, the specified GROUP is raised or lowered in the
  sequence of groups. The polys within that group are kept in their existing
  order.

  In the last two forms, the specified poly is raised or lowered in the
  sequence of polys. This may result in the poly being raised into the
  preceding group or lowered into the following group if it is at the top or
  bottom of its current group's sequence.
*/
  use, data;

  if(is_void(name)) {
    idx = data(*,group);
    if(!idx) {
      // not found
    }
    // First or last, do nothing
    if(dir == -1 && idx == 1) return;
    if(dir == 1 && idx == data(*)) return;
    w = indgen(data(*));
    w([idx,idx+dir]) = w([idx+dir,idx]);
    data = data(noop(w));
  } else {
    gidx = data(*,group);
    if(!idx) {
      // not found
    }
    grp = data(noop(group));
    nidx = grp(*,name);
    if(!nidx) {
      // not found
    }
    shiftgroup = 0;
    if(dir == -1 && nidx == 1) {
      if(gidx == 1) return;
      // move to previous group
      shiftgroup = 1;
    } else if(dir == 1 && nidx == grp(*)) {
      if(gidx == data(*)) return;
      // move to next group
      shiftgroup = 1;
    }
    if(shiftgroup) {
      newgrp = data(gidx+dir);
      save, newgrp, noop(name), grp(noop(name));
      if(dir == 1 && newgrp(*) > 1) {
        save, data, noop(gidx+dir), newgrp(long(roll(indgen(newgrp(*)), 1)));
      }
      save, data, noop(group), obj_delete(grp, noop(name));
    } else {
      w = indgen(grp(*));
      w([nidx,nidx+dir]) = w([nidx+dir,nidx]);
      save, data, noop(group), grp(noop(w));
    }
  }
  use_method, tksync;
}
polyplot, raise=closure(polyplot_raise_or_lower, -1);
polyplot, lower=closure(polyplot_raise_or_lower, 1);

save, scratch, polyplot_plot;
func polyplot_plot(group, name, win=, highlight=) {
/* DOCUMENT polyplot, plot, win=, highlight=
  -OR- polyplot, plot, "<group>", win=, highlight=
  -OR- polyplot, plot, "<group>", "<name>", win=, highlight=

  In the first form, plots all polys from all groups.

  In the second form, plots all polys from the specified GROUP.

  In the third form, plots the specified poly.

  For all forms, WIN specifies which window to plot in; if omitted, the current
  window is used. If HIGHLIGHT is specifed, the line width will be increased
  and the vertices of all polys will be marked with dots to help highlight the
  polys. Otherwise, polys are plotted using their defined width, color, and
  closed settings.
*/
  use, data, re_color;

  if(is_void(group)) {
    for(i = 1; i <= data(*); i++)
      use_method, plot, data(*,i), win=win, highlight=highlight;
  } else if(is_void(name)) {
    grp = data(noop(group));
    for(i = 1; i <= grp(*); i++)
      use_method, plot, group, grp(*,i), win=win, highlight=highlight;
  } else {
    work = data(noop(group), noop(name));
    color = work.color;
    r = g = b = [];
    if(regmatch(re_color, color, , r, g, b)) color = atoi([r,g,b]);
    width = work.width;
    if(highlight) width += 3;
    ply = work.ply;
    if(work.closed && (ply(1,1) != ply(1,0) || ply(2,1) != ply(2,0))) {
      grow, ply, ply(,1);
    }

    wbkp = current_window();
    window, win;
    plot_poly, ply, color=color, width=width, vertices=highlight;
    window_select, win;
  }
}
polyplot, plot=polyplot_plot;

save, scratch, polyplot_exists;
func polyplot_exists(group, name, empty=) {
/* DOCUMENT bool = polyplot(exists,);
  -or- bool = polyplot(exists, "<group>");
  -or- bool = polyplot(exists, "<group>", "<name>");

  -or- bool = polyplot(exists, ["", ""]);
  -or- bool = polyplot(exists, ["<group>", ""]);
  -or- bool = polyplot(exists, ["<group", "<name>"]);

  Returns 1 if the specified poly or shapefile is defined and contains poly
  data, or 0 otherwise. Alternately, you can specify empty=1 to only check if
  the poly or shapefile is defined.

  There are two ways you can call polyplot(exists,). The first way is to pass
  it zero, one, or two scalar string arguments. The second way is to pass it a
  two-element string array. These possibilities are shown in the example syntax
  above; the first three examples provide the same output as the last three
  examples.

  The two-element string array is to make it easier to specific a poly through
  a calling function. If both strings are zero-length, then it retrieves all
  polys. If only the second string is zero-length, then a single group's polys
  are retrieved. If neither string is zero-length, then a specific poly in a
  specific group is retrieved.
*/
  if(numberof(group) == 2) {
    if(strlen(group(2)))
      return polyplot(exists, group(1), group(2), empty=empty);
    if(strlen(group(1)))
      return polyplot(exists, group(1), empty=empty);
    return polyplot(exists, empty=empty);
  }

  default, empty, 0;
  use, data;

  if(is_void(group)) {
    if(empty) return 1;
    if(!data(*)) return 0;
    for(i = 1; i <= data(*); i++) {
      if(polyplot(exists, data(*,i))) return 1;
    }
    return 0;
  }

  if(is_void(name)) {
    if(empty) return data(*,group) > 0;
    if(!data(*,group)) return 0;
    grp = data(noop(group));
    if(!grp(*)) return 0;
    for(i = 1; i <= grp(*); i++) {
      if(polyplot(exists, group, grp(*,i))) return 1;
    }
    return 0;
  }

  if(!data(*,group)) return 0;
  if(!data(noop(group), *, name)) return 0;
  if(empty) return 1;
  item = data(noop(group), noop(name));
  return numberof(item.ply) > 0;
}
polyplot, exists=polyplot_exists;

save, scratch, polyplot_get;
func polyplot_get(group, name) {
/* DOCUMENT shp = polyplot(get,);
  -or- shp = polyplot(get, "<group>");
  -or- ply = polyplot(get, "<group>", "<name>");

  -or- shp = polyplot(get, ["", ""]);
  -or- shp = polyplot(get, ["<group>", ""]);
  -or- ply = polyplot(get, ["<group", "<name>"]);

  Retrieves a poly or a shapefile (array of polys) defined in the Plotting
  Tool.

  There are two ways you can call polyplot(get,). The first way is to pass it
  zero, one, or two scalar string arguments. The second way is to pass it a
  two-element string array. These possibilities are shown in the example syntax
  above; the first three examples provide the same output as the last three
  examples.

  The two-element string array is to make it easier to specific a poly through
  a calling function. If both strings are zero-length, then it retrieves all
  polys. If only the second string is zero-length, then a single group's polys
  are retrieved. If neither string is zero-length, then a specific poly in a
  specific group is retrieved.
*/
  if(numberof(group) == 2) {
    if(strlen(group(2)))
      return polyplot(get, group(1), group(2));
    if(strlen(group(1)))
      return polyplot(get, group(1));
    return polyplot(get,);
  }

  use, data;

  if(is_void(group)) {
    if(!data(*)) return [];
    tmp = array(pointer, data(*));
    for(i = 1; i <= data(*); i++) {
      tmp(i) = &polyplot(get, data(*,i));
    }
    return merge_pointers(tmp);
  }

  if(is_void(name)) {
    grp = data(noop(group));
    if(!grp(*)) return [];
    shp = array(pointer, grp(*));
    for(i = 1; i <= grp(*); i++) {
      shp(i) = &polyplot(get, group, grp(*,i));
    }
    return shp;
  }

  item = data(noop(group), noop(name));
  ply = item.ply;

  // If it's a closed poly, make sure it has the closing line
  if(item.closed && (ply(1,1) != ply(1,0) || ply(2,1) != ply(2,0))) {
    grow, ply, ply(,1);
  }

  return ply;
}
polyplot, get=polyplot_get;

save, scratch, polyplot_limits;
func polyplot_limits(void, win=, geo=, expand=, square=) {
/* DOCUMENT polyplot, limits, win=, geo=, expand=, square=
  Wrapper around region_limits that calls it with polyplot's data. However,
  expand is set to 0.02 by default.
*/
  default, expand, 0.02;
  shp = polyplot(get,);
  if(is_void(shp)) {
    write, "no polys defined; aborting";
    return;
  }
  region_limits, shp, win=win, geo=geo, expand=expand,
    square=square;
}
polyplot, limits=polyplot_limits;

save, scratch, polyplot_export;
func polyplot_export(group, file, geo=, meta=) {
/* DOCUMENT polyplot, export, "<group>", "<file>", geo=, meta=
  Exports polys from the specified GROUP to the specified FILE in ASCII
  shapefile format.

  By default, all polys are exported as UTM. Use geo=1 to force export using
  geographic coordinates; make sure curzone is set.

  By default, each poly will be preceded by metadata (name, line width, line
  color, and closed). To disable this, use meta=0.
*/
  use, data, colormap_name, colormap_val;
  default, geo, 0;
  default, meta, 1;

  grp = data(noop(group));

  md = [];
  if(meta) {
    md = "NAME=" + grp(*,) + "\n";
    for(i = 1; i <= grp(*); i++) {
      item = grp(noop(i));
      color = item.color;
      w = where(color == colormap_name);
      if(numberof(w)) {
        w = w(1);
        r = (colormap_val(w) >> 16) & 255;
        g = (colormap_val(w) >> 8) & 255;
        b = (colormap_val(w)) & 255;
        color = swrite(format="RGB(%d,%d,%d)", r, g, b);
      }
      closed = item.closed ? "CLOSED=YES\n" : "";
      md(i) += swrite(format="LINE_WIDTH=%d\nLINE_COLOR=%s\n%s",
        long(item.width), color, closed);
    }
  }

  shp = array(pointer, grp(*));
  for(i = 1; i <= grp(*); i++) {
    shp(i) = &grp(noop(i), ply);
  }

  write_ascii_shapefile, shp, file, meta=md, geo=geo, utm=!geo;
}
polyplot, export=polyplot_export;

save, scratch, polyplot_import;
func polyplot_import(file) {
/* DOCUMENT polyplot, import, "<file>"
  Imports polys from the specified FILE, which must be an ASCII shapefile. If
  the shapefile contains metadata for poly name, color, width, or closed, the
  information will be used to initialize the poly; otherwise, suitable defaults
  are used.
*/
  use, data, re_color, colormap_val, colormap_name;
  local meta;

  shp = read_ascii_shapefile(file, meta);
  if(is_void(shp)) {
    // none found
    // warn?
    return;
  }

  fields = save(
    name=["NAME", "LABEL", "TILE_NAME"],
    color=["LINE_COLOR", "LINE COLOR", "BORDER_COLOR", "BORDER COLOR",
      "PEN_COLOR", "PEN COLOR"],
    width=["LINE_WIDTH", "LINE WIDTH", "BORDER_WIDTH", "BORDER WIDTH",
      "PEN_WIDTH", "PEN WIDTH"],
    closed=["CLOSED"]
  );
  fcount = 4;
  fkeys = fields(*,);

  grp = save();
  count = numberof(shp);
  for(i = 1; i <= count; i++) {
    new = save();
    for(j = 1; j <= fcount; j++) {
      fvals = fields(fkeys(j));
      idx = meta(noop(i))(*,fields(fkeys(j)));
      w = where(idx);
      if(numberof(w)) {
        save, new, fkeys(j), meta(noop(i))(idx(w(1)));
      }
    }

    ply = *shp(i);

    // If no metadata is provided, initialize closed based on whether the poly
    // forms a closed polygon.
    if(meta(*) == 0 && ply(1,1) == ply(1,0) && ply(2,1) != ply(2,0)) {
      save, new, closed="YES";
    }

    keydefault, new, color="black", width="1", closed="NO", name="poly1";
    name = use_method(validate_name, new.name, extra=grp(*,));
    obj_delete, new, name;

    save, new, ply;
    save, new, width = atoi(new.width);
    save, new, closed = anyof(strcase(1,new.closed) == ["TRUE","YES"]);

    r = g = b = [];
    if(regmatch(re_color, new.color, , r, g, b)) {
      rgb = (atoi(r) << 16) + (atoi(g) << 8) + atoi(b);
      w = where(rgb == colormap_val);
      if(numberof(w)) {
        save, new, color=colormap_name(w(1));
      }
    } else {
      color = strcase(0,new.color);
      if(noneof(colormap_name == color)) {
        save, new, color="black";
      }
    }

    save, grp, noop(name), new;
  }

  group = use_method(validate_name, file_tail(file), extra=grp(*,));
  save, data, noop(group), grp;
  use_method, tksync;
  use_method, tksel, group;
}
polyplot, import=polyplot_import;

save, scratch, polyplot_tksel;
func polyplot_tksel(item) {
/* DOCUMENT polyplot, tksel, "<item>"
  Internal function. Tells Tcl/Tk to select the given ITEM in the treeview.
  ITEM may be either a group or a poly.
*/
  // This is sometimes used after other commands that trigger idle events that
  // update the selection. Thus it needs an additional delay.
  tkcmd, swrite(format="after 1 {after idle {::plot::poly_select {%s}}}", item);
}
polyplot, tksel=polyplot_tksel;

save, scratch, polyplot_warn;
func polyplot_warn(msg) {
/* DOCUMENT polyplot, warn, "<msg>"
  Internal function. Used to give the user a warning via Tcl/Tk.
*/
  if(!_ytk) write, format="%s\n", msg;
  else tkcmd, swrite(format="::plot::warnmsg {%s}", msg);
}
polyplot, warn=polyplot_warn;

save, scratch, polyplot_err;
func polyplot_err(msg) {
/* DOCUMENT polyplot, err, "<msg>"
  Internal function. Used to give the user an error via Tcl/Tk.
*/
  if(!_ytk) write, format="%s\n", msg;
  else tkcmd, swrite(format="::plot::errmsg {%s}", msg);
}
polyplot, err=polyplot_err;

save, scratch, polyplot_tksync;
func polyplot_tksync(void) {
/* DOCUMENT polyplot, tksync
  Sends update information to Tcl/Tk to keep it in sync with Yorick. Primarily
  intended for internal use, but may be used externally if things get out of
  sync somehow.
*/
  use, data;
  tmp = save();
  for(i = 1; i <= data(*); i++) {
    grp = data(noop(i));
    work = save();
    for(j = 1; j <= grp(*); j++) {
      save, work, grp(*,j), obj_delete(grp(noop(j)), "ply");
    }
    save, tmp, data(*,i), work;
  }
  tkcmd, swrite(format="::plot::poly_sync {%s}", json_encode(tmp));
}
polyplot, tksync=polyplot_tksync;

restore, scratch;
