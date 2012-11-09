// vim: set ts=2 sts=2 sw=2 ai sr et:

func geotiff_tags_encode(gtif) {
/* DOCUMENT geotiff_tags_encode(gtif)

  Given an oxy group object (or Yeti hash) that has key-value mappings for
  GeoTIFF coordinate system tags, this will convert the named tags into
  numerical data as encoded by the GeoTIFF specification.

  For example:

    > tags = save(GTModelTypeGeoKey="ModelTypeProjected", \
    cont> ProjectedCSTypeGeoKey="PCS_NAD83_UTM_zone_16N")
    > encoded = geotiff_tags_encode(tags)
    > info, encoded
     object with 4 members:
      KeyId = array(short,2)
      TIFFTagLocation = array(short,2)
      Count = array(short,2)
      Value_Offset = array(short,2)
    > encoded.KeyId
    [1024,3072]
    > encoded.TIFFTagLocation
    [0,0]
    > encoded.Count
    [1,1]
    > encoded.Value_Offset
    [1,26916]

  The result will have, at a minimum, four members: KeyId, TIFFTagLocation,
  Count, and Value_Offset. Depending on the input given, it may also have up
  to two additional members: GeoDoubleParamsTag and GeoAsciiParamsTag.

  SEE ALSO: geotiff_tags_decode
*/
  if(is_hash(gtif))
    gtif = hash2obj(gtif);

  result = save();
  count = gtif(*);
  for(i = 1; i <= count; i++) {
    key = gtif(*,i);
    if(!GTIF.key(*,key))
      error, "unknown key: "+key;
    keyid = GTIF.key(noop(key));
    keytype = GTIF.keytype(noop(key));
    if(keytype == "short") {
      if(!GTIF.code(*,gtif(noop(i))))
        error, "unknown code: "+gtif(noop(i));
      val = GTIF.code(gtif(noop(i)));
      save, result,
        KeyId = grow(result.KeyId, keyid),
        TIFFTagLocation=grow(result.TIFFTagLocation, 0s),
        Count=grow(result.Count, 1s),
        Value_Offset=grow(result.Value_Offset, val);
    } else if(keytype == "double") {
      val = double(gtif(noop(i)));
      save, result,
        KeyId = grow(result.KeyId, keyid),
        TIFFTagLocation=grow(result.TIFFTagLocation, GTIF.tag.GeoDoubleParamsTag),
        Count=grow(result.Count, short(numberof(val))),
        Value_Offset=grow(result.Value_Offset,
          short(numberof(result.GeoDoubleParamsTag))),
        GeoDoubleParamsTag=grow(result.GeoDoubleParamsTag, val);
    } else if(keytype == "ascii") {
      val = gtif(noop(i));
      if(is_string(val))
        val = strchar(val);
      save, result,
        KeyId = grow(result.KeyId, keyid),
        TIFFTagLocation=grow(result.TIFFTagLocation, GTIF.tag.GeoAsciiParamsTag),
        Count=grow(result.Count, short(numberof(val))),
        Value_Offset=grow(result.Value_Offset,
          short(numberof(result.GeoAsciiParamsTag))),
        GeoAsciiParamsTag=grow(result.GeoAsciiParamsTag, val);
    }
  }
  return result;
}

func geotiff_tags_decode(gtif, &err) {
/* DOCUMENT geotiff_tags_decode(gtif, &err)
  Performs the inverse operation as geotiff_tags_encode. That is, if given an
  oxy group or Yeti hash that could have been returned by geotiff_tags_encode,
  this will construct an oxy group that would have generated that result. It
  will have keys that are key names from the GeoTIFF spec, and the values will
  be doubles, strings, or symbolic strings from the GeoTIFF spec.

  If invalid data is encountered, such data is skipped and err will be an
  array of strings containing error notices. Otherwise, err is [].

  SEE ALSO: geotiff_tags_encode
*/
  if(is_hash(gtif))
    gtif = hash2obj(gtif);
  err = [];

  result = save();
  count = numberof(gtif.KeyId);
  for(i = 1; i <= count; i++) {
    keyid = gtif.KeyId(i);
    idx = binary_search(GTIF.key, keyid, exact=1);
    if(is_void(idx)) {
      grow, err, swrite(format="KeyID=%d is not recognized", keyid);
      continue;
    }
    key = GTIF.key(*,idx);
    keytype = GTIF.keytype(noop(key));

    if(keytype == "ascii") {
      if(gtif.TIFFTagLocation(i) != GTIF.tag.GeoAsciiParamsTag) {
        grow, err, swrite(
          format="%s: TIFFTagLocation is %d but should be %d",
          key, u_cast(gtif.TIFFTagLocation(i), long),
          u_cast(GTIF.tag.GeoAsciiParamsTag, long));
        continue;
      }
      start = gtif.Value_Offset(i) + 1;
      stop = start + gtif.Count(i) - 1;
      str = gtif.GeoAsciiParamsTag(start:stop);
      if(str(0) == '|')
        str(0) = 0x00;
      val = strchar(str);
    } else if(keytype == "double") {
      if(gtif.TIFFTagLocation(i) != GTIF.tag.GeoDoubleParamsTag) {
        grow, err, swrite(
          format="%s: TIFFTagLocation is %d but should be %d",
          key, u_cast(gtif.TIFFTagLocation(i), long),
          u_cast(GTIF.tag.GeoDoubleParamsTag, long));
        continue;
      }
      start = gtif.Value_Offset(i) + 1;
      stop = start + gtif.Count(i) - 1;
      val = gtif.GeoDoubleParamsTag(start:stop);
    } else if(keytype == "short") {
      if(gtif.TIFFTagLocation(i) != 0s) {
        grow, err, swrite(
          format="%s: TIFFTagLocation is %d but should be 0",
          key, u_cast(gtif.TIFFTagLocation(i), long));
        continue;
      }
      // valid is "val id" aka value id
      valid = gtif.Value_Offset(i);
      w = where(strglob(GTIF.keymap(noop(key)), GTIF.code(*,)));
      if(!numberof(w)) {
        grow, err, swrite(
          format="%s: Unable to look up code %d (no codes defined)",
          key, u_cast(valid, long));
        continue;
      }
      idx = binary_search(GTIF.code(noop(w)), valid, exact=1);
      if(is_void(idx)) {
        grow, err, swrite(
          format="%s: Unable to look up code %d",
          key, u_cast(valid, long));
        continue;
      }
      val = GTIF.code(*,w(idx));
    } else {
      grow, err, swrite(format="%s: Invalid", key);
      continue;
    }

    save, result, noop(key), noop(val);
  }

  return result;
}
