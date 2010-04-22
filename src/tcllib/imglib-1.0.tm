# vim: set tabstop=3 softtabstop=3 shiftwidth=3 shiftround autoindent:

package provide imglib 1.0
package require Img

namespace eval ::imglib {}

# Icons used for expanding/collapsing things
namespace eval ::imglib::collapsible {}

# Square box with a plus sign inside
image create bitmap ::imglib::collapsible::expand -data {
   #define expand_width 11
   #define expand_height 11
   static unsigned char expand_bits[] = {
      0xff, 0x07, 0x01, 0x04, 0x01, 0x04, 0x21, 0x04, 0x21, 0x04, 0xf9, 0x04,
      0x21, 0x04, 0x21, 0x04, 0x01, 0x04, 0x01, 0x04, 0xff, 0x07};
}

# Square box with a minus side inside
image create bitmap ::imglib::collapsible::collapse -data {
   #define collapse_width 11
   #define collapse_height 11
   static unsigned char collapse_bits[] = {
      0xff, 0x07, 0x01, 0x04, 0x01, 0x04, 0x01, 0x04, 0x01, 0x04, 0xf9, 0x04,
      0x01, 0x04, 0x01, 0x04, 0x01, 0x04, 0x01, 0x04, 0xff, 0x07};
}

# Icons used for VCR-like controls
namespace eval ::imglib::vcr {}

# Solid triangle pointing right, similar to: >
image create bitmap ::imglib::vcr::playfwd -data {
   #define right-arrow_width 16
   #define right-arrow_height 16
   static unsigned char right-arrow_bits[] = {
      0x00, 0x00, 0x20, 0x00, 0x60, 0x00, 0xe0, 0x00, 0xe0, 0x01, 0xe0, 0x03,
      0xe0, 0x07, 0xe0, 0x0f, 0xe0, 0x07, 0xe0, 0x03, 0xe0, 0x01, 0xe0, 0x00,
      0x60, 0x00, 0x20, 0x00, 0x00, 0x00, 0x00, 0x00};
}

# Solid triangle pointing left, similar to: <
image create bitmap ::imglib::vcr::playbwd -data {
   #define left-arrow_width 16
   #define left-arrow_height 16
   static unsigned char left-arrow_bits[] = {
      0x00, 0x00, 0x00, 0x04, 0x00, 0x06, 0x00, 0x07, 0x80, 0x07, 0xc0, 0x07,
      0xe0, 0x07, 0xf0, 0x07, 0xe0, 0x07, 0xc0, 0x07, 0x80, 0x07, 0x00, 0x07,
      0x00, 0x06, 0x00, 0x04, 0x00, 0x00, 0x00, 0x00};
}

# Solid triangle pointing right, with a solid vertical line to its left.
# Similar to: |>
image create bitmap ::imglib::vcr::stepfwd -data {
   #define right-arrow-single_width 16
   #define right-arrow-single_height 16
   static unsigned char right-arrow-single_bits[] = {
      0x00, 0x00, 0xb0, 0x00, 0xb0, 0x01, 0xb0, 0x03, 0xb0, 0x07, 0xb0, 0x0f,
      0xb0, 0x1f, 0xb0, 0x3f, 0xb0, 0x1f, 0xb0, 0x0f, 0xb0, 0x07, 0xb0, 0x03,
      0xb0, 0x01, 0xb0, 0x00, 0x00, 0x00, 0x00, 0x00};
}

# Solid triangle pointing left, with a solid vertical line to its right.
# Similar to: <|
image create bitmap ::imglib::vcr::stepbwd -data {
   #define left-arrow-single_width 16
   #define left-arrow-single_height 16
   static unsigned char left-arrow-single_bits[] = {
      0x00, 0x00, 0x00, 0x0d, 0x80, 0x0d, 0xc0, 0x0d, 0xe0, 0x0d, 0xf0, 0x0d,
      0xf8, 0x0d, 0xfc, 0x0d, 0xf8, 0x0d, 0xf0, 0x0d, 0xe0, 0x0d, 0xc0, 0x0d,
      0x80, 0x0d, 0x00, 0x0d, 0x00, 0x00, 0x00, 0x00};
}

# Solid square.
image create bitmap ::imglib::vcr::stop -data {
   #define stop_width 16
   #define stop_height 16
   static unsigned char stop_bits[] = {
      0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xf0, 0x0f, 0xf0, 0x0f,
      0xf0, 0x0f, 0xf0, 0x0f, 0xf0, 0x0f, 0xf0, 0x0f, 0xf0, 0x0f, 0xf0, 0x0f,
      0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00};
}

# Miscellaneous icons
namespace eval ::imglib::misc {}

# Depicts a red square on a blue line, as would be seen in Yorick when
# plotting the point.
image create photo ::imglib::misc::plot -format gif -data {
   R0lGODdhEAAQAJEAAAAA/+fn5/8AAP///ywAAAAAEAAQAAACIUSOqWHr196KMtF6hN5C9vQ5
   YeYpo4k+3IZZrftCsTwDBQA7
}

# Depicts an excerpt/thumbnail of a plotted lidar raster.
image create photo ::imglib::misc::raster -format png -data {
   iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAIAAAHnlligAAAABGdBTUEAAYagMeiWXwAAAttJ
   REFUKJEFwd1vU2UYAPDned9z2o3OjhHsVtgcMBUxcdCJvSCDkEUTL1AIFyByoTde+AcYzDRR
   g1Gj0RujF0KiidFERaMmBhdNJlE3HGNhDMQxwXZd6T66taynpz3nPB/+fph5drinO2XXJXtj
   bARPDL/ri29zlcx8XnDLU6eOD/R/+uvfh0+ilXv2TVwtelc+/C+3Bx955q3+7bhUiSdcMEcO
   tJ+f9MZGLg8ObLbTi4+iNpsrc+PXHCdsVI1p03A9IsYjr7340IPpC7O5VjdFjItzja9fPnj4
   9d8wmXnJSbSQHxiHmvlLYtyu/f33J3sMMUS1iAOK/Fhz5S/hYH2uZXKiZJikWb5CAFv7EiCh
   BKtBGEWi+Nwrb1/P0cbNXirZ/uPvlaHsfR1ubFdvl3n+2J4HBuKHBuvjy7XP3sjs2hns2+98
   PHnRfvlH9/ToaMntrRSc784tP/5Y2ov5v5zzzIa4bUU3QY63IEFx9P3P/zWrnTYCgxQoy62S
   KhpWCGv43tmrwKEDpAyAYMPyFICCsIYgrE4DUAGVGACUmxKRURE0BhGMdWtF0voCAIT+ArGq
   Kr7w6refnD76zYXvN9rUULZPxTn9w0epjuTFm2up1L3Znm2567K7v226MGsaO5480I7pp4cj
   Vw5ue7hYXsktLww94W+N9X0xsXxoN391PhEsNc+8uXctNlvxku98kI+bhI2lBoOShfTizE9/
   tnZ2+tWOkZ+9aFGvTVFQmND6UkF5e3tnWfLGtpVugcVk1nWxeifOXl64uxZCeku1WtkQLo2r
   shq36vWOTTfmSlz8B5HYdHRHwCzMrEARd2Ua87c3hWszoiSIgAigELKfb6U6q4hZLcSapMgC
   AGq0Nm9tC4MwVWY08iW4qxEpE3AkIqRgQFUB/PKUmpgArN520mkCRABABUAgASJVYgEgFgOI
   iABoABQBVBmljb0ccEMRNKxxPUcIJIAK1jH/A/0NrpQYv8ZmAAAAAElFTkSuQmCC
}
