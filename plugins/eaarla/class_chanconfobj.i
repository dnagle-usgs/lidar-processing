// vim: set ts=2 sts=2 sw=2 ai sr et:

scratch = save(scratch);

func chanconfobj(base, data) {
/* DOCUMENT chanconf = chanconfobj()
  -or- chanconf = chanconfobj(save(...))
  -or- chanconf = chanconfobj("/path/to/file")

  Creates and returns a generic channel-based configuration object. This is
  intended to serve as the base class for EAARL configuration objections that
  configure things on the basis of channel. This is a specialized subclass that
  is built on the confobj clas.

  Please see help, confobj for basic information on the confobj framework.
  Follows are details on how the base class has been specialized.

  The primary difference from the base class is that chanconfobj permits
  multiple groups. Each group has a "channels" value that specifies which
  channels it should be used for.

  Added methods:

    group = chanconf(settings_group, <channel>)
      Given a CHANNEL, returns the name of the GROUP used for that channel.

    chanconf, prompt_groups, "<ns>", "<yobj>", <win>
      Used by GUI for updating group/channel mapping.

  Modified methods:

    conf = chanconf(settings, <channel>)
      Given a CHANNEL, this will return the active profile settings for that
      channel.

    chanconf, groups, <groups>, copy=<0|1>
      In addition to the behavior of the base class, this expects that each
      group will have a member named "channels" that stores an array of channel
      numbers. Each channel should be assigned to exactly one group. If any
      channels are missing, they are assigned to the first group. If any
      channels appear multiple times, an error occurs.

    chanconf, clear
      Modified to account for the requirement of channels in the empty
      initialized configuration.

  Internal modified methods:

    <dumped> = chanconf(dumpgroups, compact=<0|1>)
      Extends base class to add chanconfver to output when compact=0.

    chanconf(cleangroups,)
      Ensures that required fields are present and sanitizes channel
      information.

  SEE ALSO: confobj
*/
  conf = obj_copy(base);
  save, conf, data=save(null=save()), mapping=[];
  if(is_void(data)) {
    conf, clear;
  } else if(is_obj(data)) {
    conf, groups, data, copy=0;
  } else if(is_string(data)) {
    conf, read, data;
  } else {
    error, "invalid input";
  }
  return conf;
}

save, scratch, base;
base = obj_copy(confobj.data, recurse=1);

save, scratch, chanconfobj_settings;
func chanconfobj_settings(channel) {
  use, data;
  use, mapping;
  return data(mapping(channel)).active;
}
save, base, confobj_settings=base.settings;
save, base, settings=chanconfobj_settings;

save, scratch, chanconfobj_settings_group;
func chanconfobj_settings_group(channel) {
  use, mapping;
  return mapping(channel);
}
save, base, settings_group=chanconfobj_settings_group;

save, scratch, chanconfobj_groups;
func chanconfobj_groups(newgroups, copy=) {
  default, copy, 1;
  use, data;
  oldgroups = data;

  use, mapping;
  oldmap = mapping;

  // Channel validation
  newmap = array(string, CHANNEL_COUNT);
  for(i = 1; i <= newgroups(*); i++) {
    grp = newgroups(noop(i));
    if(!grp(*,"channels"))
      error, "missing channel information";
    w = where(grp.channels <= CHANNEL_COUNT);
    if(!numberof(w)) continue;
    if(anyof(newmap(grp.channels(w))))
      error, "multiple groups refer to same channel";
    newmap(grp.channels(w)) = newgroups(*,i);
  }

  if(noneof(newmap))
    error, "no channels found";

  if(nallof(newmap)) {
    first = newmap(where(newmap)(1));
    missing = where(!newmap);
    write, format=" WARNING: no groups found for these channels: %s\n",
      pr1(missing);
    write, format="          using this group for missing channels: %s\n",
      first;
    grp = newgroups(noop(first));
    save, grp, channels=set_remove_duplicates(grow(grp.channels, missing));
    newmap(missing) = first;
  }

  if(nallof(newmap))
    error, "not all channels are assigned";

  if(copy)
    use_method, groups_migrate, oldgroups, newgroups, oldmap, newmap;

  keep = unique(newmap);
  keep = keep(sort(keep));

  data = newgroups(newmap(keep));
  mapping = newmap;

  for(i = 1; i <= data(*); i++)
    use_method, validate, data(*,i);
}
save, base, confobj_groups=base.groups;
save, base, groups=chanconfobj_groups;

save, scratch, chanconfobj_clear;
func chanconfobj_clear(void) {
  working = save(
    channels123=save(channels=[1,2,3])
  );
  use_method, groups, working, copy=0;
}
save, base, confobj_clear=base.clear;
save, base, clear=chanconfobj_clear;

save, scratch, chanconfobj_dumpgroups;
func chanconfobj_dumpgroups(compact=) {
  output = use_method(confobj_dumpgroups, compact=compact);
  if(!compact)
    save, output, chanconfver=1;
  return output;
}
save, base, confobj_dumpgroups=base.dumpgroups;
save, base, dumpgroups=chanconfobj_dumpgroups;

save, scratch, chanconfobj_cleangroups;
func chanconfobj_cleangroups(void) {
  groups = use_method(confobj_cleangroups,);
  for(i = 1; i <= groups(*); i++) {
    grp = groups(noop(i));
    idx = grp(*,["channels","active_name","profiles"]);
    if(nallof(idx))
      error, "missing required field";

    w = where(grp.channels <= CHANNEL_COUNT);
    save, grp, channels=set_remove_duplicates(grp.channels(w));

    save, groups, noop(i), grp;
  }
  return groups;
}
save, base, confobj_cleangroups=base.cleangroups;
save, base, cleangroups=chanconfobj_cleangroups;

save, scratch, chanconfobj_prompt_groups;
func chanconfobj_prompt_groups(ns, yobj, win) {
  use, data;

  cmd = swrite(format="::eaarl::chanconf::prompt_groups .yorwin%d.pg", win);
  parts = [];
  for(i = 1; i <= data(*); i++) {
    chans = strjoin(swrite(format="%d", data(noop(i)).channels), " " );
    grow, parts, swrite(format="%s {%s}", data(*,i), chans);
  }
  cmd += " {"+strjoin(parts, " ")+"}";
  cmd += swrite(format=" -ns %s -yobj %s -window %d", ns, yobj, win);
  tkcmd, cmd;
}
save, base, prompt_groups=chanconfobj_prompt_groups;

chanconfobj = closure(chanconfobj, base);

restore, scratch;
