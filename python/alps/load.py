import tables
import pandas as pd

def h5_gps(fn):
    with tables.open_file(fn, "r") as fh:
        data = fh.root.gps.read()
    return pd.DataFrame(data)

def h5_gps_yo(fn):
    data = h5_gps(fn)
    return data.to_dict('list')

def h5_ins(fn):
    with tables.open_file(fn, "r") as fh:
        data = fh.root.ins.read()
    return pd.DataFrame(data)

def h5_ins_yo(fn):
    with tables.open_file(fn, "r") as fh:
        data = fh.root.ins.read()
        head = fh.root.ins.attrs.headers
    data = pd.DataFrame(data).to_dict('list')
    data['iex_head'] = head.split('\n')
    return data

