import json

import numpy as np
import pandas as pd
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

def _adder_store(filename, adder_funcs):
    adders = []
    for adder_func in adder_funcs:
        adders.append(adder_func())

    with tables.open_file(filename, mode='w', filters=FILTER) as fh:
        for adder in adders:
            adder(fh)

def _prep_gps():
    gps = _to_desc_array(yo('=struct2obj(pnav)'), EaarlGps)
    gps_file = yo('=file_relative(mission.data.path, pnav_filename)')

    def add(fh):
        table = fh.create_table('/', 'gps', obj=gps)
        table.attrs.filename = gps_file

    return add

def _prep_ins():
    ins = _to_desc_array(yo('=struct2obj(iex_nav)'), EaarlIns,
                         map={'sod': 'somd'})
    ins_file = yo('=file_relative(mission.data.path, ins_filename)')
    ins_head = "\n".join(yo('=iex_head')) + "\n"

    def add(fh):
        table = fh.create_table('/', 'ins', obj=ins)
        table.attrs.filename = ins_file
        table.attrs.headers = ins_head

    return add

def _edb_class(filename_length):
    class EaarlEdb(tables.IsDescription):
        soe = tables.Float32Col(pos=0)
        raster_offset = tables.UInt32Col(pos=1)
        raster_length = tables.UInt32Col(pos=2)
        pulse_count = tables.UInt8Col(pos=3)
        digitizer = tables.UInt8Col(pos=4)
        file = tables.StringCol(pos=5, itemsize=filename_length)
    return EaarlEdb

def _prep_edb():
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

    def add(fh):
        table = fh.create_table('/', 'eaarl', obj=edb)
        table.attrs.filename = edb_file

        table = fh.create_array('/', 'time_offset', obj=time_offset)

    return add

def h5_gps(filename):
    _adder_store(filename, [_prep_gps])

def h5_ins(filename):
    _adder_store(filename, [_prep_ins])

def h5_edb(filename):
    _adder_store(filename, [_prep_edb])

def json_ops_conf(filename):
    ops = yo('=ops_conf')

    for key, val in ops.items():
        try:
            val = val.tolist()
        except AttributeError:
            pass
        ops[key] = val

    if ops['name'] in ['(nil)', '']:
        del ops['name']
    if ops['comment'] in ['(nil)', '']:
        del ops['comment']

    with open(filename, 'w') as fh:
        json.dump(ops, fh, indent=2)

def csv_edb(filename):
    edb_files = np.array(yo('=edb_files'))
    edb = yo('=struct2obj(edb)')
    edb['file'] = edb_files[edb['file_number'] - 1]
    del edb['file_number']
    del edb_files

    edb['pulse_count'] = edb['pixels']
    del edb['pixels']

    time_offset = yo('=eaarl_time_offset')

    edb['soe'] = edb['seconds'] + edb['fseconds'] * 1.6e-6 - time_offset
    del edb['seconds']
    del edb['fseconds']

    filename_length = len(max(edb['file'], key=len))

    columns = ['soe', 'digitizer', 'pulse_count', 'offset', 'raster_length',
               'file']

    raster_number = pd.Index(np.arange(1, len(edb['file'])+1),
                             name="raster_number")
    edb = pd.DataFrame(edb, index=raster_number, columns=columns)
    del raster_number

    edb.to_csv(filename, float_format='%.7f')