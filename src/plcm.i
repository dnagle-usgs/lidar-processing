/*
   $Id$
*/

write,"$Id$"



/*

$Revision$
$Date$
$Header$
$Author$
$Id$
    
$Log$
Revision 1.6  2002/07/08 04:21:38  wwright

 Several bug fixes, DOCUMENTS and comments updated and clarified.
 Added geo_rast to drast.i to permit viewing rasters in a geo-refed.
 sense.


Revision 1.5  2002/03/22 15:29:45  anayegan
    bathy.i :  Changed start value such that it matches with 
               start value of first_surface function.  The start 
               keyword can now have the same record number for both 
               functions.
               While executing run_bath, instead of printing to 
               screen every raster, it now prints the index value 
               every 50th raster.
               Commented exponential values for keys water, since I 
               was working on tampa bay survey.

    drast.i :  modified line that sends tans information to sf_a.tcl 
               so that it only sends when there is any data to send.

    drast.ytk: corrected the error causing window, 0 to erroneously 
               pop up when initially playing through rasters.  corrected 
               error message that arises when edb is loaded and sf_a.tcl 
               is not open.  changed it to a warning message.

    geobath.i: Added colorbar function which plots colorbar every 
               time you display bathymetric or depth image.  Added 
               structure GEODEPTH which will contain depth information 
               and GEOBATH which will contain bathymetric information 
               depending on the bathy keyword.

               Documented display_bath function which explains all the 
               keywords.
               By setting the bathy keyword, the display_bath writes 
               out and displays a bathymetric image corrected for the 
               refraction of light in water for depth.  However, we 
               still need to correct for the position of light pulse 
               at the bottom.  Need to add the effect of the scan 
               angle for this.
                Made correction for displaying the bathymetric or depth 
               image using the correct keyword such it does not plot all 
               those erroneous points at (0,0).

    sf_a.tcl:  changed the 'mogrify' command to correctly rotate the 
               image depending on the heading value.

    Revision 1.4  2002/02/12 15:53:03  anayegan
    plcm.i : Fixed q array.
    geo_bath.i : display "georectified" bathymetric image.

    Revision 1.3  2002/01/23 04:57:58  wwright

     minor changes.  Added code to update the dir var in sf automatically
     when load_edb is called.  Saves a few steps.

    Revision 1.2  2002/01/22 21:42:13  wwright

      fixed somd, again, in edb_access.i and affected code in sf

    Revision 1.1.1.1  2002/01/04 06:33:51  wwright
    Initial deposit in CVS.


*/

func plcm( z, y, x, cmin=, cmax=, marker=, msize=)
/* DOCUMENT plcm   Plot markers z,y,x where z will be color coded

   Plots a scatter plot where z determines the color of the marker. 
   z,y, and x must all be the same size. sz= the size in NDC coords of the
   marker.  If shape= is non-nil it will cause plcm to  generate squares.
   If shape= is not defined or nil plcm will generate triangles.

   This function is useful for plotting data that's a function of three 
   variables.  In my case, it's frequently latitude, longitude, and 
   elevation where elevation variations are shown as varying colors.
   1=squares, 3=triangles

    1/22/02   Added edges=0 to plfp cuz Yorick 1.5 doesn't seem 
              to default to 0 as 1.4 did.
   11/27/1999 Mostly rewritten by David Munro.
   11/15/99 Fixed problem where z values were shifted from the x/y
            values.

   C. W. Wright 11/7/1999  wright@web-span.com

*/ 


{
  q = where( z > cmin );
  if ( numberof(q) == 0 ) 
     return;
  qq = where( z(q) < cmax );
  z = z( q(qq) );
  x = x( q(qq) );
  y = y( q(qq) );
  if (is_void(marker)) marker= 1;          /* default to squares */
  marker= (*_plmk_markers(marker)) / 7.0;  /* shrink default size */
  if (msize) marker*= msize;
  px= marker(,1);
  py= marker(,2);

  n= array(1, 1+numberof(y));
  n(1)= numberof(py);
  if (is_void(x)) x= indgen(numberof(y));
  plfp, edges=0, grow([0.],z), grow(py,y), grow(px,x), n, 
       cmin=cmin, cmax=cmax;
}



