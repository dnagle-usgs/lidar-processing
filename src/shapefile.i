/* vim: set tabstop=3 softtabstop=3 shiftwidth=3 autoindent shiftround expandtab: */
write, "$Id$";

func read_ascii_shapefile(filename) {
   f = open(filename, "r");
   shp = array(pointer, 8);
   shp_idx = 0;
   state = "TOP";
   ary = [];
   while(1) {
      line = rdline(f);
      if(strglob("*=*", line)) {
         if(state == "TOP" || state == "ATTR") {
            // do nothing with the data
            state = "ATTR";
         } else {
            // invalid
            error, "Unexpected attribution in " + state;
         }
      } else if(strglob("*,*", line)) {
         if(state == "TOP" || state == "ATTR" || state == "COORD") {
            // grow coordinates
            if(regmatch("^ *(-?[0-9]+\.?[0-9]*), *(-?[0-9]+\.?[0-9]*)(,|$)",
                  line, , x, y)) {
               x = atod(x);
               y = atod(y);
               grow, ary, [[x,y]];
               state = "COORD";
            } else {
               // invalid
               error, "Unexpected non-coordinate in " + state;
            }
         } else {
            // invalid
            error, "Unexpected coordinate in " + state;
         }
      } else if(!line || regmatch("^[ \t\n\r]*$", line)) {
         if(state == "COORD") {
            shp_idx++;
            if(shp_idx > numberof(shp)) {
               grow, shp, shp;
            }
            shp(shp_idx) = &ary;
            ary = [];
            if(!line) {
               break;
            } else {
               state = "TOP";
            }
         } else if(state == "TOP") {
            if(!line) {
               break;
            }
         } else {
            if(!line) {
               error, "Unexpected EOF in " + state;
            } else {
               error, "Unexpected blank line in " + state;
            }
         }
      } else {
         // Invalid
         error, "Unexpected unknown in " + state;
      }
   }
   close, f;
   shp = shp(:shp_idx);
   return shp;
}

func write_ascii_shapefile(shp, filename, meta=) {
   f = open(filename, "w");
   for(i = 1; i <= numberof(shp); i++) {
      if(!is_void(meta)) {
         write, f, format="%s", meta(i);
      }
      write, f, format="%.3f,%.3f\n", (*shp(i))(1,), (*shp(i))(2,);
      write, f, format="%s", "\n";
   }
   close, f;
}

func plot_shape(shp, color=, width=) {
   for(i = 1; i <= numberof(shp); i++) {
      plg, (*shp(i))(2,), (*shp(i))(1,), marks=0, color=color, width=width;
   }
}

func shape_stats(shp) {
   write, format="Number of polys: %d\n", numberof(shp);
   points = 0;
   for(i = 1; i <= numberof(shp); i++) {
      write, format="  %d: %d points\n", i, numberof((*shp(i))(1,));
      points += numberof((*shp(i))(1,));
   }
   write, format="Number of total points: %d\n", points;
}

func print_shape(shp, idx) {
   if(idx) {
      write, format="%.2f, %.2f\n", (*shp(idx))(1,), (*shp(idx))(2,);
   } else {
      for(i = 1; i <= numberof(shp); i++) {
         write, format="Poly %i\n", i;
         print_shape, shp, i;
         write, " ";
      }
   }
}

func add_shapefile(filename) {
   extern _shp_polys;
   extern _shp_files;

   shp = read_ascii_shapefile(filename);
   if(is_void(_shp_polys)) {
      _shp_polys = array(pointer, 1);
      _shp_files = array(string, 1);
      _shp_polys(1) = &shp;
      _shp_files(1) = filename;
   } else {
      grow, _shp_polys, &shp;
      grow, _shp_files, filename;
   }
}

func plot_shapefiles(void) {
   extern _shp_polys;
   if(is_void(_shp_polys))
      return;
   for(i = 1; i <= numberof(_shp_polys); i++) {
      plot_shape, *_shp_polys(i);
   }
}

