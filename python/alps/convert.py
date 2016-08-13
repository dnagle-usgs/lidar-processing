import numpy as np
import tables

from .site import yo

FILTER = tables.Filters(complevel=9, complib='blosc:blosclz')

class EaarlGps(tables.IsDescription):
    lon = tables.Float32Col(pos=0)
    lat = tables.Float32Col(pos=1)
    alt = tables.Float32Col(pos=2)
    sod = tables.Float32Col(pos=3)
    pdop = tables.Float32Col(pos=4)
    xrms = tables.Float32Col(pos=5)
    veast = tables.Float32Col(pos=6)
    vnorth = tables.Float32Col(pos=7)
    vup = tables.Float32Col(pos=8)
    sv = tables.Int16Col(pos=9)
    flag = tables.Int16Col(pos=10)

class EaarlIns(tables.IsDescription):
    lon = tables.Float32Col(pos=9)
    lat = tables.Float32Col(pos=1)
    alt = tables.Float32Col(pos=2)
    sod = tables.Float32Col(pos=3)
    roll = tables.Float32Col(pos=4)
    pitch = tables.Float32Col(pos=5)
    heading = tables.Float32Col(pos=6)

def _to_desc_array(data, desc):
    fields = list(desc.columns.keys())
    count = len(data[fields[0]])
    array = np.zeros(count, dtype=tables.description.dtype_from_descr(desc))
    for field in fields:
        try:
            array[field] = data[field]
        except KeyError:
            if field == 'sod':
                array[field] = data['somd']
            else:
                raise
    return array

def h5_mission(filename):
    gps = _to_desc_array(yo('=struct2obj(pnav)'), EaarlGps)
    ins = _to_desc_array(yo('=struct2obj(iex_nav)'), EaarlIns)

    with tables.open_file(filename, mode='w') as fh:
        fh.create_table('/', 'gps', obj=gps, filters=FILTER)
        fh.create_table('/', 'ins', obj=ins, filters=FILTER)
