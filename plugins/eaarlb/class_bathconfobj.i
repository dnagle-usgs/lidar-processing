require, "class_confobj.i";

func bathconfobj(base, data) {
/* DOCUMENT bathconf = bathconfobj()
  -or- bathconf = bathconfobj(save(...))
  -or- bathconf = bathconfobj("/path/to/file.bathy")

  This returns a bathconf object. This is a specialized subclass built on
  confobj that adds bathy-specific configuration elements to the framework.

  Please see help, confobj for basic information on the confobj framework.
  Follows are details on how the base class has been specialized.

  The primary difference from the base class is that bathconfobj permits
  multiple groups. Each group has a "channels" value that specifies which
  channels it should be used for.

  Additionally, bathconfobj has specific knowledge of which keys are expected
  and what format they should be in (integer, double, etc.).

  Added method:

    group = bathconf(settings_group, <channel>)
      Given a CHANNEL, returns the name of the GROUP used for that channel.

  Modified methods:

    conf = bathconf(settings, <channel>)
      Given a CHANNEL, this will return the active profile settings for that
      channel.

    bathconf, groups, <groups>, copy=<0|1>
      In addition to the behavior of the base class, this expects that each
      group will have a member named "channels" that stores an array of channel
      numbers. Each channel should be assigned to exactly one group. If any
      channels are missing, they are assigned to the first group. If any
      channels appear multiple times, an error occurs. Also removes unneeded
      syncs for Tcl.

    bathconf, read, "/path/to/file.bathy"
      Overloaded to handle legacy bathy formats.

    bathconf, clear
      Modified to account for the requirement of channels in the empty
      initialized configuration.

    bathconf, profile_add, "<group>", "<profile>"
    bathconf, profile_del, "<group>", "<profile>"
    bathconf, profile_rename, "<group>", "<old_profile>", "<new_profile>"
      In addition to their normal behavior, these will also keep Tcl updated
      with changes to the profile list.

  Internal modified methods:

    bathconf, validate, "<group>"
      Ensures the presence of all required keys, including conditional
      selection of keys based on "decay" setting. Also enforces proper types on
      them (double or integer). Also applies syncing to Tcl.

    bathconf(cleangroups,)
      Ensures that only the relevant keys are kept. In particular, if you've
      swapped back and forth between "decay" settings on a profile, you'll end
      up with copies of each decay type's specialized settings in that profile.
      This makes sure that only the selected decay type's settings get written
      out to file.

  SEE ALSO: confobj
*/
  obj = obj_copy(base);
  save, obj, data=save(null=save()), mapping=[];
  if(is_void(data)) {
    obj, clear;
  } else if(is_obj(data)) {
    obj, groups, data, copy=0;
  } else if(is_string(data)) {
    obj, read, data;
  } else {
    error, "invalid input";
  }
  return obj;
}

scratch = save(scratch, base);
base = obj_copy(confobj.data, recurse=1);

save, scratch, bathconfobj_settings;
func bathconfobj_settings(channel) {
  use, data;
  use, mapping;
  return data(mapping(channel)).active;
}
save, base, confobj_settings=base.settings;
save, base, settings=bathconfobj_settings;

func bathconfobj_settings_group(channel) {
  use, mapping;
  return mapping(channel);
}
save, base, settings_group=bathconfobj_settings_group;

save, scratch, bathconfobj_groups;
func bathconfobj_groups(newgroups, copy=) {
  default, copy, 1;
  use, data;
  oldgroups = data;

  // Remove syncs
  for(i = 1; i <= oldgroups(*); i++) {
    if(!oldgroups(noop(i))(*,"active")) continue;
    group = oldgroups(*,i);
    drop = oldgroups(noop(i)).active(*,);
    tksync, remove,
      swrite(format="bathconf.data.%s.active.%s", group, drop),
      swrite(format="::eaarl::bathconf::settings(%s,%s)", group, drop);
    tksync, remove,
      swrite(format="bathconf.data.%s.active_name", group),
      swrite(format="::eaarl::bathconf::active_profile(%s)", group);
  }

  use, mapping;
  oldmap = mapping;

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

  for(i = 1; i <= data(*); i++) {
    use_method, validate, data(*,i);
    tksetval, swrite(format="::eaarl::bathconf::profiles(%s)", data(*,i)),
      strjoin("{"+data(noop(i)).profiles(*,)+"}", " ");
  }
}
save, base, confobj_groups=base.groups;
save, base, groups=bathconfobj_groups;

