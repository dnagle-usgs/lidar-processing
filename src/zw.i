/*
  $Id$

    Review EAARL waveform data.

*/


//window,0,style="eaarl1.gs",width=300,height=300
window,0
limits,0,30,-10,270
//window,1,style="eaarl1.gs",width=300,height=300
window,1
limits,0,20,-10,270


fn = "200602-191645"
dd = "./"
func lf { 
 extern idxa, fd;
   f = open(dd+fn+".idx", "rb"); 
   len = long(0);
   _read,f,0,len
   len
   idxa = array(long, 2, len );
   _read,f,4,idxa
   fd = open( dd+fn+".tld", "rb" );
}

func f {
 extern pn; 
 pn
 pwf,pn;
 pn++;
}

func r {
 extern pn; 
 pn--
 pn
 pwf,pn
}

func get_irange ( ad ) {
extern idxa,wf_offset
adr = idxa(2,ad);
wf = array(char, 100);
n = _read(fd, adr, wf);
wf_offset = wf(12) + wf(13)*256
return wf_offset
}


func pwf( ad ) {
extern idxa,wf,txwf,wf_offset,scan_angle
extern rx0, rx1,rx2,rx3
adr = idxa(2,ad);
wf = array(char, 2000);
n = _read(fd, adr, wf);
offset_time = wf(2)*256 + (wf(1)) ; 
wf_offset = wf(12) + wf(13)*256
scan_angle = wf(10) + wf(11)*256;
if ( scan_angle >= 32768 ) scan_angle = scan_angle - 65536;
txlen = wf(16)-2;
txwf = wf(17:18+txlen);
rxlen = array(short, 4);
p = 33; 
l = wf(p) +  (wf(p+1)<<8);
p += 2;
rx0 = ~wf(p:p+l-1);

p += l; l = wf(p) +  (wf(p+1)<<8);
p += 2;
rx1 = ~wf(p:p+l-1);

p += l; l = wf(p) +  (wf(p+1)<<8);
p += 2;
rx2 = ~wf(p:p+l-1);

p += l; l = wf(p) +  (wf(p+1)<<8);
p += 2;
rx3 = ~wf(p:p+l-1);

window,0
fma
plg,rx0,color="black",marks=0
plmk,rx0,color="black",msize=.2,marker=1
plg,rx1,color="blue",marks=0
plmk,rx1,color="blue",msize=0.2,marker=1
plg,rx2,color="red",marks=0
plmk,rx2,color="red",msize=0.2,marker=1
plg,rx3,color="magenta",marks=0
plmk,rx3,color="magenta",msize=0.2,marker=1
str = "";
str = swrite( format="RX N:%d Irge:%5d Sa:%d tm:%10.6f", 
        ad, wf_offset, scan_angle, offset_time*1.6e-6);
str
pltitle,str
window,1
fma
plg,~txwf,marks=0
plmk,~txwf,msize=.25, marker=1
}



