import sys

import pyorick

yo = pyorick.Yorick(ypath=sys.argv[1])
yo.c.require('ytk.i')
yo.c.initialize_ytk(sys.argv[2], sys.argv[3])
