require, "eaarl.i";
write, "$Id$";

func batch_pbd2las(con_dir, searchstr=, proj_id=, v_maj=, v_min=, cday=, cyear=, typ=, zone_nbr=, nad83=, wgs84N=, wgs84S=, buffer=, qq=) {
/* DOCUMENT batch_pbd2las(con_dir, searchstr=, proj_id=, v_maj=, v_min=, cday=, cyear=, typ=, zone_nbr=, nad83=, wgs84N=, wgs84S=, buffer=, qq=, atm=)
        dir, string, directory containing pbd files wanted for conversion

        searchstr, string, search string for the pbd files that you would like converted ( default = *.pbd ) 

        proj_id, char[8], optional LAS header variable.  Useful to group multiple datasets for a unique project.
                          Size limit is 8 bytes so only 8 characters.  Default is NULL.
     
        v_maj, char, version major e.g. if this is version 1.2 then the major will be 1, default is 1
        
        v_min, char, version minor with above example minor = 2, default is 0

        cday, short, file creation day of year (GMT time)

        cyear, short, file creation year 

        typ, int, type of data set, 1 = first surface
                                    2 = bare earth
                                    3 = bathymetry

        zone_nbr, int, UTM Zone number.  Vars nad83, wgs84N, wgs84S tell which datum the data is in.  Make
                sure that you set whichever datum that it is in equal to 1.  It defaults to nad83 if a zone number
                is input without selecting a datum.

        buffer, specifies a buffer in meters to apply to tile boundary; if set to -1 (the default), the data will be used as-is

        qq, if 1 it specifies that the data is in quarter-quad format instead of 2k tile format; if 0, it specifies that the data is in 2k tile format (this is the default)

        created by Jim Lebonitte
        last edited on 8/29/07 by Jim Lebonitte
        modified 2008-10-29 by David Nagle to add buffer=, qq=
*/
  default, buffer, -1;
  default, qq, 0;
  if(is_void(searchstr)) {
          searchstr="*.pbd"
  } 


  command = swrite(format="find %s -name '%s'", con_dir, searchstr);

  files = ""
  s = array(string,10000);
  f = popen(command, 0);
  nn = read(f,format="%s",s);
  s = s(where(s));
  numfiles = numberof(s);
  newline = "\n"
  data=[];

  for(i=1; i<=numfiles; i++) {
        
         filename=s(i);
         pbd2las(filename, proj_id=proj_id, v_maj=v_maj, v_min=v_min, cday=cday, cyear=cyear, typ=typ, zone_nbr=zone_nbr, nad83=nad83, wgs84N=wgs84N, wgs84S=wgs84S, buffer=buffer, qq=qq) 

  }

}
func pbd2las(fname, proj_id=, v_maj=, v_min=, cday=, cyear=, typ=, zone_nbr=, nad83=, wgs84N=, wgs84S=, buffer=, qq=) {
/* DOCUMENT pbd2las(fname, proj_id=, v_maj=, v_min=, cday=, cyear=, typ=, zone_nbr=, nad83=, wgs84N=, wgs84S=, buffer=, qq=)
        
        Purpose:  This function creates a .las file that contains the LiDAR point records from a LiDAR data
                  variable in ALPS.  The .las binary file format has been determined by the ASPRS LiDAR
                  committee.

        proj_id, char[8], optional LAS header variable.  Useful to group multiple datasets for a unique project.
                          Size limit is 8 bytes so only 8 characters.  Default is NULL.
     
        v_maj, char, version major e.g. if this is version 1.2 then the major will be 1, default is 1
        
        v_min, char, version minor with above example minor = 2, default is 0

        cday, short, file creation day of year (GMT time)

        cyear, short, file creation year 

        typ, int, type of data set, 1 = first surface
                                    2 = bare earth
                                    3 = bathymetry    

        zone_nbr, int, UTM Zone number.  Vars nad83, wgs84N, wgs84S tell which datum the data is in.  Make
                sure that you set whichever datum that it is in equal to 1.  It defaults to nad83 if a zone number
                is input without selecting a datum.

        buffer, specifies a buffer in meters to apply to tile boundary; if set to -1 (the default), the data will be used as-is

        qq, if 1 it specifies that the data is in quarter-quad format instead of 2k tile format; if 0, it specifies that the data is in 2k tile format (this is the default)


        created by Jim Lebonitte
        last edited on 8/29/07 by Jim Lebonitte
        modified 2008-10-29 by David Nagle to add buffer=, qq=
*/

default, buffer, -1;
default, qq, 0;

if (is_void(proj_id)) {
  proj_id=array(char, 8)
} else {
  proj_id=as_chars(proj_id)
}

if (is_void(v_maj)) {
  v_maj=char(1);
}

if (is_void(v_min)) {
  v_min=char(0);
}

if( is_void(cday)) {
  cday=short(0)
}

if( is_void(cyear)) {
  cyear=short(0)
}

if( is_void(zone_nbr)) {
  zone_tag=short(32767)
}

if(!is_void(zone_nbr) && is_void(wgs84N) && is_void(wgs84S) && is_void(nad83)) {
  nad83=1
}

if(nad83==1) zone_tag=26903+(zone_nbr-3);
if(wgs84N==1) zone_tag=32601+zone_nbr;
if(wgs84S==1) zone_tag=32701+zone_nbr;

/*Opening .pbd file */ 

  f1=openb(fname);
  restore, f1, vname;
  data=get_member(f1, vname);
  close, f1;
  dvname=vname;

  // Restrict to a buffer
  if(buffer >= 0) {
    n = e = [];
    if(typ == 1 || typ == 2) {
      n = data.north;
      e = data.east;
    } else if(typ == 3) {
      n = data.lnorth;
      e = data.least;
    } else {
      error, "Invalid typ " + typ;
    }
    tail = file_tail(fname);
    idx = [];
    n = n/100.;
    e = e/100.;
    if(qq) {
      idx = extract_for_qq(n, e, qq2uz(tail), tail, buffer=buffer);
    } else {
      idx = extract_for_dt(n, e, tail, buffer=buffer);
    }
    n = e = tail = [];
    if(numberof(idx)) {
      data = data(idx);
      idx = [];
    } else {
      data = [];
      write, "No data within buffer, skipping " + file_tail(fname);
      return;
    }
  }

/*Creating .las file */

  a=split_path(fname, 0, ext=1)
  b=split_path(a(1), 0)
  las_fname=b(1)+b(2)+".las"
  f1=open(las_fname, "wb");
  bad_binary=las_fname+"L";
  popen("rm -rf "+ bad_binary, 0);


/*Writing .las header*/

  byt_count=0;
  file_sig=array(char, 4)
  
  file_sig(1)='L'
  file_sig(2)='A'
  file_sig(3)='S'
  file_sig(4)='F'

  _write, f1, byt_count, file_sig;
  byt_count+=4;
  
  _write, f1, byt_count, short(00);
  byt_count+=2;
  
  _write, f1, byt_count, short(00);
  byt_count+=2;

  _write, f1, byt_count, long(0000);
  byt_count+=4;

  _write, f1, byt_count, short(00);
  byt_count+=2;
  
  _write, f1, byt_count, short(00);
  byt_count+=2;

  _write, f1, byt_count, proj_id; 
  byt_count+=8;

  _write, f1, byt_count, v_maj;
  byt_count+=1;

  _write, f1, byt_count, v_min;
  byt_count+=1;

  sys_iden=array(char, 32)
  _write, f1, byt_count, sys_iden;
  byt_count+=32;

  gen_soft=array(char, 32)
  _write, f1, byt_count, gen_soft;
  byt_count+=32;

  _write, f1, byt_count, cday
  byt_count+=2;

  _write, f1, byt_count, cyear
  byt_count+=2;

  _write, f1, byt_count, short(227)
  byt_count+=2;

  _write, f1, byt_count, long(297)
  byt_count+=4;

  _write, f1, byt_count, long(1);
  byt_count+=4;
  
  _write, f1, byt_count, char(1);
  byt_count+=1; 

  _write , f1, byt_count, short(28);
  byt_count+=2;
 
  _write, f1, byt_count, long(numberof(data))
  byt_count+=4;

 /* For the number of records by return, even if it is the first return
    record, it does not mean that it is the first return laser pulse.  You
    need to look at the filename to determine which type of file this is (be, fs, ba).
  */
  
  num_returns=array(long, 5)
  num_returns(1)=numberof(data);
  num_returns(2)=0
  num_returns(3)=0
  num_returns(4)=0
  num_returns(5)=0
 
  _write, f1, byt_count, num_returns
  byt_count+=20

  _write, f1, byt_count, double(.01);
  byt_count+=8;
  
  _write, f1, byt_count, double(.01);
  byt_count+=8;

  _write, f1, byt_count, double(.01);
  byt_count+=8;

  _write, f1, byt_count, double(0);
  byt_count+=8;

  _write, f1, byt_count, double(0);
  byt_count+=8;

  _write, f1, byt_count, double(0);
  byt_count+=8;
  
  if (typ == 1) {
    _write, f1, byt_count, double(max(data.east));
    byt_count+=8;

    _write, f1, byt_count, double(min(data.east));
    byt_count+=8;

    _write, f1, byt_count, double(max(data.north));
    byt_count+=8;

    _write, f1, byt_count, double(min(data.north));
    byt_count+=8;

    _write, f1, byt_count, double(max(data.elevation));
    byt_count+=8;

    _write, f1, byt_count, double(min(data.elevation));
    byt_count+=8;
}
  if (typ == 2) {
    _write, f1, byt_count, double(max(data.least));
    byt_count+=8;

    _write, f1, byt_count, double(min(data.least));
    byt_count+=8;

    _write, f1, byt_count, double(max(data.lnorth));
    byt_count+=8;

    _write, f1, byt_count, double(min(data.lnorth));
    byt_count+=8;

    _write, f1, byt_count, double(max(data.lelv));
    byt_count+=8;

    _write, f1, byt_count, double(min(data.lelv));
    byt_count+=8;
}

  if (typ == 3) {
     
    _write, f1, byt_count, double(max(data.east));
    byt_count+=8;

    _write, f1, byt_count, double(min(data.east));
    byt_count+=8;

    _write, f1, byt_count, double(max(data.north));
    byt_count+=8;

    _write, f1, byt_count, double(min(data.north));
    byt_count+=8;

    _write, f1, byt_count, double(max(data.elevation + data.depth));
    byt_count+=8;

    _write, f1, byt_count, double(min(data.elevation + data.depth));
    byt_count+=8;
}


/* Start of variable length records */
 
  _write, f1, byt_count, short(00);
  byt_count+=2;

  user_id=array(char, 16);
  user_id(1)='L'
  user_id(2)='A'
  user_id(3)='S'
  user_id(4)='F'
  user_id(5)='_'
  user_id(6)='P'
  user_id(7)='r'
  user_id(8)='o'
  user_id(9)='j'
  user_id(10)='e'
  user_id(11)='c'
  user_id(12)='t'
  user_id(13)='i'
  user_id(14)='o'
  user_id(15)='n'

  _write, f1, byt_count,  user_id;
  byt_count+=16;

  _write, f1, byt_count, short(34735);
  byt_count+=2;

  _write, f1, byt_count, short(70);
  byt_count+=2;

  description=array(char, 32);
  
  _write, f1, byt_count, description;
  byt_count+=32;

  a = array(short, 8); 
  a(1)=short(1);
  a(2)=short(1);
  a(3)=short(0);
  a(4)=short(1);

  a(5)=short(zone_tag);
  a(6)=short(0);
  a(7)=short(1);
  a(8)=short(zone_tag);

  _write, f1, byt_count, a;
  byt_count+=16;

 
  /* Start of point data */

  for(i=0; i<(numberof(data)); i++) {
        
        message = swrite(format="Point %i out of %i\r", i, numberof(data));
 
        if (typ==1) {
                _write, f1, byt_count, long(data(i).east);
                byt_count+=4;
                _write, f1, byt_count, long(data(i).north);
                byt_count+=4;
                _write, f1, byt_count, long(data(i).elevation);                
                byt_count+=4;
                _write, f1, byt_count, short(data(i).fint);
                byt_count+=2;
        }
        if (typ==2) {
                _write, f1, byt_count, long(data(i).least);
                byt_count+=4;
                _write, f1, byt_count, long(data(i).lnorth);
                byt_count+=4;
                _write, f1, byt_count, long(data(i).lelv);                
                byt_count+=4;
                _write, f1, byt_count, short(data(i).lint);
                byt_count+=2;
        }
        if (typ==3) {
                
                _write, f1, byt_count, long(data(i).east);
                byt_count+=4;
                _write, f1, byt_count, long(data(i).north);
                byt_count+=4;
                _write, f1, byt_count, long(data(i).elevation + data(i).depth);                
                byt_count+=4;
                _write, f1, byt_count, short(0);
                byt_count+=2;

        }

        if (i%1000 == 0) write, message;
       
       /* Determining positive or negative scan direction */
        if(structof(data) == ATM2) {
               s_dir = []; // Making a guess on this, since it wasn't
                           // previously defined.
        } else {
               s_dir=data(i).rn%(0xffffff); 

               if( (s_dir%2) == 0) {
                         s_dir=1;
               } else {
                         s_dir=0;
               }
        }


        /*Determing pulse number in the raster scan*/

        if (structof(data) != ATM2) {
          s_num=data(i).rn/(0xffffff); 
          if(s_dir == 0 && (s_num != 1 || s_num != 120)) {
                fl_data=char(10010000);
                _write, f1, byt_count, fl_data;
                byt_count++;
          } else if(s_dir == 1 && (s_num != 1 || s_num != 120)) {
                fl_data=char(10010010);
                _write, f1, byt_count, fl_data;
                byt_count++;
          } else if(s_dir == 1 && (s_num == 1 || s_num == 120)) {
                fl_data=char(10010011);
                _write, f1, byt_count, fl_data;
                byt_count++;
          } else if(s_dir == 0 && (s_num == 1 || s_num == 120)) {
                fl_data=char(10010001);
                _write, f1, byt_count, fl_data;
                byt_count++;
          } else {
                fl_data=char(00000000);
                _write, f1, byt_count, fl_data;
                byt_count++;
          } 
        } else {
                // scan direction flag
                _write, f1, byt_count, char(0);
                byt_count++;
        }

        // classification 
        _write, f1, byt_count, char(0);
        byt_count++;

        // scan angle rank
        if (structof(data) != ATM2) {
                scan_ang=((s_num-60)*.375)
                _write, f1, byt_count, char(scan_ang);
        } else {
                _write, f1, byt_count, char(0);
        }
        byt_count++;

        _write, f1, byt_count, char(0);
        byt_count++;

        _write, f1, byt_count, short(0);
        byt_count+=2;
        
        _write, f1, byt_count, double(data(i).soe);
        byt_count+=8; 
 
  }  /*End of for loop*/

f1=[];

} 
