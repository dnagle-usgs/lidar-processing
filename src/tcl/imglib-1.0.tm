# vim: set ts=4 sts=4 sw=4 ai sr et:

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

# Icons for locking/unlocking
namespace eval ::imglib::padlock {}

# A padlock in the open state (unlocked)
image create bitmap ::imglib::padlock::open -data {
    #define open_width 11
    #define open_height 11
    static unsigned char open_bits[] = {
        0x00, 0x00, 0x80, 0x03, 0x40, 0x04, 0x40, 0x04, 0xfe, 0x04, 0xfe, 0x00,
        0xfe, 0x00, 0xee, 0x00, 0xee, 0x00, 0xfe, 0x00, 0x00, 0x00};
}

# A padlock in the closed state (locked)
image create bitmap ::imglib::padlock::closed -data {
    #define closed_width 11
    #define closed_height 11
    static unsigned char closed_bits[] = {
        0x00, 0x00, 0x70, 0x00, 0x88, 0x00, 0x88, 0x00, 0xfc, 0x01, 0xfc, 0x01,
        0xfc, 0x01, 0xdc, 0x01, 0xdc, 0x01, 0xfc, 0x01, 0x00, 0x00};
}

# Image used in styling panedwindows
image create bitmap ::imglib::sash -data {
    #define sash_width 2
    #define sash_height 2
    static unsigned char sash_bits[] = {
        0xfd, 0xfc};
}

# Plus symbol
image create bitmap ::imglib::plus -data {
    #define plus_width 15
    #define plus_height 15
    static unsigned char plus_bits[] = {
        0x00, 0x00, 0xc0, 0x01, 0xc0, 0x01, 0xc0, 0x01, 0xc0, 0x01, 0xc0, 0x01,
        0xfe, 0x3f, 0xfe, 0x3f, 0xfe, 0x3f, 0xc0, 0x01, 0xc0, 0x01, 0xc0, 0x01,
        0xc0, 0x01, 0xc0, 0x01, 0x00, 0x00};
}

image create bitmap ::imglib::x -data {
    #define x_width 15
    #define x_height 15
    static unsigned char x_bits[] = {
        0x00, 0x00, 0x08, 0x08, 0x1c, 0x1c, 0x3e, 0x3e, 0x7c, 0x1f, 0xf8, 0x0f,
        0xf0, 0x07, 0xe0, 0x03, 0xf0, 0x07, 0xf8, 0x0f, 0x7c, 0x1f, 0x3e, 0x3e,
        0x1c, 0x1c, 0x08, 0x08, 0x00, 0x00};
}

# Symbol with "x2" on it
# 15x15 pixels
image create photo ::imglib::x2 -format png -data {
    iVBORw0KGgoAAAANSUhEUgAAAA8AAAAPCAQAAACR313BAAAAqUlEQVR4Aa3BsYrBcQAA4M8v
    w909wnW6q1uu7obr7gE8gAegZLdYTLwFgzLIxiCLgSxeQUnZLQpRDEr9i8WgjHyfh3tX1deU
    5FbC1lhZTyRNwgvgC1SsxEHXjJGRZxQcvSEtAyjb8GFuqCCSAwBMDODT2kkeAMTUHH1DVmSn
    Kw4gpu4gBRmRoh9rbQEEDXtJoKMEfk29ImhZ+gMIAALIO/j3dHlj4XT1LmdqCy7zJio7fAAA
    AABJRU5ErkJggg==
}

# Icons for arrows
namespace eval ::imglib::arrow {}

# Up arrow
image create bitmap ::imglib::arrow::up -data {
    #define arrow_up_width 15
    #define arrow_up_height 15
    static unsigned char arrow_up_bits[] = {
       0x80, 0x00, 0xc0, 0x01, 0xe0, 0x03, 0xf0, 0x07, 0xf8, 0x0f, 0xfc, 0x1f,
       0xc0, 0x01, 0xc0, 0x01, 0xc0, 0x01, 0xc0, 0x01, 0xc0, 0x01, 0xc0, 0x01,
       0xc0, 0x01, 0xc0, 0x01, 0xc0, 0x01};
}

