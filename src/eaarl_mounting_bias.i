/*

 $Id$

   Range_bias

   Range_bias computed from 7-29-02 ground test.  The EAARL data was taken from
   pulses 8716:10810 which was captured from a static target at 101.1256 meters
   measured distance.  The EAARL centroid range values were averaged and then
   the actual slope distance to the target subtracted to yield the range_biasM.
   The rms noise on the range values used to compute the range_biasM was 3.19cm

   range_biasM is the measured range bias in Meters, and range_biasNS is the
 same bias expressed in Nanoseconds.
*/

write,"$Id$"

range_biasM =  0.7962;  // Laser range measurement bias.
range_biasNS=  range_biasM / NS2MAIR;
 scan_bias  =  0.0;     // The mounting bias of the scan encoder.
 roll_bias  = -1.40;    // The mounting bias of the instrument in the plane.
 pitch_bias = +0.5;     // pitch mounting bias
 yaw_bias   =  -3.0;     // Yaw mounting bias



