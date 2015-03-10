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
  are. This varies based on which EAARL version is active. If 0, it means the
  EAARL code isn't fully loaded.
*/
if(is_void(CHANNEL_COUNT)) CHANNEL_COUNT = 0;
