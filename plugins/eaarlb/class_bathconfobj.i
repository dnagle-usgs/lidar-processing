// vim: set ts=2 sts=2 sw=2 ai sr et:

func bathconfobj(base, data) {
/* DOCUMENT bathconf = bathconfobj()
  -or- bathconf = bathconfobj(save(...))
  -or- bathconf = bathconfobj("/path/to/file.bathconf")

  This returns a bathconf object. This is a specialized subclass built on
  chanconfobj that adds bathy-specific configuration elements to the framework.

  Please see help, chanconfobj for information on the chanconfobj framework, as
  well as help, confobj for more information on the underlying confobj
  framework. Follows are details on how the base class has been specialized.

  The primary difference from the base class is that  bathconfobj has specific
  knowledge of which keys are expected and what format they should be in
  (integer, double, etc.).

  Modified methods:

    bathconf, groups, <groups>, copy=<0|1>
      In addition to the behavior of the base class, this updates Tcl syncs.

    bathconf, read, "/path/to/file.bathconf"
      Overloaded to handle legacy bathy formats.

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

    bathconf(dumpgroups, compact=<0|1>)
      Extends base class to add bathver to output when compact=0.

    bathconf(cleangroups,)
      Ensures that only the relevant keys are kept. In particular, if you've
      swapped back and forth between "decay" settings on a profile, you'll end
      up with copies of each decay type's specialized settings in that profile.
      This makes sure that only the selected decay type's settings get written
      out to file.

  SEE ALSO: confobj, chanconfobj
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
base = obj_copy(chanconfobj.data, recurse=1);

save, scratch, bathconfobj_groups;
func bathconfobj_groups(newgroups, copy=) {
  use, data;

  // Remove syncs
  for(i = 1; i <= data(*); i++) {
    if(!data(noop(i))(*,"active")) continue;
    group = data(*,i);
    drop = data(noop(i)).active(*,);
    tksync, remove,
      swrite(format="bathconf.data.%s.active.%s", group, drop),
      swrite(format="::eaarl::bathconf::settings(%s,%s)", group, drop);
    tksync, remove,
      swrite(format="bathconf.data.%s.active_name", group),
      swrite(format="::eaarl::bathconf::active_profile(%s)", group);
  }

  use_method, chanconfobj_groups, newgroups, copy=copy;

  // Add syncs
  for(i = 1; i <= data(*); i++) {
    tksetval, swrite(format="::eaarl::bathconf::profiles(%s)", data(*,i)),
      strjoin("{"+data(noop(i)).profiles(*,)+"}", " ");
  }
}
save, base, chanconfobj_groups=base.groups;
save, base, groups=bathconfobj_groups;

save, scratch, bathconfobj_validate;
func bathconfobj_validate(group) {
  use_method, chanconfobj_validate, group;

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
save, base, chanconfobj_validate=base.validate;
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
save, base, chanconfobj_read=base.read;
save, base, read=bathconfobj_read;

save, scratch, bathconfobj_cleangroups;
func bathconfobj_cleangroups(void) {
  groups = use_method(chanconfobj_cleangroups,);
  for(i = 1; i <= groups(*); i++) {
    grp = groups(noop(i));

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
save, base, chanconfobj_cleangroups=base.cleangroups;
save, base, cleangroups=bathconfobj_cleangroups;

save, scratch, bathconfobj_dumpgroups;
func bathconfobj_dumpgroups(compact=) {
  output = use_method(chanconfobj_dumpgroups, compact=compact);
  if(!compact)
    save, output, bathver=2;
  return output;
}
save, base, chanconfobj_dumpgroups=base.dumpgroups;
save, base, dumpgroups=bathconfobj_dumpgroups;

save, scratch, bathconfobj_upgrade;
func bathconfobj_upgrade(versions, working) {
  working = use_method(chanconfobj_upgrade, working);

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

save, base, chanconfobj_upgrade=base.upgrade;
save, base, upgrade=closure(bathconfobj_upgrade, versions);
restore, scratch;

save, scratch, bathconfobj_profile_add;
func bathconfobj_profile_add(group, profile) {
  use, data;
  use_method, chanconfobj_profile_add, group, profile;
  tksetval, swrite(format="::eaarl::bathconf::profiles(%s)", group),
    strjoin("{"+data(noop(group)).profiles(*,)+"}", " ");
}
save, base, chanconfobj_profile_add=base.profile_add;
save, base, profile_add=bathconfobj_profile_add;

save, scratch, bathconfobj_profile_del;
func bathconfobj_profile_del(group, profile) {
  use, data;
  use_method, chanconfobj_profile_del, group, profile;
  tksetval, swrite(format="::eaarl::bathconf::profiles(%s)", group),
    strjoin("{"+data(noop(group)).profiles(*,)+"}", " ");
}
save, base, chanconfobj_profile_del=base.profile_del;
save, base, profile_del=bathconfobj_profile_del;

save, scratch, bathconfobj_profile_rename;
func bathconfobj_profile_rename(group, oldname, newname) {
  use, data;
  use_method, chanconfobj_profile_rename, group, oldname, newname;
  tksetval, swrite(format="::eaarl::bathconf::profiles(%s)", group),
    strjoin("{"+data(noop(group)).profiles(*,)+"}", " ");
}
save, base, chanconfobj_profile_rename=base.profile_rename;
save, base, profile_rename=bathconfobj_profile_rename;

bathconfobj = closure(bathconfobj, base);
restore, scratch;
