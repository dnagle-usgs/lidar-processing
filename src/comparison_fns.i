func read_ascii_file(fname,n) {
  //this function reads a UTM ascii file 
  f = open(fname, "r");
  data = array(float,3,n);
  x = array(float, n);
  y = array(float, n);
  z = array(float, n);
  read, f, format="%f %f %f", x,y,z
  data(1,) = x;
  data(2,) = y;
  data(3,) = z;
  close, f;
  return data
  }


func compare_pts(eaarl, kings, rgn, fname=, buf=) {
   // this function compares each point of kings data within a buffer of eaarl data.
   // amar nayegandhi 11/15/2002.

   if (!buf) buf = 500 // default to 5 m buffer side.
   indx = where(((kings(1,) >= rgn(1)) &
                 (kings(1,) <= rgn(2))) & 
	        ((kings(2,) >= rgn(3)) &
		 (kings(2,) <= rgn(4))));
   kings = kings(,indx);


 write, format="Searching for data within %d centimeters from kings data \n",buf;

 if (!fname) 
   f = open("/home/anayegan/terra_ceia_comparison/analysis/nearest_pt_be_comparisons_1m_after_rcf.txt", "w");
 else 
   f = open(fname, "w");
 write, f, "Indx  Number_of_Indices  Avg  Nearest_Point  Kings_Point  Nearest_Elv_Point Diff_Nearest Diff_Nearest_Elv"

 for (i=1; i <= numberof(kings(1,)); i++) {

   indx = where(((eaarl.east >= kings(1,i)*100-buf)   & 
               (eaarl.east <= kings(1,i)*100+buf))  & 
               ((eaarl.north >= kings(2,i)*100-buf) & 
               (eaarl.north <= kings(2,i)*100+buf)));

   if (is_array(indx)) {
      be_avg = eaarl.elevation(indx)/100.-(eaarl.lelv(indx)-eaarl.felv(indx))/100.;
      be_avg_pts = avg(be_avg);
      //avg_pts = avg(eaarl.elevation(indx));
      mindist = buf*sqrt(2);
      for (j = 1; j <= numberof(indx); j++) {
        x1 = (eaarl(indx(j)).east)/100.0;
        y1 = (eaarl(indx(j)).north)/100.0;
        dist = sqrt((kings(1,i)-x1)^2 + (kings(2,i)-y1)^2);
        if (dist <= mindist) {
          mindist = dist;
	  mineaarl = eaarl(indx(j));
	  minindx = indx(j);
        }
      }
      elv_diff = abs((eaarl(indx).elevation/100.-(eaarl(indx).lelv-eaarl(indx).felv)/100.)-kings(3,i));
      minelv_idx = (elv_diff)(mnx);
      minelv_indx = indx(minelv_idx);
      minelveaarl = eaarl(minelv_indx);
      //write, mineaarl.elevation, kings(3,i);
      be = mineaarl.elevation/100.-(mineaarl.lelv-mineaarl.felv)/100.;
      be_elv = minelveaarl.elevation/100.-(minelveaarl.lelv-minelveaarl.felv)/100.;
      write, f, format=" %d  %d  %f  %f  %f %f %f %f\n",i, numberof(indx), be_avg_pts, be, kings(3,i), be_elv,  (be-kings(3,i)), (be_elv-kings(3,i));

   }
 }
 close, f;
}


func read_txt_anal_file(fname, n) {
  // this function reads the analysis data file written out from compare_pts
  // amar nayegandhi 11/18/02
   
   extern i, no, be_avg_pts, be, kings_elv, be_elv, diff1, diff2;

   i = array(int, n)
   no =  array(int, n)
   be_avg_pts = array(float, n)
   be = array(float, n)
   kings_elv = array(float, n)
   be_elv = array(float, n)
   diff1 = array(float, n)
   diff2 = array(float, n)
   f1 =open(fname, "r");
   read, f1, format=" %d  %d  %f  %f  %f %f %f %f",i,no,be_avg_pts, be, kings_elv, be_elv, diff1, diff2;
   close, f1;
} 

func rcfilter_eaarl_pts(eaarl, buf=, w=, be=) {
  //this function uses the random consensus filter (rcf) within a defined
  // buffer size (default 4m by 4m) to filter within an elevation width
  // defined by w.
  // amar nayegandhi 11/18/02.

 // define a bounding box
  bbox = array(float, 4);
  bbox(1) = min(eaarl.east);
  bbox(2) = max(eaarl.east);
  bbox(3) = min(eaarl.north);
  bbox(4) = max(eaarl.north);

  if (!buf) buf = 400; //in centimeters
  if (!w) w = 30; //in centimeters

  //now make a grid in the bbox
  ngridx = ceil((bbox(2)-bbox(1))/buf);
  ngridy = ceil((bbox(4)-bbox(3))/buf);
  xgrid = span(bbox(1), bbox(2), int(ngridx));
  ygrid = span(bbox(3), bbox(4), int(ngridy));


  for (i = 1; i <= ngridy; i++) {
    for (j = 1; j <= ngridx; j++) {
      indx = where(((eaarl.east >= xgrid(j))   &
                   (eaarl.east <= xgrid(j)+buf))  &
                   ((eaarl.north >= ygrid(i)) &
                   (eaarl.north <= ygrid(i)+buf)));
      if (is_array(indx)) {
       if (be) {
         be_elv = eaarl.elevation(indx)-(eaarl.lelv(indx)-eaarl.felv(indx));
	 sel_ptr = rcf(be_elv, w, mode=2);
	 if (*sel_ptr(2) > 1) {
	    tmp_eaarl = eaarl(indx);
	    grow, new_eaarl, tmp_eaarl(*sel_ptr(1));
	    //write, numberof(indx), *sel_ptr(2);
	 }
       }
      }
    }
  }

  return new_eaarl
	 
}


