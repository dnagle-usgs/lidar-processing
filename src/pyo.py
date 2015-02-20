import pyorick
import code
import sys

yo = pyorick.Yorick(ypath='/opt/alps/bin/yorick')
yo.c.require('ytk.i')
yo.c.initialize_ytk(sys.argv[1], sys.argv[2])
code.interact(local=locals())
