import code
import os.path
import sys

sys.path.append(os.path.dirname(__file__))

import alps.site

yo = alps.site.yo

code.interact(local=locals())
