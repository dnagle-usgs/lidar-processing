// vim: set ts=3 sts=3 sw=3 ai sr et:
require, "eaarl.i";

func analysis_extract_neighborhood(data, truth, mode=, truthmode=, radius=) {
   extern curzone;
   local x, y, z, tx, ty, tz;
   default, radius, 1.;
   radius = double(radius);
   // For our purposes, zone can be arbitrary but use curzone if it's defined
   zone = curzone ? curzone : 15;

   data2xyz, data, x, y, z, mode=mode;
   data2xyz, truth, tx, ty, tz, mode=truthmode;

   // eliminate data points outside of bbox+radius from truth points
   w = data_box(x, y, [tx(min),tx(max),ty(min),ty(max)] + radius*[-1,1,-1,1]);
   if(!numberof(w))
      error, "Points do not overlap";
   x = x(w);
   y = y(w);
   z = z(w);

   dist = match = array(pointer, numberof(tx));
   stack = deque();
   stack, push, save(t=indgen(numberof(tx)), d=indgen(numberof(x)),
      schemes=["it","dt","dtquad","dtcell"]);

   t0 = array(double, 3);
   timer, t0;
   tp = t0;
   while(stack(count,)) {
      top = stack(pop,);
      if(numberof(top.schemes)) {
         tiles = partition_by_tile(tx(top.t), ty(top.t), zone, top.schemes(1),
            buffer=0);
         names = h_keys(tiles);
         count = numberof(names);
         schemes = (numberof(top.schemes) > 1 ? top.schemes(2:) : []);
         for(i = 1; i <= count; i++) {
            t = top.t(tiles(names(i)));
            xmin = tx(t)(min) - radius;
            ymin = ty(t)(min) - radius;
            xmax = tx(t)(max) + radius;
            ymax = ty(t)(max) + radius;
            idx = data_box(x(top.d), y(top.d), xmin, xmax, ymin, ymax);
            if(numberof(idx)) {
               d = top.d(idx);
               stack, push, save(t, d, schemes);
            }
         }
      } else {
         X = x(top.d);
         Y = y(top.d);
         Z = z(top.d);
         count = numberof(top.t);
         for(i = 1; i <= count; i++) {
            j = top.t(i);
            idx = find_points_in_radius(tx(j), ty(j), X, Y, radius=radius);
            if(!numberof(idx))
               continue;

            xm = X(idx);
            ym = Y(idx);
            zm = Z(idx);

            dist(j) = &(((tx(j) - xm)^2 + (ty(j) - ym)^2) ^ .5);
            match(j) = &[xm, ym, zm];
         }
      }
      if(anyof(match))
         timer_remaining, t0, numberof(where(match)), numberof(match), tp, interval=10;
   }
   timer_finished, t0;
   return save(dist, match, truth=[tx,ty,tz], maxradius=radius);
}

func analysis_nearest_z(data, radius=) {
   bkp = restore(data);
   // dist, match, truth, radius

   count = numberof(match);
   found = array(char(1), count);
   result = array(double, count, 2);
   result(,1) = truth(,3);
   for(i = 1; i <= count; i++) {
      if(!match(i)) {
         found(i) = 0;
         continue;
      }
      pts = *match(i);
      if(radius) {
         w = where(*dist(i) <= radius);
         if(!numberof(w)) {
            found(i) = 0;
            continue;
         }
         pts = pts(w,);
      }
      zdif = abs(pts(,3) - result(i,1));
      result(i,2) = pts(,3)(zdif(mnx));
   }
   restore, bkp;

   w = where(found);
   if(!numberof(w))
      return [];
   return result(w,);
}
