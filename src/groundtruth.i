// vim: set ts=3 sts=3 sw=3 ai sr et:
require, "eaarl.i";

func gt_extract_comparisons(model, truth, modelmode=, truthmode=, radius=) {
/* DOCUMENT gt_extract_comparisons(model, truth, modelmode=, truthmode=,
   radius=)

   Returns a group object with the comparison results for the given MODEL
   against the given TRUTH.

   The parameters, MODEL and TRUTH, must be values suitable for passing to
   data2xyz. This means they can be arrays of type VEG__, FS, etc. They can
   also be 3xn or nx3 arrays of doubles.

   Options MODELMODE= and TRUTHMODE= specify how to interpret MODEL and TRUTH,
   respectively. Defaults are:
      modelmode="fs"
      truthmode="fs"
   However, any of the normal values may be passed ("be", "ba", etc.).

   RADIUS= is the search radius to use about each truth point, in meters. It
   defaults to 1 meter.

   Return result is a group object with these members:
      truth - The elevation value from TRUTH.
      m_best - The elevation value from MODEL that is closest in value to
         TRUTH's elevation value, among those points within the RADIUS.
      m_nearest - The elevation value from MODEL that is spatially closest to
         TRUTH's x,y location.
      m_average - The average elevation value for the MODEL points within
         RADIUS of TRUTH.
      m_median - The median elevation value for the MODEL points within RADIUS
         of TRUTH.
*/
   extern curzone;
   local mx, my, mz, tx, ty, tz;
   default, radius, 1.;
   radius = double(radius);

   // Use curzone if it's defined, otherwise arbitrarily make it 15. The zone
   // really doesn't matter since all we're using it for is to dummy out tile
   // names as part of partitioning.
   zone = curzone ? curzone : 15;

   data2xyz, model, mx, my, mz, mode=modelmode;
   data2xyz, truth, tx, ty, tz, mode=truthmode;

   // Eliminate model points outside of bbox+radius from truth points. Easy to
   // do, and results in huge savings if the model points cover a much larger
   // region than the truth points.
   w = data_box(mx, my, [tx(min),tx(max),ty(min),ty(max)] + radius*[-1,1,-1,1]);
   if(!numberof(w))
      error, "Points do not overlap";
   mx = mx(w);
   my = my(w);
   mz = mz(w);

   // We seek four results:
   //    best: The model elevation closest to truth
   //    nearest: The model elevation for the point spatially closest to truth
   //    average: Average of model elevations in radius about truth
   //    median: Median of model elevations in radius about truth
   m_best = m_nearest = m_average = m_median = array(double, dimsof(tx));

   // Some or all of the truth points may not have a model point within radius;
   // such points must be discarded. "keep" tracks which points have yielded
   // results.
   keep = array(char(0), dimsof(tx));

   // In order to reduce the overall number of point-to-point comparisons
   // necessary, the truth data is partitioned into successively smaller
   // regions. The corresponding model points are extracted for each partition.
   // This works especially well when the truth points are clustered in several
   // disparate areas.
   //
   // A stack is used to handle the partitioning. Each item in the stack is a
   // group object with three members:
   //    t - index list into the truth data for this set of points
   //    m - index list into the model data that corresponds to the above
   //    schemes - string array with the tiling schemes that need to be applied
   //          yet for this point cloud's partitioning
   //
   // When an item is popped off the stack, one of two things happens depending
   // on the number of schemes defined for it. If the number of schemes is
   // non-zero, then the truth points are partitioned with the first scheme in
   // the list. Each tile gets pushed onto the stack as a new item; each will
   // be provided with the model points that match the truth points' area as
   // well as with the array of remaining schemes that must be applied.
   //
   // If an item is popped that has no remaining schemes, then the points are
   // analyzed to extract the relevant model values for each truth value. These
   // values go in m_best, m_nearest, etc.
   stack = deque();
   stack, push, save(t=indgen(numberof(tx)), m=indgen(numberof(mx)),
      schemes=["it","dt","dtquad","dtcell"]);

   t0 = array(double, 3);
   timer, t0;
   tp = t0;
   while(stack(count,)) {
      top = stack(pop,);
      if(numberof(top.schemes)) {
         tiles = partition_by_tile(tx(top.t), ty(top.t), zone, top.schemes(1),
            buffer=0);
         names = h_keys(tiles);
         count = numberof(names);
         schemes = (numberof(top.schemes) > 1 ? top.schemes(2:) : []);
         for(i = 1; i <= count; i++) {
            t = top.t(tiles(names(i)));
            xmin = tx(t)(min) - radius;
            ymin = ty(t)(min) - radius;
            xmax = tx(t)(max) + radius;
            ymax = ty(t)(max) + radius;
            idx = data_box(mx(top.m), my(top.m), xmin, xmax, ymin, ymax);
            if(numberof(idx)) {
               m = top.m(idx);
               stack, push, save(t, m, schemes);
            }
         }
      } else {
         X = mx(top.m);
         Y = my(top.m);
         Z = mz(top.m);
         count = numberof(top.t);
         for(i = 1; i <= count; i++) {
            j = top.t(i);
            idx = find_points_in_radius(tx(j), ty(j), X, Y, radius=radius);
            if(!numberof(idx))
               continue;

            XP = X(idx);
            YP = Y(idx);
            ZP = Z(idx);

            keep(j) = 1;

            dist = abs(ZP - tz(j));
            m_best(j) = ZP(dist(mnx));

            dist = ((tx(j) - XP)^2 + (ty(j) - YP)^2) ^ .5;
            m_nearest(j) = ZP(dist(mnx));

            m_average(j) = ZP(avg);
            m_median(j) = median(ZP);
         }
      }
      // The timer_remaining call will be fairly inaccurate, but in a
      // pessimistic sense. There's a larger up-front cost due to the
      // partitioning. Still, in extremely large datasets, this is better than
      // nothing.
      if(anyof(match))
         timer_remaining, t0, numberof(where(match)), numberof(match), tp,
            interval=10;
   }
   timer_finished, t0;

   if(noneof(keep))
      return [];
   mx = my = mz = tx = ty = [];

   w = where(keep);
   truth = tz(w);
   m_best = m_best(w);
   m_nearest = m_nearest(w);
   m_average = m_average(w);
   m_median = m_median(w);

   return save(truth, m_best, m_nearest, m_average, m_median);
}

