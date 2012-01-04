/******************************************************************************\
* This file was created in the attic on 2010-02-19. It contains functions from *
* ircf.i that have become obsolete. These functions were removed:              *
*     remove_large_triangles                                                   *
*     derive_plane_constants                                                   *
* Details accompany each function below.                                       *
\******************************************************************************/

/*
   Function 'remove_large_triangles' is superseded by 'filter_trimesh_maxside'
   from ytriangulate.i, which performs the same task.
*/
func remove_large_triangles(verts, data, distthresh, mode=) {
/* DOCUMENT remove_large_triangles(verts, distthresh) 
   this function removes large triangles using a distance threshold.  
   the length of the sides of a triangle must be lesser than this threshold.
   amar nayegandhi 04/16/04.
*/

  if (is_void(mode)) mode = 3;
  if (!is_void(distthresh)) {
      write, "removing large triangles using distance threshold...";
      if (mode != 3) {
        d1sq = (data(verts(1,)).east/100. - data(verts(2,)).east/100.)^2 +
		(data(verts(1,)).north/100. - data(verts(2,)).north/100.)^2;
        d2sq = (data(verts(2,)).east/100. - data(verts(3,)).east/100.)^2 +
		(data(verts(2,)).north/100. - data(verts(3,)).north/100.)^2;
        d3sq = (data(verts(3,)).east/100. - data(verts(1,)).east/100.)^2 +
		(data(verts(3,)).north/100. - data(verts(1,)).north/100.)^2;
      } else {
        d1sq = (data(verts(1,)).least/100. - data(verts(2,)).least/100.)^2 +
		(data(verts(1,)).lnorth/100. - data(verts(2,)).lnorth/100.)^2;
        d2sq = (data(verts(2,)).least/100. - data(verts(3,)).least/100.)^2 +
		(data(verts(2,)).lnorth/100. - data(verts(3,)).lnorth/100.)^2;
        d3sq = (data(verts(3,)).least/100. - data(verts(1,)).least/100.)^2 +
		(data(verts(3,)).lnorth/100. - data(verts(1,)).lnorth/100.)^2;
      }
      dsq = [d1sq, d2sq, d3sq](,max);
      didx = where(dsq <= distthresh^2);
      if (is_array(didx)) {
        verts = verts(,didx);
      } else {
	verts = [];
      }
  }

  return verts;
}

/*
   Function 'derive_plane_constants' is superseded by 'planar_params_from_pts'
   in geometry.i, which performs the same task.
*/
func derive_plane_constants(p,q,r) {
/*DOCUMENT derive_plane_constants(p,q,r)
  amar nayegandhi 02/04/04.
*/
 
  A = p(2)*(q(3)-r(3))+q(2)*(r(3)-p(3))+r(2)*(p(3)-q(3));
  B = p(3)*(q(1)-r(1))+q(3)*(r(1)-p(1))+r(3)*(p(1)-q(1));
  C = p(1)*(q(2)-r(2))+q(1)*(r(2)-p(2))+r(1)*(p(2)-q(2));
  D = p(1)*(q(2)*r(3) - r(2)*q(3))+q(1)*(r(2)*p(3)-p(2)*r(3))+r(1)*(p(2)*q(3)-q(2)*p(3));
  D = -1.0*D;

return [A,B,C,D];
}