# Down arrow
image create bitmap ::imglib::arrow::down -data {
    #define arrow_down_width 15
    #define arrow_down_height 15
    static unsigned char arrow_down_bits[] = {
        0xc0, 0x01, 0xc0, 0x01, 0xc0, 0x01, 0xc0, 0x01, 0xc0, 0x01, 0xc0, 0x01,
        0xc0, 0x01, 0xc0, 0x01, 0xc0, 0x01, 0xfc, 0x1f, 0xf8, 0x0f, 0xf0, 0x07,
        0xe0, 0x03, 0xc0, 0x01, 0x80, 0x00};
}

# Miscellaneous icons
namespace eval ::imglib::misc {}

# Depicts a red square on a blue line, as would be seen in Yorick when
# plotting the point.
# 16x16 pixels
image create photo ::imglib::misc::plot -format gif -data {
    R0lGODdhEAAQAJEAAAAA/+fn5/8AAP///ywAAAAAEAAQAAACIUSOqWHr196KMtF6hN5C9vQ5
    YeYpo4k+3IZZrftCsTwDBQA7
}

# Depicts an excerpt/thumbnail of a plotted lidar raster.
# 16x16 pixels
image create photo ::imglib::misc::raster -format png -data {
    iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAIAAACQkWg2AAACW0lEQVR4AQBTAaz+ATFaei4h
    Dc7d/wcD/SUfB+v17RcKEP8E//T5Cr7K5TgoGQoOBQEC7RADGfDy9TktIwQ0IjOag1KrwbAQ
    AxZCNiP//gSDsZUWEQ7I2u1mMx02HSDg1f4vLinR49kC9ylIPg8DHkETGBIDxN3PwNnnj7up
    9vHFu9oCtsn2AAP+VC0hfJjEICL8OSAM7fn7jqbGpszeAsnPEVWCwdzOIODSA+DLD8vj+zQR
    Evr3+ykN+GSD1uPSBC0UHMLk0ejz8urmAPLVAgIB//3x2f8pI/PHvLJYNjTU2g2csfH87Aap
    rgr/7f4B9Ofj6/TN3/sDBQOCZjL8/P4DBRc+AfsD7Aju79fs3fz9DAMK69/7/fL8//f3+uzL
    /vv18QkDOyAZ6vvfwdDz6d8BAvz0/AME/+LSBwID/vXqBAoJ+wQH+/0ABPrszwD8+v8BANzc
    Bpi64Bf8OQT0JcDdSpRhGIXhez3TiFlB0k4Y7XXIHUvn0FYFBCpuKYgiqjg6P9/3PmsJzHUs
    XGNupb0lNoPTc309WQN2GwLTSs+XH37++v3n/53SRUSPBILN8pNv7z5G1SJhL7M31++9cdx1
    /H0Cxd3g7i8/drvVwXz/Tx4pIUGUZMYOqB6vDxmODajycHEkO+nx8Bc7Y4tNIBZxu9zeogqA
    YXmwq6MooEV6m96lHQ/c7biqFocVmMZrUGBav3MqYk8QO23sAKF608B4OqOWgdUN304mIUAh
    oqmO4gSGXUESqEoA9IDPfr2iNxGZX3p9aegALKSS2HMiSEkeSbOXEFskKLDQGylajHX5lVmt
    AAAAAElFTkSuQmCC
}

# Depicts two arrows, one pointing to the upper right and one to the lower left
image create bitmap ::imglib::misc::limits -data {
    #define limits_width 14
    #define limits_height 14
    static unsigned char limits_bits[] = {
        0x00, 0x3e, 0x00, 0x38, 0x00, 0x3c, 0x00, 0x2e, 0x00, 0x27, 0x00, 0x02,
        0x00, 0x00, 0x00, 0x00, 0x10, 0x00, 0x39, 0x00, 0x1d, 0x00, 0x0f, 0x00,
        0x07, 0x00, 0x1f, 0x00};
}

# Like Limits, but adds the impression of a window behind the arrows
image create bitmap ::imglib::resize -data {
    #define resize_width 14
    #define resize_height 14
    static unsigned char resize_bits[] = {
        0x00, 0x3e, 0x3e, 0x38, 0x02, 0x3c, 0x02, 0x2e, 0x02, 0x27, 0x02, 0x02,
        0x00, 0x00, 0x00, 0x00, 0x10, 0x10, 0x39, 0x10, 0x1d, 0x10, 0x0f, 0x10,
        0x07, 0x1f, 0x1f, 0x00};
}

