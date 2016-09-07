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

def get_gps(gps=None):
    if gps is None:
        gps = yo('=struct2obj(pnav)')
    return _to_desc_array(gps, EaarlGps)

def add_gps(fh, gps):
    fh.create_table('/', 'gps', obj=gps)

def get_ins(ins=None, headers=None):
    if ins is None:
        ins = _to_desc_array(yo('=struct2obj(iex_nav)'), EaarlIns,
                            map={'sod': 'somd'})
        headers = "\n".join(yo('=iex_head')) + "\n"
    ins = _to_desc_array(ins, EaarlIns, map={'sod': 'somd'})
    return (ins, headers)

def add_ins(fh, ins, headers=None):
    table = fh.create_table('/', 'ins', obj=ins)
    if headers is not None:
        table.attrs.headers = headers

def _edb_class(filename_length):
    class EaarlEdb(tables.IsDescription):
        soe = tables.Float32Col(pos=0)
        raster_offset = tables.UInt32Col(pos=1)
        raster_length = tables.UInt32Col(pos=2)
        pulse_count = tables.UInt8Col(pos=3)
        digitizer = tables.UInt8Col(pos=4)
        file = tables.StringCol(pos=5, itemsize=filename_length)
    return EaarlEdb

def h5_gps(filename, gps=None):
    gps = get_gps(gps)
    with tables.open_file(filename, mode='w', filters=FILTER) as fh:
        add_gps(fh, gps)

def h5_ins(filename, ins=None, headers=None):
    ins, headers = get_ins(ins, headers)
    with tables.open_file(filename, mode='w', filters=FILTER) as fh:
        add_ins(fh, ins, headers)

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
