/*
   $Id$

  Dave Munro wrote this stuff.
*/


func fillin(z, &done)
{
   good = (z>-9.)&(z<-0.5);
   bad = where(!good);
   done = !numberof(bad);
   if (done) return z;
   count = double(good)(zcen,zcen)(pcen,pcen);
   z0 = z;
   z0(bad) = 0.;
   z0bar = z0(zcen,zcen)(pcen,pcen)/(count+!count);
   z0(bad) = z0bar(bad);
   return z0;
}
 
func fillall(z, quiet=)
{
   local done;
   count = 0;
   for (done=0 ; !done ; count++) z = fillin(z, done);
   if (!quiet) write, "number of iterations =",count;
   return z;
}