# Depicts two arrows, curved to form a circle
# Icon by Timothy Miller, "Pictype Free Vector Icons"
# Licensed under CC Attribution-Share Alike 3.0 Unported
# www.iconfinder.com/icondetails/126579/128/refresh_reload_sync_icon
# 16x16 pixels
image create photo ::imglib::misc::refresh -format png -data {
    iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAQAAAC1+jfqAAAAwUlEQVR4AZ3RIapCARAF0JMe
    2M0mmwuw2V2GIHaTyWYwGQSbIIK4AUFcgskk4gsGm0G7ijC/TREM/0y9MDNcqa5n5ephb6ym
    5Wgo9X2EHB8v4QQUlkK4mOnomrsLIZyBkRCmKoCmZwbQ8BYmkm0uOsBaKBWSto2dnY023ISB
    HxZKVf9SVVr4YSDcvo5KhVJYwyHf2pImwlsDzkIIT01AxVQII5CBu7mujpmLEJYK4CS8vsrq
    S0NHLTVjew9XKz11gD9DtmsZeJUtKwAAAABJRU5ErkJggg==
}

# Following two images are derived from:
# Icon by WPZOOM, "WPZOOM Developer Icon Set"
# Licensed under CC Attribution-Share Alike 3.0 Unported
# www.iconfinder.com/icondetails/111069/128/finger_point_up_icon

# Single hand pointing up
# 14x15 pixels
image create photo ::imglib::handup -format png -data {
    iVBORw0KGgoAAAANSUhEUgAAAA4AAAAPCAQAAAB+HTb/AAAAxElEQVR4AWOAAc1a87taExmw
    A+ub//+7PWBgwSrpeuf//5BHDBz4JAUZmHBIhj4xf6B+jcNTKoeBC0Ny289P/9f+cXu99LfE
    HsVpDKLIkmDw9/93IDnv3/H/mhvAvmBgRkgigM05BvUdua/M7igtTnuBLul6i0H79h8g48r/
    3//RgfsdBglfj2ev/2MD1ueAVrKpaV7c9ANTUvcAxKnMyisP/UKV2vNbrgTmE1bN8y9RJD3u
    IAeEgtpDr0cw6PlIdR4DAwD2BtFORhBUsAAAAABJRU5ErkJggg==
}

# Two hands pointing up
# 15x15 pixels
image create photo ::imglib::handup2 -format png -data {
    iVBORw0KGgoAAAANSUhEUgAAAA8AAAAPCAQAAACR313BAAABBUlEQVR4AWNAAdyqF1QvM3Az
    4AD20z/P+cHgikvaYfa3pb8YPDDE+XTV9siFQKSlH6mckqrmR1akse35f6OrIOln/x7/m/1p
    7k+Hl4oXOfWh0toH//93uAaS/g8Fz/9/+K99GSqtden/f9OfKq9afp/7/+8/DNjdYYJZzsAQ
    x3ZKdB7LCoYIhvVQQUaYrPYhiPqvQLzsf+H/rWCeyQUG5XT1QxIxKmf/I4FL/1uB5LP/musY
    NB9++T//++LPyNIv/hcAyYyXDJoMyhlhzz78RwUn/qs+1TmtuhBsL6uW1pkjP5Glp31lcEIO
    NFa1sw+QpE1vMjCjhqqE6j2vRxDo8FShBiYMAGEhyooLrIGcAAAAAElFTkSuQmCC
}

# Depicts an X in a circle
# Icon by Victor Erixon http://victorerixon.com
# License is "Free for commercial use"
# www.iconfinder.com/icondetails/106227/128/close_icon
# 15x15 pixels
image create photo ::imglib::xincircle -format png -data {
    iVBORw0KGgoAAAANSUhEUgAAAA8AAAAPCAQAAACR313BAAAAhElEQVR4AYXRqw2FQABE0SMR
    GAwJLUFzWCR228Cu3xpegkMg5xn8qqsm8wNgc6ge1WEDAGZFRNwfixlg9hPNasJk1cTPDBRx
    GgAwOEWBTTSD0W7k46CJjUOs2MVlcYkdqzioYsLoEq+4jJhE5XEDFq94LYDb01F3vDvJO707
    q3U27zz2B+1AYzRTLDEHAAAAAElFTkSuQmCC
}

