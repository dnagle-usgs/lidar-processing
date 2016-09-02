import tables
import pandas as pd

def h5_gps(fn):
    with tables.open_file(fn, "r") as fh:
        data = fh.root.gps.read()
    return pd.DataFrame(data)

def h5_gps_yo(fn):
    data = h5_gps(fn)
    return data.to_dict('list')
