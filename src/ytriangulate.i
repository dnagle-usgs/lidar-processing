/* 
  $Id$
*/

write, "$Id$";
  
/* DELAUNAY TRIANGULATION procedure
  adapted from Paul Bourke's C source code available at
  http://astronomy.swin.edu.au/~pbourke/terrain/triangulate/
*/

struct ITRIANGLE {
   int p1,p2,p3;
}

struct IEDGE {
   int p1,p2;
}

struct XYZ {
   double x,y,z;
}

FALSE = 0;
TRUE = 1;
EPSILON = 1e-6;


func triangulate_xyz(file=, savefile=, data=, plot=, mode=, win=, distthresh=, dolimits=) {
/*DOCUMENT prepare_xyz(file=, savefile=, data=, plot=, mode=) 
  amar nayegandhi 01/05/03.
 */
  
  if (is_void(win)) win = 0; // default window to plot triangulations
  if (is_void(mode)) mode = 3; // default to bare earth
  //elapsed = elapsed1 = array(double, 3);
  //timer, elapsed;
  extern xyz, pxyz, ntri;
  if (!is_void(file)) {
     ipath = split_path(file,0)(1);
     ifname = split_path(file,0)(2);
     xyz = read_ascii_xyz(ipath=ipath,ifname=ifname);
  }

  if (is_array(data)) {
     if (mode == 3) {
       xyz = [data.least/100., data.lnorth/100., (data.lelv)/100.];
     } 
     if (mode == 2) {
       xyz = [data.east/100., data.north/100., (data.elevation+data.depth)/100.];
     }
     if (mode == 1) {
       xyz = [data.east/100., data.north/100., (data.elevation)/100.];
     }
     xyz = transpose(xyz);
  }
  write, format="Total Points Read = %d\n",numberof(xyz(1,));
  if (numberof(xyz(1,)) < 4) return [];


/*
 // not sure if I need to this sort and search for duplicate points ...
  xyz = xyz(,sort(xyz(1,)));
  // check for duplicate points
  idx = where(xyz(1,dif) == 0);
  if (is_array(idx)) {
     idx1 = where(xyz(2,idx) == xyz(2,idx+1));
     if (is_array(idx1)) {
        xyz(,idx(idx1)) = 0;
        xyz = xyz(,where(xyz(1,)!=0));
     }
  }
*/
  nv = numberof(xyz(1,));  
  //pxyz = array(long, 3, nv);
  //pxyz.x = xyz(1,);
  //pxyz.y = xyz(2,);
  //pxyz.z = xyz(3,);
  //pxyz = grow(xyz, array(double,3,3));

  //pxyz = pxyz(sort(pxyz.x));
  // using C version of triangulate function...
  //v = triangulate(nv, pxyz);
  v = ytriangle(nv, xyz);
  //v++;
  // below if when using triangulation function
  /*
  xi = where(v(1,) == 0 & v(2,) == 0 & v(3,)==0);
  if (is_array(xi)) {
    v = v(,1:xi(1)-1)
  }
  ntri = numberof(v(1,));
  //write, format="Total Triangles formed = %d\n",ntri;
  xi = where(v(1,) <= nv & v(2,) <= nv & v(3,) <= nv);
  if (is_array(xi)) {
    v = v(,xi)
  }
*/
  ntri = numberof(v(1,));
  write, format="Total Triangles formed = %d\n",ntri;
  pxyz = xyz;

  if (distthresh)
    v = remove_large_triangles(v, data, distthresh, mode=mode);
  
  if (savefile) {
    f = open(savefile,"w");
    for (i=1;i<=ntri;i++) {
      write, f, format="%10.3f %10.3f %7.3f %10.3f %10.3f %7.3f %10.3f %10.3f %7.3f\n",
	pxyz(1,v(1,i)),pxyz(2,v(1,i)),pxyz(3,v(1,i)),
        pxyz(1,v(2,i)),pxyz(2,v(2,i)),pxyz(3,v(2,i)),
        pxyz(1,v(3,i)),pxyz(2,v(3,i)),pxyz(3,v(3,i)); 
    }
    close,f;
  }

  if (plot) {
    w = window();
    x = [pxyz(1,(v(1,))), pxyz(1,(v(2,))), pxyz(1,(v(3,)))]
    y = [pxyz(2,(v(1,))), pxyz(2,(v(2,))), pxyz(2,(v(3,)))]
    z = [pxyz(3,(v(1,))), pxyz(3,(v(2,))), pxyz(3,(v(3,)))]
    xx = transpose(x)(*)
    yy = transpose(y)(*)
    zz = z(,sum); zz = zz/3;
    n = array(int,numberof(zz))
    n(*) = 3
    window, win; fma; 
    if (dolimits) {
        limits, square=1;
	limits;
    }
    plfp, zz, yy, xx, n, edges=0
    colorbar, min(zz), max(zz), units="m";
    window, w;
  }


  //timer, elapsed1;
  //timediff = elapsed1 - elapsed;
  //write, format = "Total time taken = %10.5f minutes\n",timediff(3)/60.;
  return v;
}

