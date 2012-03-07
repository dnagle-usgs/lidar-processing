/******************************************************************************\
* This file was moved to the attic on 2012-03-07. The code in this file was    *
* primarily used for a specific dataset and are no longer generally relevant   *
* in ALPS.                                                                     *
\******************************************************************************/

func read_4wd_ascii(ipath, ifname, no_lines=) {
/* DOCUMENT read_4wd_ascii(ipath, ifname, no_lines=)
    Original amar nayegandhi 02/28/03
    This function reads a 4 word ascii file of the format x y zmin zmax
    Input:
    ipath - Input path
    ifname - Input file name
    no_lines = Optional keyword to define the number of lines to read.  If no_lines is not set, the function will read all the lines in the file.
    Output:
    Data array of type array(int, 4, no_lines)
 */

 if (!no_lines) {
    f= open(ipath+ifname, "r");
    xx = 0;
    do {
  	line = rdline(f);
	xx++;
    } while (strlen(line) > 0);
    close, f
    no_lines = xx - 2;
 }

 data = array(int, 4, no_lines);

 f = open(ipath+ifname, "r");
 //read first line as string
 
 title = rdline(f);
 for (i = 1;  i <= no_lines; i++) {
   s = rdline(f);
   sread, s, format="%d %d %d %d\n",data(1,i), data(2,i), data(3,i), data(4,i);
  }
  return data
}

func extract_indx_tile(noaa_data, indx_no, win=) {
   /* DOCUMENT extract_indx_tile(indx_no)
    amar nayegandhi 03/05/03.
  */
  //open index tile file to read
  f = open("~/bathy_keys/indx_tiles_nos.txt", "r");
  no_lines = 110;
  ino = 0;
  ieastn = 0;
  ieastx = 0;
  inorthn = 0;
  inorthx = 0;
  for (i = 1; i <= no_lines; i++) {
     s = rdline(f);
     sread, s, format = "%d %d %d %d %d\n", ino, ieastn, ieastx, inorthn, inorthx;
     if (ino == indx_no) {
         eastn = ieastn;
         eastx = ieastx;
         northn = inorthn;
         northx = inorthx;
     }
  }
  write, indx_no, eastn, eastx, northn, northx;

  close, f;
  window, win;


  // now extract this indx tile from noaa bathy data
  indx = where(noaa_data(2,) >= northn);
  if (is_array(indx)) {
     iindx = where(noaa_data(2,indx) <= northx);
     if (is_array(iindx)) {
       indx = indx(iindx);
       eindx = where(noaa_data(1,indx) >= eastn);
       if (is_array(eindx)) {
         indx = indx(eindx);
 	 eeindxx = where(noaa_data(1,indx) <= eastx);
         if (is_array(eeindxx)) {
           if (win) {
 		 pldj, eastn, northn, eastn, northx, color="green"
 		 pldj, eastn, northn, eastx, northn, color="green"
 		 pldj, eastx, northn, eastx, northx, color="green"
  		 pldj, eastx, northx, eastn, northx, color="green"
                 s = swrite(format="%d",indx_no);
		 plt, s, eastn+(eastx-eastn)/2, northn+(northx-northn)/2, tosys=1;
            }
	   indx = indx(eeindxx);
	   data_out = noaa_data(,indx);
	 }
       }
     }
   } else data_out = [];
       
 return data_out 
}

