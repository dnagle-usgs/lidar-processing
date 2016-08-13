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
    lon = tables.Float32Col(pos=0)
    lat = tables.Float32Col(pos=1)
    alt = tables.Float32Col(pos=2)
    sod = tables.Float32Col(pos=3)
    roll = tables.Float32Col(pos=4)
    pitch = tables.Float32Col(pos=5)
    heading = tables.Float32Col(pos=6)

def _to_desc_array(data, desc, map={}):
    fields = list(desc.columns.keys())
    count = len(data[fields[0]])
    array = np.zeros(count, dtype=tables.description.dtype_from_descr(desc))
    for field in fields:
        if field in map:
            array[field] = data[map[field]]
        else:
            array[field] = data[field]
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
    ins = _to_desc_array(yo('=struct2obj(iex_nav)'), EaarlIns,
                         map={'sod': 'somd'})

    gps_file = yo('=file_relative(mission.data.path, pnav_filename)')
    ins_file = yo('=file_relative(mission.data.path, ins_filename)')
    ins_head = "\n".join(yo('=iex_head')) + "\n"

    ops = _ops_conf()

    with tables.open_file(filename, mode='w', filters=FILTER) as fh:
        table = fh.create_table('/', 'gps', obj=gps)
        table.attrs.filename = gps_file

        table = fh.create_table('/', 'ins', obj=ins)
        table.attrs.filename = ins_file
        table.attrs.headers = ins_head

        fh.create_group('/', 'conf')
        for key, val in ops.items():
            fh.set_node_attr('/conf', key, val)

def _edb_class(filename_length):
    class EaarlEdb(tables.IsDescription):
        soe = tables.Float32Col(pos=0)
        raster_offset = tables.UInt32Col(pos=1)
        raster_length = tables.UInt32Col(pos=2)
        pulse_count = tables.UInt8Col(pos=3)
        digitizer = tables.UInt8Col(pos=4)
        file = tables.StringCol(pos=5, itemsize=filename_length)
    return EaarlEdb

def h5_edb(filename):
    edb_file = yo('=file_relative(mission.data.path, edb_filename)')

    edb_files = np.array(yo('=edb_files'))
    edb = yo('=struct2obj(edb)')
    edb['file'] = edb_files[edb['file_number'] - 1]
    del edb['file_number']
    del edb_files

    time_offset = yo('=eaarl_time_offset')

    edb['soe'] = edb['seconds'] + edb['fseconds'] * 1.6e-6 - time_offset
    del edb['seconds']
    del edb['fseconds']

    filename_length = len(max(edb['file'], key=len))

    edb = _to_desc_array(edb, _edb_class(filename_length),
                        map = {
                            'pulse_count': 'pixels',
                            'raster_offset': 'offset'
                        })

    with tables.open_file(filename, mode='w', filters=FILTER) as fh:
        table = fh.create_table('/', 'eaarl', obj=edb)
        table.attrs.filename = edb_file

        table = fh.create_array('/', 'time_offset', obj=time_offset)
