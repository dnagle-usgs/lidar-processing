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

def _ops_conf():
    ops = yo('=ops_conf')

    for key, val in ops.items():
        if hasattr(val, 'size') and val.size == 1:
            ops[key] = val[()]

    if ops['name'] in ['(nil)', '']:
        del ops['name']
    if ops['comment'] in ['(nil)', '']:
        del ops['comment']

    return ops

def h5_mission(filename):
    gps = _to_desc_array(yo('=struct2obj(pnav)'), EaarlGps)
    ins = _to_desc_array(yo('=struct2obj(iex_nav)'), EaarlIns)

    gps_file = yo('=file_relative(mission.data.path, pnav_filename)')
    ins_file = yo('=file_relative(mission.data.path, ins_filename)')
    ins_head = "\n".join(yo('=iex_head')) + "\n"

    ops = _ops_conf()

    with tables.open_file(filename, mode='w') as fh:
        table = fh.create_table('/', 'gps', obj=gps, filters=FILTER)
        table.attrs.filename = gps_file

        table = fh.create_table('/', 'ins', obj=ins, filters=FILTER)
        table.attrs.filename = ins_file
        table.attrs.headers = ins_head

        fh.create_group('/', 'conf', filters=FILTER)
        for key, val in ops.items():
            fh.set_node_attr('/conf', key, val)
