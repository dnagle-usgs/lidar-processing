// vim: set ts=2 sts=2 sw=2 ai sr et:
#include "yapi.h"

#define LEVEL_SHORT_DIPS_KEYCT 2
void Y_level_short_dips(int nArgs)
{
  // level_short_dips(seq, dist=indgen(numberof(seq)), thresh=10)
  static char *knames[LEVEL_SHORT_DIPS_KEYCT+1] = {"dist", "thresh", 0};
  static long kglobs[LEVEL_SHORT_DIPS_KEYCT+1];

  double *seq, *dist, thresh;
  long count;

  {
    int kiargs[LEVEL_SHORT_DIPS_KEYCT];
    yarg_kw_init(knames, kglobs, kiargs);

    int iarg_seq = yarg_kw(nArgs-1, kglobs, kiargs);
    if(iarg_seq == -1) y_error("must provide 1 argument");
    if(yarg_kw(iarg_seq-1, kglobs, kiargs) != -1) {
      y_error("must provide only 1 argument");
    }

    // Retrieve seq
    long dims[Y_DIMSIZE];
    seq = ygeta_d(iarg_seq, &count, dims);

    // Retrieve thresh or use default of 10
    thresh = (kiargs[1] == -1) ? 10. : ygets_d(kiargs[1]);

    // Retrieve dist, if provided.
    if(kiargs[0] == -1) {
      // If not provided, push a new array on the stack to use for dist. Then
      // increment iarg_seq to reflect it's new position (in case we need it
      // later).
      dist = ypush_d(dims);
      long i;
      for(i = 0; i < count; i++)
        dist[i] = i+1;
      iarg_seq++;
    } else {
      // If provided, then retrieve and make sure the count matches. Don't
      // worry about checking dimensions.
      long count_dist;
      dist = ygeta_d(kiargs[0], &count_dist, 0);
      if(count_dist != count)
        y_error("array for dist= must have same size as seq");
    }

    // If seq is a scratch variable, re-use for return variable (saves us from
    // having to copy it). Otherwise, push a new array on the stack for the
    // return value and copy seq to it; then use that as seq instead.
    if(yarg_scratch(iarg_seq)) {
      yarg_swap(0, iarg_seq);
    } else {
      double *tmp = ypush_d(dims);
      long i;
      for(i = 0; i < count; i++)
        tmp[i] = seq[i];
      seq = tmp;
    }
  }

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