save, scratch, bathconfobj_validate;
func bathconfobj_validate(group) {
  use_method, confobj_validate, group;

  // Only validate fields on active profile.
  use, data;
  active = data(noop(group)).active;

  // Values that all confs have
  defaults = save(
    thresh=1.0, first=1, last=2, sfc_last=12, maxsat=1, smoothwf=0,
    lwing_dist=1, rwing_dist=3, lwing_factor=0.9, rwing_factor=0.9,
    decay="exponential"
  );
  key_default_and_cast, active, defaults;
  tksync, idleadd,
    swrite(format="bathconf.data.%s.active.%s", group, defaults(*,)),
    swrite(format="::eaarl::bathconf::settings(%s,%s)", group, defaults(*,));

  // Values specific to a decay type
  if(active.decay == "exponential") {
    defaults = save(laser=-1.0, water=-1.0, agc=-1.0);
    drop = ["mean", "stdev", "xshift", "xscale", "tiepoint"];
  } else if(active.decay == "lognormal") {
    defaults = save(mean=1.0, stdev=1.0, agc=-1.0, xshift=1.0, xscale=15.0,
      tiepoint=2);
    drop = ["laser", "water"];
  } else {
    error, "Unknown decay type";
  }
  key_default_and_cast, active, defaults;
  tksync, idleadd,
    swrite(format="bathconf.data.%s.active.%s", group, defaults(*,)),
    swrite(format="::eaarl::bathconf::settings(%s,%s)", group, defaults(*,));
  tksync, remove,
    swrite(format="bathconf.data.%s.active.%s", group, drop),
    swrite(format="::eaarl::bathconf::settings(%s,%s)", group, drop);
  tksync, idleadd,
    swrite(format="bathconf.data.%s.active_name", group),
    swrite(format="::eaarl::bathconf::active_profile(%s)", group);
}
save, base, confobj_validate=base.validate;
save, base, validate=bathconfobj_validate;

save, scratch, bathconfobj_prompt_groups;
func bathconfobj_prompt_groups(win) {
  use, data;

  cmd = swrite(format="::eaarl::bathconf::prompt_groups .yorwin%d.pg", win);
  parts = [];
  for(i = 1; i <= data(*); i++) {
    chans = strjoin(swrite(format="%d", data(noop(i)).channels), " " );
    grow, parts, swrite(format="%s {%s}", data(*,i), chans);
  }
  cmd += " {"+strjoin(parts, " ")+"}";
  cmd += swrite(format=" -window %d", win);
  tkcmd, cmd;
}
save, base, prompt_groups=bathconfobj_prompt_groups;

save, scratch, bathconfobj_read;
func bathconfobj_read(fn) {
  f = open(fn, "r");

  // Legacy support for old .bctl files, written for Tcl
  if(file_extension(fn) == ".bctl") {
    lines = rdfile(f);
    key = val = [];
    good = regmatch("set bath_ctl\\((.*)\\) (.*)", lines, , key, val);
    w = where(good);
    prof = save();
    for(i = 1; i <= numberof(w); i++) {
      save, prof, key(w(i)), atod(val(w(i)));
    }
    working = save(
      confver=1,
      groups=save(
        channels123=save(
          channels=[1,2,3],
          profiles=save(default=obj_copy(prof))
        )
      )
    );
  } else {
    working = json_decode(rdfile(f), objects="");
    // Legacy support for .json style files that had a fixed format
    if(anyof(working(*,["bath_ctl","bath_ctl_chn4"]))) {
      working = save(
        confver=1,
        bathver=1,
        groups=save(
          channels123=save(
            channels=[1,2,3],
            profiles=save(
              default=(working(*,"bath_ctl")
                ? working.bath_ctl
                : working.bath_ctl_chn4
              )
            )
          )
        )
      );
    }
  }
  close, f;

  working = use_method(upgrade, working);
  use_method, groups, working.groups, copy=0;

  if(logger(info)) logger, info, "Loaded bathy settings from "+fn;
}
save, base, confobj_read=base.read;
save, base, read=bathconfobj_read;

save, scratch, bathconfobj_clear;
func bathconfobj_clear(void) {
  working = save(
    chn1=save(channels=1),
    chn2=save(channels=2),
    chn3=save(channels=3),
    chn4=save(channels=4)
  );
  use_method, groups, working, copy=0;
}
save, base, confobj_clear=base.clear;
save, base, clear=bathconfobj_clear;

