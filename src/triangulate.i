
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


func triangulate_xyz(file=, savefile=, data=, plot=) {
/*DOCUMENT prepare_xyz(file=,xyz=)
  amar nayegandhi 01/05/03.
 */
  
  extern xyz, pxyz, ntri;
  if (!is_void(file)) {
     ipath = split_path(file,0)(1);
     ifname = split_path(file,0)(2);
     xyz = read_ascii_xyz(ipath=ipath,ifname=ifname);
  }

  if (is_array(data)) {
     xyz = [data.east/100., data.north/100., (data.elevation+data.depth)/100.];
     xyz = transpose(xyz);
  }
  write, format="Total Points Read = %d\n",numberof(xyz(1,));

  xyz = xyz(,sort(xyz(1,)));
 


 /*
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
  pxyz = array(XYZ,nv);
  pxyz.x = xyz(1,);
  pxyz.y = xyz(2,);
  pxyz.z = xyz(3,);



  pxyz = pxyz(sort(pxyz.x));
  pxyz = grow(pxyz, array(XYZ,3));
  v = triangulate(nv);
  write, format="Total Triangles formed = %d\n",ntri;
  
  if (savefile) {
    f = open(savefile,"w");
    for (i=1;i<=ntri;i++) {
      write, f, format="%10.3f %10.3f %7.3f %10.3f %10.3f %7.3f %10.3f %10.3f %7.3f\n",
	 pxyz(v(i).p1).x,pxyz(v(i).p1).y,pxyz(v(i).p1).z,
         pxyz(v(i).p2).x,pxyz(v(i).p2).y,pxyz(v(i).p2).z,
         pxyz(v(i).p3).x,pxyz(v(i).p3).y,pxyz(v(i).p3).z; 
    }
    close,f;
  }

  if (plot) {
    x = [pxyz.x(v.p1), pxyz.x(v.p2), pxyz.x(v.p3)]
    y = [pxyz.y(v.p1), pxyz.y(v.p2), pxyz.y(v.p3)]
    z = [pxyz.z(v.p1), pxyz.z(v.p2), pxyz.z(v.p3)]
    xx = transpose(x)(*)
    yy = transpose(y)(*)
    zz = z(,sum); zz = zz/3;
    n = array(int,numberof(zz))
    n(*) = 3
    window, 0; fma; plfp, zz, yy, xx, n, edges=1
  }


  return v;
}

  
func triangulate(nv) {
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


