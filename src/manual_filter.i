/*

   $Id$

*/

func select_region(data, win=, plot=) {
 /*DOCUMENT select_region(data, win=)
   This function allows the user to select a region by using a mouse click.  The user 
   will have to decide if the mouse click is for a data tile(2km by 2km), 
   letter tile (1km by 1km) or number tile (250m by 250m).
   amar nayegandhi 11/21/03.
*/

  extern cur_east, cur_north, cur_csize;
  if (is_void(win)) win = 5;
  // wtemp = window();
  window, win;
  a = mouse(1,1,"Hold the left mouse button down and select a region:");
 
  mneast = min(a(1),a(3));
  mxnorth = max(a(2),a(4));

  seldist = sqrt((a(3)-a(1))^2+(a(4)-a(2))^2);
  if (seldist < 250*sqrt(2)) {
    write, "Congratulations! You have selected a number tile."
    teast = int(mneast/250) * 250;
    tnorth = ceil(mxnorth/250) * 250;
    csize = 250;
  } else {
     if (seldist < 1000*sqrt(2)) {
       write, "Congratulations! You have selected a letter tile."
       teast = int(mneast/1000) * 1000;
       tnorth = ceil(mxnorth/1000) * 1000;
       csize = 1000;
     } else {
       if (seldist < 2000*sqrt(2)) {
         write, "Congratulations! You have selected a data tile."
         teast = int(mneast/2000) * 2000;
         tnorth = ceil(mxnorth/2000) * 2000;
         csize = 2000;
       } else {
         write, "Bad region selected! Please try again..."
       }
     }
  }

 if (!is_void(plot)) {
   window, win;
   pldj, [teast,teast,teast+csize,teast+csize], 
	 [tnorth-csize, tnorth, tnorth, tnorth-csize],
         [teast, teast+csize, teast+csize, teast], 
         [tnorth, tnorth, tnorth-csize, tnorth-csize],
         color="yellow", width=1.5;
 }
 //now extract data within selected region
 idx = data_box(data.east/100., data.north/100., teast, teast+csize, tnorth-csize, tnorth);
 if (is_array(idx)) outdata = data(idx);

 cur_east = teast;
 cur_north = tnorth;
 cur_csize = csize;

 return outdata;

}

func select_points(celldata, exclude=, win=) {
  // amar nayegandhi 11/21/03
 
 if (is_void(win)) win = 4;
  
 window, win;
 left_mouse = 1;
 center_mouse = 2;
 right_mouse = 3;
 buf = 1000;  // 10 meters
 
 rtn_data = [];
 
 do {
  write, format="Window: %d, Controls:- Left: Select point, Middle: View Waveform, Right: Quit \n",win;
  spot = mouse(1,1,"");
  mouse_button = spot(10);
  if (mouse_button == right_mouse) break;

  q = where(((celldata.east >= spot(1)*100-buf)   &
               (celldata.east <= spot(1)*100+buf)) )

  if (is_array(q)) {
    indx = where(((celldata.north(q) >= spot(2)*100-buf) &
               (celldata.north(q) <= spot(2)*100+buf)));

    indx = q(indx);
  }
  if (is_array(indx)) {
    rn = celldata(indx(1)).rn;
    mindist = buf*sqrt(2);
    for (i = 1; i < numberof(indx); i++) {
      x1 = (celldata(indx(i)).east)/100.0;
      y1 = (celldata(indx(i)).north)/100.0;
      dist = sqrt((spot(1)-x1)^2 + (spot(2)-y1)^2);
      if (dist <= mindist) {
        mindist = dist;
        mindata = celldata(indx(i));
        minindx = indx(i);
      }
    }
    blockindx = minindx / 120;
    rasterno = mindata.rn&0xffffff;
    pulseno  = mindata.rn/0xffffff;

    if (mouse_button == center_mouse) {
	  a = [];
          ex_bath, rasterno, pulseno, win=0, graph=1;
    }
 
    if (mouse_button == left_mouse) 
          rtn_data = grow(rtn_data, mindata);
    
  }

 } while ( mouse_button != right_mouse );

 return rtn_data;
}

 

func write_to_final_arr(temp_arr) {
  // amar nayegandhi 11/21/03
  extern final_arr, cur_east, cur_north, cur_csize;
  final_arr = grow(final_arr, temp_arr);
  pldj, [cur_east,cur_east,cur_east+cur_csize,cur_east+cur_csize], 
	 [cur_north-cur_csize, cur_north, cur_north, cur_north-cur_csize],
         [cur_east, cur_east+cur_csize, cur_east+cur_csize, cur_east], 
         [cur_north, cur_north, cur_north-cur_csize, cur_north-cur_csize],
         color="green", width=1.5;
}
 