func plot_triag_mesh(tr,pxyz,edges=,win=,cmin=,cmax=) {
/*DOCUMENT plot_triag_mesh(tr,pxyz,edge=,win=)
  amar nayegandhi 01/09/04
*/
  
  if (is_void(win)) win = window();
  if (is_void(edges)) edges = 0;

  x = [pxyz(1,(tr(1,))), pxyz(1,(tr(2,))), pxyz(1,(tr(3,)))]
  y = [pxyz(2,(tr(1,))), pxyz(2,(tr(2,))), pxyz(2,(tr(3,)))]
  z = [pxyz(3,(tr(1,))), pxyz(3,(tr(2,))), pxyz(3,(tr(3,)))]

  xx = transpose(x)(*)
  yy = transpose(y)(*)
  zz = z(,sum); zz = zz/3;

  n = array(int,numberof(zz))
  n(*) = 3

  window, win; fma; plfp, zz, yy, xx, n, edges=edges, cmin=cmin, cmax=cmax;
  colorbar, min(zz), max(zz), units="m";
}

  
func ytriangulate(nv) {
/*DOCUMENT triangulate(int nv, XYZ pxyz, ITRIANGLE v, int ntri)
  Amar Nayegandhi 01/02/04
  adapted from C code written by Paul Bourke

  Triangulation subroutine
   Takes as input NV vertices in array pxyz
   Returned is a list of ntri triangular faces in the array v
   These triangles are arranged in a consistent clockwise order.
   The triangle array 'v' should be malloced to 3 * nv
   The vertex array pxyz must be big enough to hold 3 more points
   The vertex array must be sorted in increasing x values
*/

  extern pxyz, ntri;
  complete = 0;
  nedge = 0;
  emax = 200;
  status = 0;
  inside = 0;

  v = array(ITRIANGLE,3*nv);
 

  trimax = 4*nv;
  complete = array(int,trimax);
  edges = array(IEDGE,emax);

  xmin = min(pxyz(1:-3).x);
  ymin = min(pxyz(1:-3).y);
  xmax = max(pxyz(1:-3).x);
  ymax = max(pxyz(1:-3).y);

  dx = xmax - xmin;
  dy = ymax - ymin;

  if (dx > dy) {
    dmax = dx;
  } else {
    dmax = dy;
  }

  xmid = (xmax + xmin)/2.0;
  ymid = (ymax + ymin)/2.0;

  /*
      Set up the supertriangle
      This is a triangle which encompasses all the sample points.
      The supertriangle coordinates are added to the end of the
      vertex list. The supertriangle is the first triangle in
      the triangle list.
   */

  pxyz(nv+1).x = xmid - 20 * dmax;
  pxyz(nv+1).y = ymid - dmax;
  pxyz(nv+1).z = 0.0;
  pxyz(nv+2).x = xmid;
  pxyz(nv+2).y = ymid + 20 * dmax;
  pxyz(nv+2).z = 0.0;
  pxyz(nv+3).x = xmid + 20 * dmax;
  pxyz(nv+3).y = ymid - dmax;
  pxyz(nv+3).z = 0.0;

  v(1).p1 = nv+1;
  v(1).p2 = nv+2;
  v(1).p3 = nv+3;
  complete(1) = FALSE;
  ntri = 1;  

/*
      Include each point one at a time into the existing mesh
   */
   for (i=1;i<=nv;i++) {

      xp = pxyz(i).x;
      yp = pxyz(i).y;
      nedge = 0;

      /*
         Set up the edge buffer.
         If the point (xp,yp) lies inside the circumcircle then the
         three edges of that triangle are added to the edge buffer
         and that triangle is removed.
      */
      for (j=1;j<=ntri;j++) {
         if (complete(j)) 
            continue;
         x1 = pxyz(v(j).p1).x;
         y1 = pxyz(v(j).p1).y;
         x2 = pxyz(v(j).p2).x;
         y2 = pxyz(v(j).p2).y;
         x3 = pxyz(v(j).p3).x;
         y3 = pxyz(v(j).p3).y;
         inside = CircumCircle(xp,yp,x1,y1,x2,y2,x3,y3);
         if (is_void(inside)) {
             continue;
         }
         xc = inside(2);
         yc = inside(3);
         r = inside(4);

         if ((xc + r) < xp)
            complete(j) = TRUE;
         if (inside(1)) {
            /* Check that we haven't exceeded the edge list size */
            if (nedge+3 > emax) {
               emax += 100;
	       edges = grow(edges,array(IEDGE,100));
            }
            edges(nedge+1).p1 = v(j).p1;
            edges(nedge+1).p2 = v(j).p2;
            edges(nedge+2).p1 = v(j).p2;
            edges(nedge+2).p2 = v(j).p3;
            edges(nedge+3).p1 = v(j).p3;
            edges(nedge+3).p2 = v(j).p1;
            nedge += 3;
            v(j) = v(ntri);
            complete(j) = complete(ntri);
            ntri--;
            j--;
         }
      }
      /*
         Tag multiple edges
         Note: if all triangles are specified anticlockwise then all
               interior edges are opposite pointing in direction.
      */
      for (j=1;j<nedge;j++) {
         for (k=j+1;k<=nedge;k++) {
            if ((edges(j).p1 == edges(k).p2) && (edges(j).p2 == edges(k).p1)) {
               edges(j).p1 = -1;
               edges(j).p2 = -1;
               edges(k).p1 = -1;
               edges(k).p2 = -1;
            }
            /* Shouldn't need the following, see note above */
            if ((edges(j).p1 == edges(k).p1) && (edges(j).p2 == edges(k).p2)) {
               edges(j).p1 = -1;
               edges(j).p2 = -1;
               edges(k).p1 = -1;
               edges(k).p2 = -1;
            }
         }
      }
      /*
         Form new triangles for the current point
         Skipping over any tagged edges.
         All edges are arranged in clockwise order.
      */
      for (j=1;j<=nedge;j++) {
         if (edges(j).p1 < 1 || edges(j).p2 < 1)
            continue;
         if (ntri+1 >= trimax) {
            status = 4;
	    return status;
         }
         v(ntri+1).p1 = edges(j).p1;
         v(ntri+1).p2 = edges(j).p2;
         v(ntri+1).p3 = i;
         complete(ntri+1) = FALSE;
         ntri++;
      }
   }
   /*
      Remove triangles with supertriangle vertices
      These are triangles which have a vertex number greater than nv
   */
   write, format="ntri = %d\n", ntri;
   for (i=1;i<=ntri;i++) {
      if ((v(i).p1 > nv) || (v(i).p2 > nv) || (v(i).p3 > nv)) {
         v(i) = v(ntri);
         ntri--;
         i--;
      }
   }
   close, f;

   return v(1:ntri);
}

