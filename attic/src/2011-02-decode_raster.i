// vim: set ts=3 sts=3 sw=3 ai sr et:
/******************************************************************************\
* This file was created in the attic on 2011-02-22. Function decode_raster was *
* moved here from edb_access.i. It was replaced by a refactored version of the *
* function that does the same thing.                                           *
\******************************************************************************/

func decode_raster(r) {
/* DOCUMENT decode_raster(r)
   Inputs:  r      ; r is an edb raster data variable
   Returns:
     decode_raster returns a RAST array of data.

Type RAST to see whats in the RAST structure.

Usage:
  r = get_erast(rn = rn ); // get a raster from the database
  rp = get_erast(rn = rn ); fma; drast(rp); rn +=1

Examples using the result data:
   Plot rx waveform 60 channel 1:  plg,(*p.rx(60)) (,1)
   Plot irange values:             plmk,p.irange(1:0)
   Plot sa values:                 plmk,p.sa(1:0)


 To extract waveform 1 from pixel 60 and assign to w:
   w = (*p.rx(60))(,1)

 To extract, convert to integer, and remove bias from pixel 60, ch 1 use:
   w = *p.rx(60,1)
   w = int((~w+1) - (~w(1)+1));

 History:
   2/7/02 ww Modified to check for short rasters and return an empty one if
          short one was found.  The problem occured reading 9-7-01 data.  It
      may have been caused by data system lockup.

*/
   extern eaarl_time_offset, tca;
   local rasternbr, type, len;

   return_raster = array(RAST,1);
   irange = array(int, 120);
   sa = array(int, 120);
   offset_time = array(int, 120);

   len = i24(r, 1);           // raster length
   type= r(4);                // raster type id (should be 5 )
   if(type != 5) {
      write, format="Raster %d has invalid type (%d) Len:%d\n",
         rasternbr, type, len;
      return return_raster;
   }

   if(len < 20)               // return empty raster.
      return return_raster;   // failed.

   seconds = i32(r, 5);             // raster seconds of the day
   seconds += eaarl_time_offset;    // correct for time set errors.

   fseconds = i32(r, 9);            // raster fractional seconds 1.6us lsb
   rasternbr = i32(r, 13);          // raster number
   npixels = i16(r,17)&0x7fff;      // number of pixels
   digitizer = (i16(r,17)>>15)&0x1; // digitizer
   a = 19;                          // byte starting point for waveform data

   if(anyof([rasternbr, fseconds, npixels] < 0))
      return return_raster;
   if(npixels > 120)
      return return_raster;
   if(seconds(1) < 0)
      return return_raster;

   if((!is_void(tca)) && (numberof(tca) > rasternbr))
      seconds = seconds+tca(rasternbr);

   for(i = 1; i <= npixels - 1; i++) { // loop thru entire set of pixels
      offset_time(i) = i32(r, a);   a+=4; // fractional time of day since gps 1hz
      txb = r(a);                   a++;  // transmit bias value
      rxb = r(a:a+3);               a+=4; // waveform bias array
      sa(i) = i16(r, a);            a+=2; // shaft angle values
      irange(i) = i16(r, a);        a+=2; // integer NS range value
      plen = i16(r, a);             a+=2;
      wa = a;                             // starting waveform index (wa)
      a = a + plen;                       // use plen to skip to next pulse
      txlen = r(wa);                wa++; // transmit len is 8 bits max

      if(txlen <= 0) {
         write, format=" (txlen<=0) raster:%d edb_access.i:decode_raster(%d). Channel 1  Bad rxlen value (%d) i=%d\n", rasternbr, txlen, wa, i;
         break;
      }

      txwf = r(wa:wa+txlen-1);            // get the transmit waveform
      wa += txlen;                        // update wf address to first rx waveform
      rxlen = i16(r,wa);         wa+=2;   // get 1st waveform and update wa to next

      if(rxlen <= 0) {
         write, format=" (rxlen<-0)raster:%d edb_access.i:decode_raster(%d). Channel 1  Bad rxlen value (%d) i=%d\n", rasternbr, rxlen, wa, i;
         break;
      }

      rx = array(char, rxlen, 4);   // get all four return waveform bias values
      rxr = r(wa: wa + rxlen -1);
      if (numberof(rxr) != numberof(rx(,1))) break;
      rx(,1) = rxr;  // get first waveform
      wa += rxlen;         // update wa pointer to next
      rxlen = i16(r,wa); wa += 2;

      if(rxlen <= 0) {
         write, format=" raster:%d edb_access.i:decode_raster(%d). Channel 2  Bad rxlen value (%d) i=%d\n", rasternbr, rxlen, wa, i;
         break;
      }

      rxr = r(wa: wa + rxlen -1);
      if (numberof(rxr) != numberof(rx(,2))) break;
      rx(,2) = rxr;  // get first waveform
      wa += rxlen;
      rxlen = i16(r,wa); wa += 2;

      if(rxlen <= 0) {
         write, format=" raster:%d edb_access.i:decode_raster(%d). Channel 3  Bad rxlen value (%d) i=%d\n",
            rasternbr, rxlen, wa, i ;
         break;
      }

      rxr = r(wa: wa + rxlen -1);
      if (numberof(rxr) != numberof(rx(,3))) break;
      rx(,3) = rxr;  // get first waveform
      return_raster.tx(i) = &txwf;
      return_raster.rx(i,1) = &rx(,1);
      return_raster.rx(i,2) = &rx(,2);
      return_raster.rx(i,3) = &rx(,3);
      return_raster.rx(i,4) = &rx(,4);
      return_raster.rxbias(i,) = rxb;
      /*****
        write,format="\n%d %d %d %d %d %d",
        i, offset_time, sa(i), irange(i), txlen , rxlen      */
   }
   return_raster.offset_time  = ((offset_time & 0x00ffffff)
                                 + fseconds) * 1.6e-6 + seconds;
   return_raster.irange    = irange;
   return_raster.sa        = sa;
   return_raster.digitizer = digitizer;
   return_raster.soe       = seconds;
   return_raster.rasternbr = rasternbr;
   return_raster.npixels   = npixels;
   return return_raster;
}