func gt_metrics(z1, z2, metrics) {
/* DOCUMENT gt_metrics(z1, z2, metrics)
   Returns an array of strings that are the metric values as requested by the
   given array METRICS. Z1 and Z2 must each be one-dimensional arrays of
   numbers. METRICS must be an array of strings.

   Valid metrics:
      "# points" - Number of points
      "COV" - Covariance of z1 and z2
      "Q1E" - First quartile of z2-z1
      "Q3E" - Third quartile of z2-z1
      "Median E" - Median of z2-z1
      "ME" - Average of z2-z1
      "Midhinge E" - Midhinge of z2-z1
      "Trimean E" - Trimean of z2-z1
      "IQME" - Interquartile mean of z2-z1
      "Pearson's R" - Perason's correlation coefficient for z1 and z2
      "Spearman's rho" - Spearman's correlation coefficient for z1 and z2
      "95% CI E" - 95% confidence interval for z2-z1
      "E skewness" - Skewness of z2-z1
      "E kurtosis" - Kurtosis of z2-z1
      "R^2" - R squared of z2 versus z1
      "RMSE" - Root-mean-squared of z2-z1

   For information about the statistics, SEE ALSO:
      covariance quartiles median midhinge trimean interquartile_mean
      pearson_correlation spearman_correlation confidence_interval_95 skewness
      kurtosis
*/
   count = numberof(metrics);
   result = array(string, count);
   zdif = z2 - z1;
   for(i = 1; i <= count; i++) {
      if(metrics(i) == "# points")
         result(i) = swrite(format="%d", numberof(z1));
      else if(metrics(i) == "COV")
         result(i) = swrite(format="%.3f", covariance(z1,z2));
      else if(metrics(i) == "Q1E")
         result(i) = swrite(format="%.3f", quartiles(zdif)(1));
      else if(metrics(i) == "Q3E")
         result(i) = swrite(format="%.3f", quartiles(zdif)(3));
      else if(metrics(i) == "Median E")
         result(i) = swrite(format="%.3f", median(zdif));
      else if(metrics(i) == "ME")
         result(i) = swrite(format="%.3f", zdif(avg));
      else if(metrics(i) == "Midhinge E")
         result(i) = swrite(format="%.3f", midhinge(zdif));
      else if(metrics(i) == "Trimean E")
         result(i) = swrite(format="%.3f", trimean(zdif));
      else if(metrics(i) == "IQME")
         result(i) = swrite(format="%.3f", interquartile_mean(zdif));
      else if(metrics(i) == "Pearson's R")
         result(i) = swrite(format="%.3f", pearson_correlation(z1,z2));
      else if(metrics(i) == "Spearman's rho")
         result(i) = swrite(format="%.3f", spearman_correlation(z1,z2));
      else if(metrics(i) == "95% CI E") {
         ci = confidence_interval_95(zdif);
         result(i) = swrite(format="%.3f to %.3f", ci(1), ci(2));
      } else if(metrics(i) == "E skewness")
         result(i) = swrite(format="%.3f", skewness(zdif));
      else if(metrics(i) == "E kurtosis")
         result(i) = swrite(format="%.3f", kurtosis(zdif));
      else if(metrics(i) == "R^2")
         result(i) = swrite(format="%.3f", r_squared(z2, z1));
      else if(metrics(i) == "RMSE")
         result(i) = swrite(format="%.3f", zdif(rms));
      else
         error, "Unknown metric: " + metrics(i);
   }
   return result;
}