func remove_shapefile(filename) {
   extern _shp_polys;
   extern _shp_files;

   if(is_void(_shp_polys) || is_void(_shp_files)) {
      _shp_files = _shp_files = [];
      return;
   }

   w = where(_shp_files != filename);
   if(numberof(w)) {
      _shp_polys = _shp_polys(w);
      _shp_files = _shp_files(w);
   } else {
      _shp_polys = _shp_files = [];
   }
}

func shapefile_limits(void) {
   extern _shp_polys;
   minx = miny =  1e+100;
   maxx = maxy = -1e+100;
   
   for(i = 1; i <= numberof(_shp_polys); i++) {
      for(j = 1; j <= numberof(*_shp_polys(i)); j++) {
         minx = min( (*(*_shp_polys(i))(j))(1,min), minx );
         maxx = max( (*(*_shp_polys(i))(j))(1,max), maxx );
         miny = min( (*(*_shp_polys(i))(j))(2,min), miny );
         maxy = max( (*(*_shp_polys(i))(j))(2,max), maxy );
      }
   }
   
   xdif = (maxx - minx)/100;
   ydif = (maxy - miny)/100;
   minx -= xdif;
   maxx += xdif;
   miny -= ydif;
   maxy += ydif;

   data_aspect = (maxx-minx)/(maxy-miny);

   temp = viewport()(dif)(1:3:2);
   plot_aspect = temp(1)/temp(2);

   limits, square=1;

   if (data_aspect < plot_aspect) {
      x = [minx,maxx](avg) - (maxy-miny)*plot_aspect/2;
      limits, x, "e", miny, maxy;
   } else {
      y = [miny,maxy](avg) - (maxx-minx)/plot_aspect/2;
      limits, minx, maxx, y, "e";
   }
}

func polygon_acquire(closed) {
   if(closed)
      type = "polygon";
   else
      type = "polyline";

   prompt = swrite(format="Left click generates a vertice. " +
      "CTRL+Left or CTRL+Middle click will close %s.", type);
   poly = array(float, 2, 1);
   result = mouse(1, 0, prompt);
   poly(,1) = result(1:2);
   plmk, poly(2,0), poly(1,0), marker=4, msize=.4, width=10, color="red";

   prompt = swrite(format="Left click generates another vertice. " +
      "CTRL+Left or Middle click will close %s.", type);

   while(!((result(11) == 4 && result(10) == 1) || result(10) == 2)) {
      result = mouse(1, 2, prompt);
      grow, poly, result(1:2);
      plmk, poly(2, 0), poly(1, 0), marker=4, msize=.3, width=10;
      plg, poly(2,-1:0), poly(1, -1:0), marks=0;
   }
   write, format="Closed %s with %d vertices.\n", type, numberof(poly(1,));
   if(closed) {
      grow, poly, poly(,1);
      plg, poly(2,-1:0), poly(1, -1:0), marks=0;
   }
   return poly;
}


func polygon_add(poly, name) {
   extern _poly_polys;
   extern _poly_names;

   if(is_void(poly))
      return;

   if(is_void(_poly_polys)) {
      _poly_polys = array(pointer, 1);
      _poly_names = array(string, 1);
      _poly_polys(1) = &poly;
      _poly_names(1) = name;
   } else {
      grow, _poly_polys, &poly;
      grow, _poly_names, name;
   }
}

func polygon_remove(name) {
   extern _poly_polys;
   extern _poly_names;

   if(is_void(_poly_polys) || is_void(_poly_names)) {
      _poly_files = _poly_files = [];
      return;
   }

   w = where(_poly_names != name);
   if(numberof(w)) {
      _poly_polys = _poly_polys(w);
      _poly_names = _poly_names(w);
   } else {
      _poly_polys = _poly_names = [];
   }
}

func polygon_plot(void) {
   extern _poly_polys;
   if(is_void(_poly_polys))
      return;
   plot_shape, _poly_polys;
}

func polygon_write(filename) {
   extern _poly_polys;
   extern _poly_names;
   meta = _poly_names;
   meta = "NAME=" + meta + "\n";
   write_ascii_shapefile, _poly_polys, filename, meta=meta;
}
