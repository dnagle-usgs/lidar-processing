func read_4wd_ascii(ipath, ifname, no_lines=) {
 /* DOCUMENT read_4wd_ascii(ipath, ifname, no_lines=)
    Original amar nayegandhi 02/28/03
    This function reads a 4 word ascii file of the format x y zmin zmax
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
   /* DOCUMENT compare_data(data_out, edata)
      amar nayegandhi 03/06/03.
   */
   //further strip the noaa data to cover only the eaarl data
   minn = min(edata.north/100.);
   maxn = max(edata.north/100.);
   mine = min(edata.east/100.);
   maxe = max(edata.east/100.);
   ct = 0;

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
        //write, format="numberof fidx = %d \n",numberof(fidx);
        eedata = edata(fidx);
        if (ndata(3,i) >= 10) {
          eidx = where((eedata.depth+eedata.elevation)/100. > (-1.0*ndata(4,i)-dif_ndata));
          //eidx = where((eedata.depth)/100. > (-1.0*ndata(4,i)-avg_ndata));
          //eidx = where((eedata.depth+eedata.elevation)/100. > (-1.0*ndata(4,i)));
          if (is_array(eidx)) {
           eiidx = where((eedata.depth(eidx)+eedata.elevation(eidx))/100. < (-1.0*ndata(3,i)+dif_ndata));
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
              eidx = where((eedata.depth+eedata.elevation)/100. > (-1.0*ndata(4,i)-4*dif_ndata));
              if (is_array(eidx)) {
                 eiidx = where((eedata.depth(eidx)+eedata.elevation(eidx))/100. < (-1.0*ndata(3,i)+4*dif_ndata));
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
       
      } 
    } // end for loop
    new_edata = new_edata(1:ct);
    
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


 
 
 