func gt_scatterplot(z1, z2, win=, dofma=, title=, xtitle=, ytitle=,
scatterplot=, equality=, mean_error=, ci95=, linear_lsf=, quadratic_lsf=,
metrics=) {
/* DOCUMENT gt_scatterplot, z1, z2, win=, dofma=, title=, xtitle=, ytitle=,
   scatterplot=, equality=, mean_error=, ci95=, linear_lsf=, quadratic_lsf=,
   metrics=

   Plots a scatterplot of Z1 versus Z2, along with additional plots and
   metrics.

   Parameters:
      z1: A one-dimensional array of values. These are typically ground truth
         values and will be associated with the Y axis.
      z2: A one-dimensional array of values. These are typically model/lidar
         data values and will be associated with the X axis.

   General options:
      win= The window to plot in. Default is the current window.
      dofma= Specifies whether to clear before plotting. Valid settings:
            dofma=0     Do not clear
            dofma=1     Clear (default)
      title= Specifies a title for the plot. Examples:
            title="Fire Island Analysis"
            title=""    (default; this results in no title)
      xtitle= Specifies a title for the X axis. Examples:
            xtitle="Ground Truth Data (m)"   (default)
      ytitle= Specifies a title for the Y axis. Examples:
            ytitle="Lidar Data (m)"    (default)
      metrics= Specifies which metrics to plot. This should be an array of
         strings. Each string must be a valid metric for gt_metrics. Examples:
            metrics=["# points", "ME"]    (default)

   Plot options:
   These options each take a string as a value. The string should be formatted
   as detailed in parse_plopts.
      scatterplot= Scatter plot of z2 vs z1
            scatterplot="square black 0.2"   (default)
      equality= Equality line: x = y
            equality="dash black 1.0"
      mean_error= Mean error line
            mean_error="hide"
      ci95= 95% confidence interval lines about the mean error
            ci95="hide"
      linear_lsf= Linear least-squares-fit line
            linear_lsf="solid black 1.0"
      quadratic_lsf= Quadratic least-squares-fit line
            quadratic_lsf="hide"
*/
   local type, color, size;

   default, win, current_window();
   default, dofma, 1;
   default, title, string(0);
   default, xtitle, "Ground Truth Data (m)";
   default, ytitle, "Lidar Data (m)";
   default, scatterplot, "square black 0.2";
   default, equality, "dash black 1.0";
   default, mean_error, "hide";
   default, ci95, "hide";
   default, linear_lsf, "solid black 1.0";
   default, quadratic_lsf, "hide";
   default, metrics, ["# points", "RMSE", "ME", "R^2"];

   if(win < 0)
      win = 0;

   // z1 = truth; z2 = lidar
   zdif = z2 - z1;

   xbounds = [z1(min), z1(max)];
   ybounds = [z2(min), z2(max)];

   window, win;
   if(dofma) fma;

   parse_plopts, scatterplot, type, color, size;
   if(type != "hide")
      plmk, z2, z1, width=10, marker=type, color=color, msize=size;

   parse_plopts, equality, type, color, size;
   if(type != "hide")
      plg, xbounds, xbounds, type=type, color=color, width=size;

   parse_plopts, mean_error, type, color, size;
   if(type != "hide") {
      ME = zdif(avg);
      plg, xbounds + ME, xbounds, type=type, color=color, width=size;
   }

   parse_plopts, ci95, type, color, size;
   if(type != "hide") {
      CI = confidence_interval_95(zdif);
      plg, xbounds + CI(1), xbounds, type=type, color=color, width=size;
      plg, xbounds + CI(2), xbounds, type=type, color=color, width=size;
   }

   parse_plopts, linear_lsf, type, color, size;
   if(type != "hide") {
      c = poly1_fit(z2, z1, 1);
      plg, poly1(xbounds, c), xbounds, type=type, color=color, width=size;
   }

   parse_plopts, quadratic_lsf, type, color, size;
   if(type != "hide") {
      c = poly1_fit(z2, z1, 2);
      x = span(xbounds(1), xbounds(2), 100);
      plg, poly1(x, c), x, type=type, color=color, width=size;
   }

   if(!is_scalar(metrics)) {
      values = gt_metrics(z1, z2, metrics);
      w = where(strglob("*^*", metrics));
      if(numberof(w))
         metrics(w) += "^";
      display = strjoin(metrics + ": " + values, "\n");
      vp = viewport();
      plt, display, vp(1) + .01, vp(4) - .01, justify="LT", height=12;
   }

   if(strlen(title))
      pltitle, title;
   if(strlen(xtitle) || strlen(ytitle))
      xytitles, xtitle, ytitle;
   limits, square=1;
   limits;
}

func gt_report(comparisons, which, metrics=, title=, outfile=) {
   default, metrics, ["# points", "RMSE", "ME", "R^2"];
   fmt = swrite(format="%%%ds", strlen(metrics)(max));
   output = swrite(format=fmt, grow("", metrics));
   for(i = 1; i <= numberof(which); i++) {
      col = gt_metrics(comparisons.truth, comparisons("m_"+which(i)), metrics);
      col = grow(which(i), col);
      fmt = swrite(format="  %%%ds", strlen(col)(max));
      output += swrite(format=fmt, col);
   }

   if(!is_void(title) && strlen(title)) {
      indent = (strlen(output)(max) - strlen(title))/2;
      if(indent > 0)
         title = array(" ", indent)(sum) + title;
      output = grow(title, output);
   }

   if(outfile) {
      f = open(outfile, "w");
      write, f, format="%s\n", output;
      close, f;
   } else {
      write, format="%s\n", output;
   }
}