# Depicts a camera
# Icon by Designmodo http://designmodo.com
# Licensed under CC Attribution-Share Alike 3.0 Unported
# www.iconfinder.com/icondetails/103171/128/camera_image_picture_pictures_icon
# 15x15 pixels
image create photo ::imglib::camera -format png -data {
    iVBORw0KGgoAAAANSUhEUgAAAA8AAAAPCAQAAACR313BAAAAqElEQVR4AX2JsQnCYBQGj4QI
    tlbZQQfIBEI6BUFLBxCyQiprY+0CzmARzAIqEdIFxDbgACmer/h5EKN+xwcHh81nxhqFBQG9
    nRDjio9bwJKUHdLhQMqKAdyQn9xBjIaMjb5BDJMLIUOm+lC9l8fEvBB9rP6RayB3ngN1N5dA
    5bwCym5uGZE4T9Rby44jHhFbvaculo2CORN9gRg8TPs8PSIyzl/ZE/F/b0pal5I9AYRrAAAA
    AElFTkSuQmCC
}

# Depicts a painter's palette
# Icon by Webalys http://www.webalys.com
# Licensed under CC Attribution-Share Alike 3.0 Unported
# www.iconfinder.com/icondetails/95100/45/paint_icon
# 15x14 pixels
image create photo ::imglib::palette -format png -data {
    iVBORw0KGgoAAAANSUhEUgAAAA8AAAAOCAYAAADwikbvAAABLklEQVR4AY3SMUvDYBCA4Yso
    SAcHlQ4xcXJwcnIv0kVQ/A0iDoKDi7sgDqK4dhMdLCIFBydBEFHoUgS1Kh0qWBz0B4hEKDlf
    5ALlyNAPnruE3vWOfpUoCr0BlFBBHa9oRHFYJS+jIHZ84ySuKNQonlCe87xhxjdPoQM1B1hD
    gi4eej7/RFGYIBjhpeUmjCLAI3Zj6kBd+ALFTjZ1HylqqENxiypSLELMKRRNpoZFHr7RRIAx
    qHOPMlbwA8WvENahSLCKPWg/xFbVPm2gAUVXCE9Qc40TJFH8/95BGQv4wiHeoWhLzw/0gWEI
    tqx5kyxm221xJIRZXGAeYpagOMcgVzREvswa7YtL2T1701aYooW2m3qGQAh5AtxAc9TYpOD/
    nt44jvGMO7apkOcQiJ0/C1K7WN4TbcMAAAAASUVORK5CYII=
}

# Depicts two chevron-like symbols pointing right: >>
# 15x15 pixels
image create photo ::imglib::doubleright -format png -data {
    iVBORw0KGgoAAAANSUhEUgAAAA8AAAAPCAQAAACR313BAAAAhklEQVR4AWNgWMCwmUGIAQL0
    GS4ypDCggHMM/xnOMgiC2S5A9j+GLGRpeYb7QMFzUBMKGP4DYTayAjmGexgKclAV3MVQkIus
    QBaLgnxkBTIMd8AK+HCZYAEWCoPyNgDZzzB18yI7EK/deF1O2N+EQ+00kqQNZpjPZdjBIAhl
    azNcZkhDlgQANdtOXjawt8oAAAAASUVORK5CYII=
}

# Depicts two chevron-like symbols pointing left: <<
# 15x15 pixels
image create photo ::imglib::doubleleft -format png -data {
    iVBORw0KGgoAAAANSUhEUgAAAA8AAAAPCAQAAACR313BAAAAhklEQVR4AWNAASkMFxn0oWwh
    hs0MC5Alsxj+MfxncAGzBRnOAtnnEJLZDP+BsACq8xyQfZ9BHiaZgyF5j0EOJpmLIXkXIZmP
    RVIWm04+sOQdBhmEk54BBTZA2WFgpRYQDqajeJF1E7absMsJ+5twqCHC3AZJwWnUGEtjuMyg
    DWULMuxgmAsA6nhOXmCcfJkAAAAASUVORK5CYII=
}
