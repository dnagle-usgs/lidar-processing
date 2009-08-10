// 3/12/01am

// read and display eaarl waveform data
idfn = "/mnt/cdrom/200309-190918.tld"
idfn = "/data/0/200312-195643.tld"

func type5( f, a) {
  a +=2;		// account for phantom 16 bit word
 rastcnt++;
 for (ii=0; ii<119; ii++ ) {
  i32 = long(0);
  i16 = short(0);
  i8x5= array(char,5);
  i16x3=array(short,3);
  px = array(PIX, 1);
  blen = char(0);
  b = a;
  n = _read( f, a, i32 );  a+=sizeof(i32);
write,format=" rastcnt=%d ii=%d %8x\n", rastcnt, ii, i32
  nw = (i32>>24)  & 0xff;
  ot = (i32 ) & 0x00ffffff;
  n = _read( f, a, i8x5 ); a+=sizeof(i8x5);
  n = _read( f, a, i16x3 ); a+=sizeof(i16x3);
  a +=1; //fix padding
  n = _read( f, a,  blen );  a+=sizeof(blen);
/*
  write,format=": %4x %4x %4x %4x %4x %4x %4x %4x %4x %4x %4x",  
	ot, nw, 
	i8x5(1), i8x5(2), i8x5(3), i8x5(4), i8x5(5),
	i16x3(1), i16x3(2), i16x3(3), blen;
*/
  txwf = array(char, blen);
  n = _read( f, a, txwf);  a+=sizeof(txwf);
  _read, f, a, i16 ;  a+= sizeof(short);
  rx0  = array(char, i16);
  _read, f, a, rx0;  a+= sizeof(rx0);
  _read, f, a, i16 ;  a+= sizeof(short);
  rx1  = array(char, i16);
  _read, f, a, rx1;  a+= sizeof(rx1);
  _read, f, a, i16 ;  a+= sizeof(short);
  rx2  = array(char, i16);
  _read, f, a, rx2;  a+= sizeof(rx2);
  _read, f, a, i16 ;  a+= sizeof(short);
  rx3  = array(char, i16);
  _read, f, a, rx3;  a+= sizeof(rx3);
fma;
 plg,txwf,marks=0, color="green"
 plg,rx0,marks=0
 plmk,rx0,msize=.2
 plg,rx1,marks=0, color="red"
 plg,rx2,marks=0, color="blue"
 plg,rx3,marks=0, color="magenta"
 pause,1
}
}

   i32 = long(0);
    addr =   long(0);
      tl =   long(0);
 seconds =   long(0);
fseconds =   long(0);
  raster =   long(0);
     sfr =   array(long, 3);	// seconds, fractionals, raster
    npix =   short(0);

f = open( idfn, "rb");

struct T5 {
  long tl;		// lsb=type, rest is len
  long secs;
  long fsecs;
  long raster;
  short npixels;	// msbit is digitizer 0 or 1
};
add_member, f, "T5", 0, "tl", long
add_member, f, "T5", -1, "secs", long
add_member, f, "T5", -1, "fsecs", long
add_member, f, "T5", -1, "raster", long
add_member, f, "T5", -1, "npixels", short

struct PIX {
 long tmn;		// lsb=nwaveforms, upper 24 are offset_time
 char txbias;		//
 char rxbias(4);
 short scan_angle;
 short wf_offset;
 short len;
};
add_member, f, "PIX", 0, "tmn", long
add_member, f, "PIX", -1, "txbias", char
add_member, f, "PIX", -1, "rxbias", char, 4
add_member, f, "PIX", -1, "scan_angle", short 
add_member, f, "PIX", -1, "wf_offset", short 
add_member, f, "PIX",  -1, "len", short 
rastcnt = 0;
window,0
limits,0,30,255,0
redraw

 while (1) {
  a = addr;
  n = _read( f, addr, tl ); a+= sizeof(long);	// get seconds;
  if ( catch(0x02) ) {
    break;
  }
  t = (tl & 0xff000000) >> 24;			// type
  l = tl &  0x00ffffff;				// len
  n = _read( f, a, sfr ); a+= sizeof(sfr);	// get ;
  npix = short(0);
  n = _read( f, a, npix ); a+= sizeof(npix);	// get npix
  dig = (npix>>15) & 0x1;
  npix &= 0x7fff;
  write,format="\n%5d %5d %8x %8x %8d %d %d",
	t,l,sfr(1), sfr(2), sfr(3), npix, dig;
  if ( t == 5 ) n = type5( f, a );
  addr += l;
//  break;
 }