func compare_data(ndata, edata) {
   /* DOCUMENT compare_data(ndata, edata)
      This function compares the depth ranges of the NOAA bathy data with the EAARL data points.  The EAARL data points that are beyond a certain range of the NOAA bathy data are discarded.  
      Input: ndata: NOAA bathy data array (from read_4wd_ascii function
             edata: EAARL bathy data array (of type GEO)
      Output: EAARL bathy data array of type GEO 
      amar nayegandhi 03/06/03.
      modified AN 03/21/03 to include tagging of EAARL data that are not compared, and finding unique elements of the compared data.
   */
   //further strip the noaa data to cover only the eaarl data
   minn = min(edata.north/100.);
   maxn = max(edata.north/100.);
   mine = min(edata.east/100.);
   maxe = max(edata.east/100.);
   ct = 0;
   tag_e = array(int, numberof(edata));

   if (minn > min(ndata(2,))) {
      indx = where(ndata(2,) >= minn);
      if (is_array(indx)) {
        ndata = ndata(,indx);
      }
   }
   if (maxn < max(ndata(2,))) {
      indx = where(ndata(2,) <= maxn);
      if (is_array(indx)) {
        ndata = ndata(,indx);
      }
   }
   if (mine > min(ndata(1,))) {
      indx = where(ndata(1,) >= mine);
      if (is_array(indx)) {
        ndata = ndata(,indx);
      }
   }
   if (maxe < max(ndata(1,))) {
      indx = where(ndata(1,) <= maxe);
      if (is_array(indx)) {
        ndata = ndata(,indx);
      }
   }

   new_edata = array(structof(edata), 2*numberof(edata));
   if (is_array(ndata)) {
     //now compare ndata with the eaarl data
     for (i=1;i<numberof(ndata(1,)); i++) {
       fidx = [];
       dif_ndata = (ndata(4,i)-ndata(3,i));
       write, format="Avg elev noaa data = %5.1f\n", avg_ndata;
       idx = where(edata.north >= (ndata(2,i)-55)*100);
       if (is_array(idx)) {
         iidx = where(edata.north(idx) <= (ndata(2,i)+55)*100);
         if (is_array(iidx)) {
           idx = idx(iidx);
           iidx = where(edata.east(idx) >= (ndata(1,i)-55)*100);
           if (is_array(iidx)) {
             idx = idx(iidx);
             iidx = where(edata.east(idx) <= (ndata(1,i)+55)*100)
             if (is_array(iidx)) {
       		fidx = idx(iidx);
	     }
           }
          }
       }
       if (is_array(fidx)) {
        tag_e(fidx)++;
        //write, format="numberof fidx = %d \n",numberof(fidx);
        eedata = edata(fidx);
        if (ndata(3,i) >= 10) {
          eidx = where((eedata.depth+eedata.elevation)/100. > (-1.0*ndata(4,i)-dif_ndata));
          //eidx = where((eedata.depth)/100. > (-1.0*ndata(4,i)-avg_ndata-1.0));
          //eidx = where((eedata.depth+eedata.elevation)/100. > (-1.0*ndata(4,i)));
          if (is_array(eidx)) {
           eiidx = where((eedata.depth(eidx)+eedata.elevation(eidx))/100. < (-1.0*ndata(3,i)+dif_ndata+1.0));
           //eiidx = where((eedata.depth(eidx))/100. < (-1.0*ndata(3,i)+avg_ndata));
           //eiidx = where((eedata.depth(eidx)+eedata.elevation(eidx))/100. < (-1.0*ndata(3,i)));
           if (is_array(eiidx)) {
             eidx = eidx(eiidx);
             new_edata(ct+1:(ct+numberof(eidx))) = eedata(eidx);
             ct= ct+numberof(eidx);
           } 
          }
        } else {
	    //if (ndata(3,i) >= 8) {
              eidx = where((eedata.depth+eedata.elevation)/100. > (-1.0*ndata(4,i)-7*dif_ndata));
              if (is_array(eidx)) {
                 eiidx = where((eedata.depth(eidx)+eedata.elevation(eidx))/100. < (-1.0*ndata(3,i)+7*dif_ndata));
                if (is_array(eiidx)) {
                  eidx = eidx(eiidx);
                  new_edata(ct+1:(ct+numberof(eidx))) = eedata(eidx);
                  ct= ct+numberof(eidx);
                } 
              }
	    /*} else {
               //write, format="depth below 8m for i = %d\n",i;
               new_edata(ct+1:(ct+numberof(eedata))) = eedata;
	       ct = ct + numberof(eedata);
	    }
	    */
        }
       
       // nd = swrite(format="%2d, %2d",ndata(3,i), ndata(4,i));
//	plt, nd, ndata(1,i), ndata(2,i), tosys=1
 //	write, ndata(2,i), ndata(1,i);
      } //else {
	//write, "No eaarl data found for given noaa point."
  //      nd = swrite(format="%2d, %2d",ndata(3,i), ndata(4,i));
//	plt, nd, ndata(1,i), ndata(2,i), tosys=1
 //	write, ndata(2,i), ndata(1,i);
//      } 
      write, format="%d of %d comparisons completed.\r",i,numberof(ndata(1,));
    } // end for loop
    ne_idx = where(tag_e == 0);
    if (is_array(ne_idx)) {
      new_edata(ct+1:(ct+numberof(ne_idx))) = edata(ne_idx);
      ct = ct + numberof(ne_idx);
    }
    new_edata = new_edata(1:ct);
    //midx = where(tag_e > 1);
    //write, format="Number of multiple occurences of the same data point = %d.  Deleting them... \n",numberof(midx);
    //use David Munros unique function 
    write, "Deleting multiple occurances of the same data points..."
    new_edata = new_edata(sort(new_edata.rn));
    neidx = unique(new_edata.rn);
    new_edata = new_edata(neidx);

   } 
   if (is_array(new_edata)) 
    return new_edata
       
}

func test_bathy(null) {
   extern noaa_data;
   noaa_data = read_4wd_ascii("~/bathy_keys/", "bathy_data_keys_0_40m_min_max.txt")
    for (i=1;i<=110;i++) {
     data_out =  extract_indx_tile(noaa_data, i, win=6);
    }
}

func remove_bow_effect(data, factor=, mode=) {
/* DOCUMENT func remove_bow_effect(data, factor=, mode=) 
   amar nayegandhi 08/01/2005
   This function tries to remove the bow effect seen in shallow and turbid bathy data by modelling a sin curve on the data.
  INPUT:
	data = input data array (of type GEO)
	factor= scale factor in cm (default = 15 cm)
        mode = 2 (for bathymetry - default).
             = 3 (for bare earth under topo).
  OUTPUT:
	outdata = corrected data array
*/

  extern pi
  if (is_void(factor)) factor = 15;
  if (is_void(mode)) factor = 2;
  data = test_and_clean(data);
  if (mode == 2) 
        data.depth -= factor*sin(((data.rn>>24)/120.)*pi);
  if (mode == 3)
        data.lelv -= factor*sin(((data.rn>>24)/120.)*pi);
  return data
}
