/*
  Id: wgs842nad83.i
  Converted to yorick from John Sonntag's C code.
  amar nayegandhi.
*/

 
func wgs842nad83(data) {
  /*DOUCMENT wgs842nad83(data)
   amar nayegandhi 07/09/03.
   this function converts coordinates from wgs84 (referenced to itrfxx) to the nad83 reference datum.
   INPUT:  data = A 2-D array of size (3,n).  The rows in the data array must be longitude (in degrees),latitude (in degrees),altitude (in meters).
   OUTPUT: nad83 = A 2-D array of the same size as the input array (3,n).  
   report all errors to /dev/null
  */
  
  //write, format="%12.8f\n",data(,1);
  //write, "\n";
  // convert the coordinates from geo to cart
  rcart = geod_cart(data);
  //write, format="%-16.8f\n",rcart(,1);
  //write, "\n";

  // convert the coordinates to NAD83 reference datum
  rnad83 = cart_wgs842nad83(rcart);
  //write, format="%12.8f\n",rnad83(,1);
  //write, "\n";

  // convert the coordinates from cart back to geo
  rgeo2 = cart_geod(rnad83);
  //write, format="%12.8f\n",rgeo2(,1);
  //write, "\n";

  return rgeo2;
}

func cart_wgs842nad83(rcart) {
  /*DOCUMENT wgs842nad83
   amar nayegandhi 07/09/03
   Converted to yorick from John Sonntags C code.
  */
  
  // define rotations and scale
  PI = atan(1.0)*4.0;
  rx = (-0.0275/60.0/60.0)*PI/180.0;
  ry = (-0.0101/60.0/60.0)*PI/180.0;
  rz = (-0.0114/60.0/60.0)*PI/180.0;
  d  = 0.0;

  // define rotation matrix
  rotmat = array(double, 3, 3)
  rotmat(1,1) = 1.0+d;
  rotmat(1,2) = -rz;
  rotmat(1,3) = ry;
  rotmat(2,1) = rz;
  rotmat(2,2) = 1.0+d;
  rotmat(2,3) = -rx;
  rotmat(3,1) = -ry;
  rotmat(3,2) = rx;
  rotmat(3,3) = 1.0+d;

  // perform rotation
  rnad83 = matvec(rotmat, rcart);

  // add origin offsets
  rnad83(1,) += 0.9738;
  rnad83(2,) += -1.9453;
  rnad83(3,) += -0.5486;
 

  return rnad83;
}

func matvec(rotmat, rcart) {
  /*DOCUMENT matvec(rotmac,rcart)
   amar nayegandhi 07/09/03.
  */
  rnad83 = rotmat(+,)*rcart(+,);
  return rnad83;
}
    
  
  
  
func geod_cart(data_in) {
  /*DOCUMENT geod_cart(rgeo1) 
   This function converts geodetic coordinates to cartesian coordinates.
   amar nayegandhi 07/08/03
   INPUT : rgeo1 = 2-dimensional input array (x,y,z) of size (3,n).
   OUTPUT: rcart = 2-dimensional output array (x,y,z) of same size (3,n).
   Converted to yorick from John Sonntags C code.
   
  */

  rgeo1 = data_in; 
  pi = atan(1.0)*4.0; //double precision pi
  a = 6378137.0; // semi-major axis
  b = 6356752.3141404; //semi-minor axis
  f = (a-b)/a;  // flattening factor
  e2 = 2*f - f*f; //eccentricity squared

  rgeo1(1,) = rgeo1(1,) * pi/180.0;
  rgeo1(2,) = rgeo1(2,) * pi/180.0;

  N = a/sqrt(1 - e2*(sin(rgeo1(2,)))^2);
  
  rcart = array(double, 3, numberof(rgeo1(1,)));
  rcart(1,) = (N + rgeo1(3,))*cos(rgeo1(2,))*cos(rgeo1(1,));
  rcart(2,) = (N + rgeo1(3,))*cos(rgeo1(2,))*sin(rgeo1(1,));
  rcart(3,) = (N*(1-e2)+rgeo1(3,))*sin(rgeo1(2,));

  return rcart;
}

func cart_geod(rnad83) {
  /*DOCUMENT cart_geod(rnad83)
   This function converts cartesian coordinates to geodetic coordinates.
   amar nayegandhi 07/08/03.
   INPUT : rnad83 = 2-dimensional input array (x,y,z) of size (3,n).
   OUTPUT: rgeo2 = 2-dimensional output array (x,y,z) of size (3,n).
   Converted to yorick from John Sonntags C code.
*/

 
  pi = atan(1.0)*4.0; //double precision pi
  a = 6378137.0; // semi-major axis
  b = 6356752.3141404; //semi-minor axis

  e1 = (a^2 - b^2)/(b^2); // e^12 in Peter Dana s formula
  f = (a-b)/a;  // flattening factor
  e2 = 2*f - f*f; //eccentricity squared

  p = sqrt(rnad83(1,)^2 + rnad83(2,)^2);
  theta = atan(rnad83(3,)*a, p*b);
  num = rnad83(3,) + e1*b*((sin(theta))^3);
  den = p - e2*a*((cos(theta))^3);
  rgeo2 = array(double, 3, numberof(rcart(1,)));
  rgeo2(2,) = atan(num,den);
  N = a/sqrt(1-e2*(sin(rgeo2(2,))*sin(rgeo2(2,))));
  rgeo2(1,) = atan(rnad83(2,),rnad83(1,));
  rgeo2(3,) = (p/cos(rgeo2(2,))) - N;
  rgeo2(2,) = rgeo2(2,)*180.0/pi;
  rgeo2(1,) = rgeo2(1,)*180.0/pi;

 return rgeo2;
}
