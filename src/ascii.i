// vim: set ts=2 sts=2 sw=2 ai sr et:
require, "eaarl.i";

func tky_ascii_rdcols_sample(opts, cmd) {
/* tky_ascii_rdcols_sample, opts, cmd
  Intended for use by the ASCII GUI only. The function is explicitly tied to
  the GUI.
*/
  opts = json_decode(opts);
  data = pointers2group(rdcols(opts.fn, opts.ncols, width=opts.width,
    delim=opts.delim, type=opts.type, missing=opts.missing,
    marker=opts.marker, comment=opts.comment, nskip=opts.nskip,
    nlines=opts.nlines));

  if(!is_void(opts.selcols))
    data = data(opts.selcols);

  types = array(string, data(*));
  for(i = 1; i <= data(*); i++)
    types(i) = typeof(data(noop(i)));

  if(opts.group == "array" && opts.type == 0) {
    if(anyof(types == "string") && nallof(types == "string")) {
      h_set, opts, type=1;
    } else if(anyof(types == "double") && nallof(types == "double")) {
      h_set, opts, type=3;
    }
    if(opts.type > 0) {
      tky_ascii_rdcols_sample, json_encode(opts), cmd;
      return;
    }
  }

  tkcmd, swrite(format="%s {%s}", cmd, json_encode(data));
}

func ascii_rdcols(opts) {
/* DOCUMENT ascii_rdcols(opts)
  Intended for use by the ASCII GUI only. Do not use interactively. Use rdcols
  intead.
*/
  opts = json_decode(opts);
  data = rdcols(opts.fn, opts.ncols, width=opts.width,
    delim=opts.delim, type=opts.type, missing=opts.missing,
    marker=opts.marker, comment=opts.comment, nskip=opts.nskip,
    nlines=opts.nlines);

  if(!is_void(opts.selcols))
    data = data(opts.selcols);

  types = array(string, numberof(data));
  for(i = 1; i <= numberof(data); i++)
    types(i) = typeof(data(i));

  if(opts.group == "array" && opts.type == 0) {
    if(anyof(types == "string") && nallof(types == "string")) {
      h_set, opts, type=1;
    } else if(anyof(types == "double") && nallof(types == "double")) {
      h_set, opts, type=3;
    }
    if(opts.type > 0) {
      return ascii_rdcols(json_encode(opts));
    }
  }

  result = [];
  if(opts.group == "array") {
    result = array(structof(*data(1)), numberof(*data(1)), numberof(data));
    for(i = 1; i <= numberof(data); i++) {
      result(,i) = *data(i);
    }
  } else if(opts.group == "pointers") {
    result = data;
  } else if(opts.group == "group") {
    result = pointers2group(data);
  }

  return result;
}
