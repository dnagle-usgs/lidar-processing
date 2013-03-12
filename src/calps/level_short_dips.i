// vim: set ts=2 sts=2 sw=2 ai sr et:

func nocalps_level_short_dips(seq, dist=, thresh=) {
/* DOCUMENT leveled = level_short_dips(seq, dist=, thresh=)
  Removes short "dips" in a data array, smoothing out some of its "noise".

  seq should be a 1-dimensional array of numerical values. For example:
    seq=[4,4,4,3,3,4,4,4,5,5,5,6,5,5]

  The sequnce of "3,3" in the above is a short "dip". This function is
  intended to smooth that sort of thing out:
    leveled=[4,4,4,4,4,4,4,4,5,5,5,6,5,5]

  Short peaks will be left alone; only short dips will be leveled.

  Parameter:
    seq: An array of numbers with values to be smoothed out.

  Options:
    dist= If provided, this must be the same length of seq. It defaults to
      [1,2,3...numberof(seq)]. This is used with thresh to determine which
      items on either side of a value are used for comparisons. This array
      is the cummulative differences of distances from point to point. (So
      the default assumes they are equally spaced.)
    thresh= The threshold for how far on either side of a value the algorithm
      should look for determining whether it's a dip. Default is 10.

  Examples:
    > seq = [2,2,1,0,0,0,0,0,1,2,2,1,1,2,2,3]
    > seq
    [2,2,1,0,0,0,0,0,1,2,2,1,1,2,2,3]
    > level_short_dips(seq, thresh=2)
    [2,2,1,0,0,0,0,0,1,2,2,2,2,2,2,3]
    > level_short_dips(seq, thresh=4)
    [2,2,1,1,1,1,1,1,1,2,2,2,2,2,2,3]
    > level_short_dips(seq, thresh=5)
    [2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,3]
    > dist = [2,1,1,2,1,1,2,1,1,2,1,1,2,1,1](cum)
    > dist
    [0,2,3,4,6,7,8,10,11,12,14,15,16,18,19,20]
    > level_short_dips(seq, thresh=4, dist=dist)
    [2,2,1,0,0,0,0,0,1,2,2,2,2,2,2,3]
*/
// If you change this documentation, be sure to also change the documentation
// in calps.i.

  default, dist, indgen(numberof(seq));
  default, thresh, 10;

  // We don't want to change the original array, so forcibly create new
  // instance.
  seq = (seq);

  if(is_func(_ylevel_short_dips)) {
    seq = double(seq);
    _ylevel_short_dips, seq, dist, thresh, numberof(seq);
    return seq;
  }

  // Must make two passes
  // Pass one will miss points that are near the edges of long dips but will
  // fill their centers.
  for(pass = 1; pass <= 2; pass++) {
    r1 = r2 = 1;
    for(i = 1; i <= count; i++) {
      b1 = dist(i) - thresh;
      b2 = dist(i) + thresh;

      // Bring the lower bound within range
      while(r1 <= count && dist(r1) < b1)
        r1++;

      // Push the upper bound /just/ out of range then bring it back in
      while(r2 <= count && dist(r2) < b2)
        r2++;
      r2--;

      // Determine upper and lower max
      lower = seq(r1:i)(max);
      upper = seq(i:r2)(max);

      // Get median value among current and two maxes
      medmax = median([seq(i), lower, upper]);

      // If the median is higher than our current value, change it
      if(seq(i) < medmax)
        seq(i) = medmax;
    }
  }

  return seq;
}

if(!is_func(level_short_dips))
  level_short_dips = nocalps_level_short_dips;
