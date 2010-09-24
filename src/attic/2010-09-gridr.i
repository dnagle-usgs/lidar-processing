// vim: set ts=3 sts=3 sw=3 ai sr et:

func tile_file_name(m) {
/* DOCUMENT tile_file_name(m)

   Determines the file name of a tile based on the input coords
  of "m".  

   Returns:  
      tilefn     A string containing the filename of the tile
                 which goes with the selected location.

 See also: tile_file_name, draw_grid, show_grid_location
*/
   tilefn = "";
   tile = tile_location(m);
   tilefn=swrite(format="%d-%d-tile.pbd", tile(1)/1000, tile(2)/1000);
   return tilefn;
}

func set_tile_filename(m, win=, nodata=) {
   extern curzone, tilename, finaldata, ifinaldata; 
   if (is_void(win)) win = window();
   if (is_void(finaldata) && (!nodata)) {
      write, "No finaldata found.  Cannot Save";
      return;
   }
   window, win;
   if (is_void(m)) m = mouse(,,"Click in window:");
   emin = 2000*(int(m(1)/2000.));
   nmax = int(2000*(ceil(m(2)/2000.)));
   if (!nodata) {
      ifinaldata = finaldata(data_box(finaldata.east/100.0, finaldata.north/100.0, emin, emin+2000, nmax-2000, nmax)); //Selects finaldata only from the clicked tile;

      // find the unique elements in the ifinaldata array
      ifinaldata = ifinaldata(sort(ifinaldata.rn));
      idx = unique(ifinaldata.rn);
      ifinaldata = ifinaldata(idx);
      ymd = soe2ymd(ifinaldata.soe(where(ifinaldata.soe == min(ifinaldata.soe)))); // finds the year-month-day of the lowest SOE value
      if (ymd(2) <=9) m = swrite(format="0%d", ymd(2));
      if (ymd(2) >9)  m = swrite(format="%d", ymd(2));
      if (ymd(3) <=9) d = swrite(format="0%d", ymd(3));
      if (ymd(3) >9)  d = swrite(format="%d", ymd(3));
      mdate = swrite(format="%d%s%s", ymd(1), m, d);
   } else {
      mdate = "yyyymmdd";
   }
   if (!curzone) {
      zone="void";
      write, "Please enter the current UTM zone: \n";
      read(zone); 
      curzone=0;
      sread(zone, format="%d", curzone);
   }
   zone = swrite(format="%d", long(curzone)); //Here zone was read as a string, converted to long and now back to string, but needed to make curzone global
   //zonel = utm_zone_letter(nmax); //gets zone letter from function in batch_process;
   type = "b"; //I still need to put in this part .. defaults to bathy for now.
   tilefname = swrite(format="t_e%d_n%d_%s_%s_%s_mf.pbd", emin, nmax, zone, mdate, type);
   temin = emin/1000;
   tnmax = nmax/1000;
   tmdate = strpart(mdate,5:);
   tilename = swrite(format="t_%d_%d_%s_%s_%s",temin,tnmax,zone,tmdate,type);

   if (_ytk) {
      //send tilefname to tk
      tkcmd, swrite(format="set tilefname %s",tilefname);
      tkcmd, swrite(format="set tilename %s",tilename);
   }
   return tilefname;		
}

func tile_location(m) {
/* DOCUMENT tile_location(m)

   Return the tile location in a 2 element linear array.

  Inputs:
    	   m   What's returned by mouse();

 Returns:
          tile  A 2 element integet array containing the tile
                numbers.

 See also: tile_file_name, draw_grid, show_grid_location
*/
   tile = array(int,2);
   tile(1) = int(m)(2) / 2000 * 2000;
   tile(2) = int(m)(1) / 2000 * 2000;
   return tile;
}

func sel_grid_area( r ) {
/* DOCUMENT sel_grid_area( r ) 
 */
   w = current_window();
   window,5; 
   res=mouse(, 1);
   x = int(res(1:3:2));
   y = int(res(2:4:2));

   ll = [x(min), y(min)];
   ur = [x(max), y(max)];
   ll;
   ur;
   img = array( long, ur(1)-ll(1)+1, ur(2)-ll(2)+1 );

   // Extract a list containing all the elements in the selection box
   q = where( (r).least > ll(1)*100 );
   qq = where( (r).least(q) < ur(1)*100 );
   q = q(qq);
   qq = where( (r).lnorth(q) > ll(2)*100 );
   q = q(qq);
   qq = where( (r).lnorth(q) < ur(2)*100 );
   q = q(qq);

   // q now holds a list of all elements within the selection box

   x = int( (r).least(q)+50)/100 + 1;  	// add 50cm, then convert from cm to m
   y = int((r).lnorth(q)+50)/100 + 1;
   z = (r).lelv(q); 

   z(max);
   z(avg);
   z(min);

   // insert elevations into the grid array 
   timer_init, tstamp;
   for (i=1; i<=numberof(x); i++ ) { 
      img( x(i)-ll(1), y(i)-ll(2)) = z(i); 
      timer_tick, tstamp, i, numberof(x);
   }

   window_select,w;
   return [&ll, &ur, &img ]
}
