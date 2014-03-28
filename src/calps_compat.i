// vim: set ts=2 sts=2 sw=2 ai sr et:

// This file, and the files under calps/, provide some measure of
// backwards-compatibility to ALPS with respect to changes in the compiled
// C-ALPS Yorick plugin.
//
// All functions defined in files under calps/ are considered deprecated.
// Except in unusual circumstances, they will NOT be maintained. If you find a
// bug in a Yorick compatibility function corresponding to a C-ALPS function
// you don't have in your local install, then that means you should upgrade
// ALPS to use the latest C-ALPS plugin and the corresponding Yorick
// compatibility function should be removed.
//
// Which is to say, C-ALPS is mandatory for ALPS. The calps/ directory exists
// to provide *short term* compatibility, since it can be a hassle to
// immediately upgrade C-ALPS every time a change is made.
//
// Yorick compatibility functions may eventually be removed, typically about a
// year after the C-ALPS function was implemented.

if(is_func(calps_compatibility)) {
  if(calps_compatibility() < 2) {
    // in version 1, unique seg faults on nil string
    unique = [];
  }
  if(calps_compatibility() < 3) {
    // in version 2, wf_centroid seg faults on subroutine form of wf_centroid
    wf_centroid = [];
  }
}

// Added 2013-03-11
if(!is_func(interp_angles))
  require, "calps/interp_angles.i";

// Added 2013-03-12
if(!is_func(level_short_dips))
  require, "calps/level_short_dips.i";

// Added 2013-03-28
if(!is_func(unique))
  require, "calps/unique.i";

// Added 2013-10-21
if(!is_func(wf_centroid))
  require, "calps/wf_centroid.i";

// Added 2014-03-28
// Back up msort, if msort is interpreted
if(is_func(msort) == 1) ymsort = msort;
// Clobber msort with timsort, if timsort is defined
if(is_func(timsort)) msort = timsort;
// Assign msort to ymsort, if needed
if(!is_func(msort) && is_func(ymsort)) msort = ymsort;

// Added 2014-03-28
if(is_func(timsort_obj)) msort_obj = timsort_obj;
if(!is_func(msort_obj))
  require, "calps/msort_obj.i";

// Added 2014-03-28
if(!is_func(sortedness))
  require, "calps/sortedness.i";
