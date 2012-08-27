// vim: set tabstop=2 softtabstop=2 shiftwidth=2 autoindent shiftround expandtab:
#include "yapi.h"

// See documentation for the Yorick function level_short_dips to find out what
// this does. This is available in Yorick as _ylevel_short_dips.
// Argument *seg is modified.
void level_short_dips(double *seq, double *dist, double thresh, long count)
{
  long pass, r1, r2, i, j;
  double b1, b2, lower, upper;

  // Must make two passes
  // First pass will miss points that are near edges of long dips but will fill
  // their centers (which allows the second pass to then fill the rest).
  for(pass = 1; pass <= 2; pass++) {
    r1 = r2 = 0;
    for(i = 0; i < count; i++) {
      b1 = dist[i] - thresh;
      b2 = dist[i] + thresh;

      // Bring lower bound within range
      while(r1 < count && dist[r1] < b1)
        r1++;

      // Push upper bound /just/ out of range, then bring it back in
      while(r2 < count && dist[r2] < b2)
        r2++;
      r2--;

      // Determine upper and lower max
      lower = seq[r1];
      for(j = i; j > r1; j--)
        if(seq[j] > lower)
          lower = seq[j];
      upper = seq[r2];
      for(j = i; j < r2; j++)
        if(seq[j] > upper)
          upper = seq[j];

      // If both lower and upper are higher than the current value, then set
      // the current value to the lower of the upper and lower.
      if(upper > seq[i] && lower > seq[i]) {
        if(upper > lower)
          seq[i] = lower;
        else
          seq[i] = upper;
      }
    }
  }
}
