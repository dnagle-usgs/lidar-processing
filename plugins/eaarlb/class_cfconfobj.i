// vim: set ts=2 sts=2 sw=2 ai sr et:

func cfconfobj(base, data) {
/* DOCUMENT cfconf = cfconfobj()
  -or- cfconf = cfconfobj(save(...))
  -or- cfconf = cfconfobj("/path/to/file.cfconf")

  This returns a cfconf object. This is a specialized subclass built on
  vegconfobj that adds curve fitting specific configuration elements to the framework.

  Please see help, vegconfobj for information on the vegconfobj framework, as
  well as help, confobj for more information on the underlying confobj
  framework. Follows are details on how the base class has been specialized.

  The primary difference from the base class is that  cfconfobj has specific
  knowledge of XYZZY

  Modified methods:

    cfconf, groups, <groups>, copy=<0|1>
      In addition to the behavior of the base class, this updates Tcl syncs.

    cfconf, read, "/path/to/file.cfconf"
      Overloaded for logging.

    cfconf, profile_add, "<group>", "<profile>"
    cfconf, profile_del, "<group>", "<profile>"
    cfconf, profile_rename, "<group>", "<old_profile>", "<new_profile>"
      In addition to their normal behavior, these will also keep Tcl updated
      with changes to the profile list.

  Internal modified methods:

    cfconf, validate, "<group>"
      Ensures the presence of all required keys, including conditional
      selection of keys based on "decay" setting. Also enforces proper types on
      them (double or integer). Also applies syncing to Tcl.

    cfconf(dumpgroups, compact=<0|1>)
      Extends base class to add bathver to output when compact=0.

    cfconf(cleangroups,)
      Ensures that only the relevant keys are kept. In particular, if you've
      swapped back and forth between "decay" settings on a profile, you'll end
      up with copies of each decay type's specialized settings in that profile.
      This makes sure that only the selected decay type's settings get written
      out to file.

  SEE ALSO: confobj, chanconfobj, vegconfobj
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

save, scratch, cfconfobj_groups;
func cfconfobj_groups(newgroups, copy=) {
  use, data;

  // Remove syncs
  for(i = 1; i <= data(*); i++) {
    if(!data(noop(i))(*,"active")) continue;
    group = data(*,i);
    drop = data(noop(i)).active(*,);
    tksync, remove,
      swrite(format="cfconf.data.%s.active.%s", group, drop),
      swrite(format="::eaarl::cfconf::settings(%s,%s)", group, drop);
    tksync, remove,
      swrite(format="cfconf.data.%s.active_name", group),
      swrite(format="::eaarl::cfconf::active_profile(%s)", group);
  }

  use_method, chanconfobj_groups, newgroups, copy=copy;

  // Add syncs
  for(i = 1; i <= data(*); i++) {
    tksetval, swrite(format="::eaarl::cfconf::profiles(%s)", data(*,i)),
      strjoin("{"+data(noop(i)).profiles(*,)+"}", " ");
  }
}
save, base, chanconfobj_groups=base.groups;
save, base, groups=cfconfobj_groups;

save, scratch, cfconfobj_validate;
func cfconfobj_validate(group) {
  use_method, chanconfobj_validate, group;

  // Only validate fields on active profile.
  use, data;
  active = data(noop(group)).active;
  channels = data(noop(group)).channels;

  // Values that all confs have
  defaults = save(
    smoothwf=0, thresh=3.0, curve="gaussian", initsd=1.0
  );

  /*
    smoothwf - non-negative integer; 0 means do not apply, positive is smoothwf
               factor to apply;
               default = 0
    thresh   - non-negative floating-point value;
               default = 3.0
    curve    - string representing which distribution to fit;
               default = “gaussian”
    initsd   - floating-point value representing initial value to use for the
               standard deviation value in the curve fitting processing;
               default = 1.0
   */

  // Values specific to a curve type
  /* We don't have these yet
  if(active.cfXYZZY == "gaussian") {
    defaults = save(smoothwf=0, thresh=3.0, curve="gaussian", initsd=1.0);
    drop = ["foo", "bar", "baz" ];
  } else if(active.cfXYZZY == "lognormal") {
    defaults = save(smoothwf=0, curve="lognormal", foo=1.0, bar=1.0, baz=-1.0);
    drop = ["thresh", "initsd"];
  } else {
    error, "Unknown curve type";
  }
  */

  key_default_and_cast, active, defaults;
  tksync, idleadd,
    swrite(format="cfconf.data.%s.active.%s", group, defaults(*,)),
    swrite(format="::eaarl::cfconf::settings(%s,%s)", group, defaults(*,));

  tksync, idleadd,
    swrite(format="cfconf.data.%s.active_name", group),
    swrite(format="::eaarl::cfconf::active_profile(%s)", group);
}
save, base, chanconfobj_validate=base.validate;
save, base, validate=cfconfobj_validate;

save, scratch, cfconfobj_read;
func cfconfobj_read(fn) {
  use_method, chanconfobj_read, fn;
  if(logger(info)) logger, info, "Loaded cf settings from "+fn;
}
save, base, chanconfobj_read=base.read;
save, base, read=cfconfobj_read;

save, scratch, cfconfobj_cleangroups;
func cfconfobj_cleangroups(void) {
  groups = use_method(chanconfobj_cleangroups,);
  for(i = 1; i <= groups(*); i++) {
    grp = groups(noop(i));

    for(j = 1; j <= grp.profiles(*); j++) {
      prof = grp.profiles(noop(j));
//    idx = prof(*, ["thresh", "noiseadj", "max_samples", "smoothwf"]); BEGONE
      idx = prof(*, ["smoothwf", "thresh", "curve", "initsd"]);
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
save, base, cleangroups=cfconfobj_cleangroups;

save, scratch, cfconfobj_dumpgroups;
func cfconfobj_dumpgroups(compact=) {
  output = use_method(chanconfobj_dumpgroups, compact=compact);
  if(!compact)
    save, output, cfver=2;
  return output;
}
save, base, chanconfobj_dumpgroups=base.dumpgroups;
save, base, dumpgroups=cfconfobj_dumpgroups;

save, scratch, cfconfobj_profile_add;
func cfconfobj_profile_add(group, profile) {
  use, data;
  use_method, chanconfobj_profile_add, group, profile;
  tksetval, swrite(format="::eaarl::cfconf::profiles(%s)", group),
    strjoin("{"+data(noop(group)).profiles(*,)+"}", " ");
}
save, base, chanconfobj_profile_add=base.profile_add;
save, base, profile_add=cfconfobj_profile_add;

save, scratch, cfconfobj_profile_del;
func cfconfobj_profile_del(group, profile) {
  use, data;
  use_method, chanconfobj_profile_del, group, profile;
  tksetval, swrite(format="::eaarl::cfconf::profiles(%s)", group),
    strjoin("{"+data(noop(group)).profiles(*,)+"}", " ");
}
save, base, chanconfobj_profile_del=base.profile_del;
save, base, profile_del=cfconfobj_profile_del;

save, scratch, cfconfobj_profile_rename;
func cfconfobj_profile_rename(group, oldname, newname) {
  use, data;
  use_method, chanconfobj_profile_rename, group, oldname, newname;
  tksetval, swrite(format="::eaarl::cfconf::profiles(%s)", group),
    strjoin("{"+data(noop(group)).profiles(*,)+"}", " ");
}
save, base, chanconfobj_profile_rename=base.profile_rename;
save, base, profile_rename=cfconfobj_profile_rename;

cfconfobj = closure(cfconfobj, base);
restore, scratch;