/*
   Return TRUE if a point (xp,yp) is inside the circumcircle made up
   of the points (x1,y1), (x2,y2), (x3,y3)
   The circumcircle centre is returned in (xc,yc) and the radius r
   NOTE: A point on the edge is inside the circumcircle
*/
func CircumCircle(xp,yp,x1,y1,x2,y2,x3,y3) {

   /* Check for coincident points */
   if ((abs(y1-y2) < EPSILON) && (abs(y2-y3) < EPSILON))
       return [FALSE,0,0,0]

   if (abs(y2-y1) < EPSILON) {
      m2 = -(x3-x2) / (y3-y2);
      mx2 = (x2 + x3) / 2.0;
      my2 = (y2 + y3) / 2.0;
      xc = (x2 + x1) / 2.0;
      yc = m2 * (xc - mx2) + my2;
   } else if (abs(y3-y2) < EPSILON) {
      m1 = -(x2-x1) / (y2-y1);
      mx1 = (x1 + x2) / 2.0;
      my1 = (y1 + y2) / 2.0;
      xc = (x3 + x2) / 2.0;
      yc = m1 * (xc - mx1) + my1;
   } else {
      m1 = -(x2-x1) / (y2-y1);
      m2 = -(x3-x2) / (y3-y2);
      mx1 = (x1 + x2) / 2.0;
      mx2 = (x2 + x3) / 2.0;
      my1 = (y1 + y2) / 2.0;
      my2 = (y2 + y3) / 2.0;
      if (m1-m2 != 0) {
        xc = (m1 * mx1 - m2 * mx2 + my2 - my1) / (m1 - m2);
        yc = m1 * (xc - mx1) + my1;
      } else {
        xc = [];
 	yc = [];
      }
      
   }

   if (!is_void(xc) && !is_void(yc)) {
    dx = x2 - xc;
    dy = y2 - yc;
    rsqr = dx*dx + dy*dy;
    r = sqrt(rsqr);

    dx = xp - xc;
    dy = yp - yc;
    drsqr = dx*dx + dy*dy;

    if (drsqr <= rsqr) {
     return [TRUE, xc, yc, r]
    } else {
     return [FALSE, xc, yc, r]
    }
   } else {
     return []
   }
}


