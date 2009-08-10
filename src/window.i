func gga_window ( ck ) {
// Find all latitudes in the window
 q  = where( gga(2,) < ck(2) );
 q1 = where( gga(2,q) > ck(4));
 q = q(q1);

// Now find the longitudes in the window
 q1 = where( gga(3,q) < ck(3) )
 q = q(q1)

 q1 = where( gga(3, q) > ck(1) )
 q = q(q1)
 return q;
}

func select_gga ( s=)  {
ck = mouse(1,1);
q = gga_window(ck)
plmk,gga(2,q),gga(3,q),msize=.2,color="green"
return q
}



pth  = "/data/0/6-21-01/"
ls = "ls " + pth + "/eaarl/*.tld"


