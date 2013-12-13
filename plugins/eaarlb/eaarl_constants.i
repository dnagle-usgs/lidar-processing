// vim: set ts=2 sts=2 sw=2 ai sr et:

// EAARL system constants
local REV, SAD, SAD2;
/* DOCUMENT
  EAARL system constants:
    REV   Counts for 360 degrees of scanner rotation
    SAD   Scan angle degrees
    SAD2  Scan angle degrees doubled
*/
REV = 8000;          // Counts for 360 degrees of scanner rotation
SAD = 360.0 / REV;   // Scan Angle Degrees
SAD2 = 720.0 / REV;

local CHANNEL_COUNT;
/* DOCUMENT CHANNEL_COUNT
  EAARL system constant. CHANNEL_COUNT specifies how many active channels there
  are and is 4 for EAARL-B.
*/
CHANNEL_COUNT = 4;
