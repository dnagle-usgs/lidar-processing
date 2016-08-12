import pyorick
import code
import sys

yo = pyorick.Yorick(ypath=sys.argv[1])
yo.c.require('ytk.i')
yo.c.initialize_ytk(sys.argv[2], sys.argv[3])
code.interact(local=locals())