func locate_triag_surface(pxyz,tr,win=, m=,show=) {
/*DOCUMENT locate_triag_surface(pxyz,tr,win=)
  amar nayegandhi 01/09/04.
*/
  if (is_void(win)) win = window();
  if (is_void(show)) show = 0;
  window, win;
  /*
  pxyz = array(XYZ,numberof(eaarl));
  pxyz.x = eaarl.least/100.;
  pxyz.y = eaarl.lnorth/100.;
  pxyz.z = eaarl.lelv/100.;
 */

  if (is_void(m)) m = mouse();
  buffer = data_box(pxyz(1,),pxyz(2,),m(1)-100,m(1)+100, m(2)-100,m(2)+100);
  if (!is_array(buffer)) return;
  dist = (pxyz(1,buffer)-m(1))^2 + (pxyz(2,buffer)-m(2))^2;
  mindist = min(dist);
  mnxdist = buffer(dist(mnx));
  whedge = where(mnxdist == tr(1,) | mnxdist == tr(2,) | mnxdist == tr(3,));

  pl = [];
  plall = [pxyz(,tr(1,whedge)), pxyz(,tr(2,whedge)), pxyz(,tr(3,whedge))];
  for (i=1;i<=numberof(plall(1,,1));i++) {
     pl = transpose([plall(1,i,),plall(2,i,)]);
     pl = grow(pl, pl(,1));
     tp = testPoly(pl, [m(1)], [m(2)]);
     if (is_array(tp))  break;
  }
  if (i > numberof(plall(1,,1))) return [];
  plthis = plall(,i,);
  x = plthis(1,*);
  y = plthis(2,*);
  z = plthis(3,*);
  

  if (show) {
    plmk, y,x, marker=5, msize=0.3, color="red";
    plg, grow(y,y(1)), grow(x,x(1)), color="red";
  }
  return transpose([[x],[y],[z]]);
}
  

func grid_triag_data(eaarl, cell=) {
// amar nayegandhi 04/07/04

 // if data array is in raster format (R, GEOALL, VEGALL), then covert to 
 // non raster format (FS, GEO, VEG).
 a = structof(eaarl(1));
 if (a == R) {
     data_out = clean_fs(eaarl);
 }

 if (a == GEOALL) {
     data_out = clean_bathy(eaarl);
 }

 if (a == VEG_ALL) {
     data_out = clean_veg(eaarl);
 }

 if (a == VEG_ALL_) {
     data_out = clean_veg(eaarl);
 }

 if (is_array(data_out)) eaarl = data_out;
 data_out = [];

 verts = triangulate_xyz(data=eaarl, plot=1);

 //define lower left and upper right coordinates
 ll =long( [min(eaarl.least)/100., min(eaarl.lnorth)/100.]);
 ur =long( [max(eaarl.least)/100., max(eaarl.lnorth)/100.]);
 ll;
 ur;
 xcell = (ur(1)-ll(1))/cell;
 ycell = (ur(2)-ll(2))/cell;
 img = array( double, xcell, ycell );
 

 //x = int( eaarl.least+50)/100 + 1;    // add 50cm, then convert from cm to m
 //y = int(eaarl.lnorth+50)/100 + 1;
 //z = eaarl.lelv;

 count = 0;


 // insert elevations into the grid array
  for (i=1; i<=xcell; i++ ) {
    for (j=1; j<=ycell; j++) {
    //locate triangulated surface
    tr = locate_triag_surface(pxyz, verts, m=[ll(1)+cell*i,ll(2)+cell*j]);
     if (is_array(tr))  {
	z = avg(tr(3,));
        count++;
        img( i, j ) = z;
     }
    }
    if ( (i % 10) == 0 ) write, format="%d of %d\r", i, xcell ;
  }
  idx = where(img == 0);
  img(idx) = -1000.0

  count;

 return [&ll, &ur, &img];

}
