write," DataRegistration.i                                      jlebonit Jun 21, 2007"

require, "batch_terraceia_analysis.i"
require, "comparison_fns.i"

 
func dataReg(data1, data2, win=, plot=, ucmin=, ucmax=, data1plot=, data2plot=, filename=, rwin=, splot=, 
regionresultpbd=, regionresulttxt=, oply=) {

/* DOCUMENT Authors: Jim Lebonitte                       created on: June 20, 2007
            Amar Nayegandhi  

This function compares two datasets to see if an area that should be "unchanged"
is the same

    data1 - data array, one of the two data sets being compared
    data2 - data array, one of the two data sets being compared
    win - int, the window that the user would like to select the area from 
                default = 5.  
    plot - int, set to 1 if you want the data taken from each dataset plotted
                in different windows.  
    ucmin - float, min colorbar value for the plotted extracted data
                   will only work if plot is set to 1
    ucmax - float, max colorbar value for the plotted extracted data
                   will only work if plot is set to 1
    data1plot - int, window that the user would like the extracted data
                from data1 to be plotted in (Default =1)
    data2plot - int, window that the user would liek the extracted data
                     from data2 to be plotted in (Default = 2)
    filename - string, path name for the results file from the compare_pts function
                       to be written. (Point 2 Point comparison results)
    rwin - int, window where you want the RMSE graph to be written out to

    regionresultpbd - string, filename where you want a pbd file with all of the necessary
                           results from this region to be written out so you can find it again.

    regionresulttxt - string, filename where you want a text file containing the group results.

    oply - polygon array, allows you to import a polygon to test.  Useful for testing the same
                          area in different data sets.
*/

    
    if(is_void(regionresultpbd)) {
        regionresultpbd="/home/jlebonit/THESIS/g2gresults.pbd"
    }
    if(is_void(regionresulttxt)) {
        regionresulttxt="/home/jlebonit/THESIS/g2gresults.txt"
    }
    if(is_void(splot)) {
        splot="~/resultsplot"
    }
    if(is_void(rwin)) {
        rwin=3
    }
    if(is_void(filename)) {
        filename="/home/jlebonit/THESIS/p2presults.txt";
    } 
    if(is_void(win)) {
        win=5;
    }

    if(is_void(data1plot)) {
        data1plot=1;
    }

    if (is_void(data2plot)) {
        data2plot=2;
    }
    
    window, win;    
    count=1;
    type= nameof(structof(data));
  if(is_void(oply)){
     ply = getPoly();
     box = boundBox(ply);
  } else {
     ply=oply;
     box = boundBox(ply);
  }
  while ( count < 3 ) {   
      if ( count == 1 ) {
	data=data1;
      } else {    
	data=data2; 
      }
  
      if ( type == "VEG__" ) {
         box_pts = ptsInBox(box*100., data.least, data.lnorth);
         poly_pts = testPoly(ply*100., data.least(box_pts), data.lnorth(box_pts));
         indx = box_pts(poly_pts);
         if (!is_void(origdata)) {
            orig_box_pts = ptsInBox(box*100., origdata.least, origdata.lnorth);
            if (!is_array(orig_box_pts)) {
            orig_poly_pts = testPoly(ply*100., origdata.least(orig_box_pts), origdata.lnorth(orig_box_pts));
            origindx = orig_box_pts(orig_poly_pts);
         }
        }
      } else {
         box_pts = ptsInBox(box*100., data.east, data.north);
         poly_pts = testPoly(ply*100., data.east(box_pts), data.north(box_pts));
         indx = box_pts(poly_pts);
         if (!is_void(origdata)) {
            orig_box_pts = ptsInBox(box*100., origdata.east, origdata.north);
            orig_poly_pts = testPoly(ply*100., origdata.east(orig_box_pts), origdata.north(orig_box_pts));
            origindx = orig_box_pts(orig_poly_pts);
         }
      }


	if (count == 1) {		
	   data1 = data(indx);
	}
	else {
	   data2 = data(indx);
	}
	 count++;
      }

      if(plot) {
        window, data1plot; fma; 
        display_veg(data1, win=data1plot, cmin=ucmin, cmax=ucmax, size=1, marker=1);  
        window, data2plot; fma;
        display_veg(data2, win=data2plot, cmin=ucmin, cmax=ucmax, size=1, marker=1); 
      }

/* Making xyz variable from the smaller variable */

      if(numberof(data1) < numberof(data2)) {
         xyzdatavar = data1;
         eaarldata = data2;
         write, "data1 is smaller"
      } else {
         xyzdatavar = data2;
         eaarldata = data1;
         write, "data2 is smaller"
      }

      xyzdata=array(float,3,numberof(xyzdatavar));

      xyzdata(1,)=xyzdatavar.least;
      xyzdata(2,)=xyzdatavar.lnorth;
      xyzdata(3,)=xyzdatavar.lelv;  
      
/* Converting centimeters to meters */

      xyzdata=xyzdata/100;   

      compare_pts(eaarldata, xyzdata, fname=filename, mode=3);
      plot_be_kings_elv(filename, win=rwin );
      window, rwin;

/* Data has been extracted into data1 and data2 */
     numpointsdata1=numberof(data1);
     numpointsdata2=numberof(data2); 

     avgdata1 = avg(data1.lelv); 
     avgdata2 = avg(data2.lelv);   


     meddata1 = median(data1.lelv);
     meddata2 = median(data2.lelv);
     

     write, "                                  data1 statistics      data2 statistics"
     write, "" 
     write, "Number Of Points:                 ", numpointsdata1(0),"      ", numpointsdata2(0) 
     write, "Average Elevation Of Region:    ", avgdata1(0),  avgdata2(0)
     write, "Median Elevation Of Region:     ", meddata1(0), meddata2(0)

     f=createb(regionresultpbd);
     f1=open(regionresulttxt, "w");
     save, f, data1, data2, ply  
     write, f1, "Number Of Point     Average Elevation    Median Elevation";
     write, f1, numpointsdata1(0),   avgdata1(0), meddata1(0);
     write, f1, numpointsdata2(0),   avgdata2(0), meddata2(0);

      close, f;
      close, f1;
}

func computeMeanErr(dir) {
/* Jim Lebonitte
        This function reads in all the point comparison text files and computes the mean error for the whole region.


*/


} 