save, scratch, bathconfobj_cleangroups;
func bathconfobj_cleangroups(void) {
  groups = use_method(confobj_cleangroups,);
  for(i = 1; i <= groups(*); i++) {
    grp = groups(noop(i));
    idx = grp(*,["channels","active_name","profiles"]);
    if(nallof(idx))
      error, "missing require field";
    grp = grp(noop(idx));

    w = where(grp.channels <= CHANNEL_COUNT);
    save, grp, channels=set_remove_duplicates(grp.channels(w));

    for(j = 1; j <= grp.profiles(*); j++) {
      prof = grp.profiles(noop(j));
      if(prof.decay == "lognormal") {
        idx = prof(*, ["maxsat", "sfc_last", "smoothwf", "decay", "mean",
          "stdev", "agc", "xshift", "xscale", "tiepoint", "first", "last",
          "thresh", "lwing_dist", "lwing_factor", "rwing_dist",
          "rwing_factor"]);
      } else {
        idx = prof(*, ["maxsat", "sfc_last", "smoothwf", "decay", "laser",
          "water", "agc", "first", "last", "thresh", "lwing_dist",
          "lwing_factor", "rwing_dist", "rwing_factor"]);
      }
      idx = idx(where(idx));
      if(numberof(idx))
        prof = prof(noop(idx));
      save, grp.profiles, noop(j), prof;
    }

    save, groups, noop(i), grp;
  }
  return groups;
}
save, base, confobj_cleangroups=base.cleangroups;
save, base, cleangroups=bathconfobj_cleangroups;

save, scratch, bathconfobj_json;
func bathconfobj_json(json, compact=) {
  if(!is_void(json)) {
    use_method, confobj_json, json, compact=compact;
  }

  if(!am_subroutine()) {
    output = save();
    if(!compact)
      save, output, confver=1, bathver=2;
    save, output, groups=use_method(cleangroups,);
    if(!compact) {
      save, output, "save environment", save(
        "user", get_user(),
        "host", get_host(),
        "timestamp", soe2iso8601(getsoe()),
        "repository", _hgid
      );
    }
    return json_encode(output, indent=(compact ? [] : 2));
  }
}
save, base, confobj_json=base.json;
save, base, json=bathconfobj_json;

save, scratch, bathconfobj_upgrade;
func bathconfobj_upgrade(versions, working) {
  working = use_method(confobj_upgrade, working);

  if(!working(*,"bathver"))
    save, working, bathver=2;
  if(is_string(working.bathver))
    save, working, bathver=atoi(working.bathver);

  for(i = working.bathver; i <= versions(*); i++) {
    working = versions(noop(i), working);
  }

  maxver = versions(*) + 1;
  if(working.bathver > maxver) {
    write, format=" WARNING: bathy format is version %d!\n", working.bathver;
    write, format=" This version of ALPS can only handle up to version %d.\n",
      maxversion;
    write, "Attempting to use anyway, but errors may ensue...";
  }

  return working;
}

scratch = save(scratch, versions);
versions = save();

save, scratch, bathconfobj_upgrade_version1;
func bathconfobj_upgrade_version1(working) {
  for(i = 1; i <= working.groups(*); i++) {
    grp = working.groups(noop(i));
    for(j = 1; j <= grp.profiles(*); j++) {
      prof = grp.profiles(noop(j));
      if(prof.xscale) {
        save, prof, xshift=-1*prof.xshift;
        save, prof, mean=prof.laser;
        save, prof, stdev=prof.water;
        save, prof, decay="lognormal";
      }
    }
  }

  save, working, bathver=2;
  return working;
}
save, versions, bathconfobj_upgrade_version1;

save, base, confobj_upgrade=base.upgrade;
save, base, upgrade=closure(bathconfobj_upgrade, versions);
restore, scratch;

save, scratch, bathconfobj_profile_add;
func bathconfobj_profile_add(group, profile) {
  use, data;
  use_method, confobj_profile_add, group, profile;
  tksetval, swrite(format="::eaarl::bathconf::profiles(%s)", group),
    strjoin("{"+data(noop(group)).profiles(*,)+"}", " ");
}
save, base, confobj_profile_add=base.profile_add;
save, base, profile_add=bathconfobj_profile_add;

save, scratch, bathconfobj_profile_del;
func bathconfobj_profile_del(group, profile) {
  use, data;
  use_method, confobj_profile_del, group, profile;
  tksetval, swrite(format="::eaarl::bathconf::profiles(%s)", group),
    strjoin("{"+data(noop(group)).profiles(*,)+"}", " ");
}
save, base, confobj_profile_del=base.profile_del;
save, base, profile_del=bathconfobj_profile_del;

save, scratch, bathconfobj_profile_rename;
func bathconfobj_profile_rename(group, oldname, newname) {
  use, data;
  use_method, confobj_profile_rename, group, oldname, newname;
  tksetval, swrite(format="::eaarl::bathconf::profiles(%s)", group),
    strjoin("{"+data(noop(group)).profiles(*,)+"}", " ");
}
save, base, confobj_profile_rename=base.profile_rename;
save, base, profile_rename=bathconfobj_profile_rename;

bathconfobj = closure(bathconfobj, base);
restore, scratch;
