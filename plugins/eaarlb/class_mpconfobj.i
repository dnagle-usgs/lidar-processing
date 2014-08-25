// vim: set ts=2 sts=2 sw=2 ai sr et:

func mpconfobj(base, data) {
/* DOCUMENT mpconf = mpconfobj()
  -or- mpconf = mpconfobj(save(...))
  -or- mpconf = mpconfobj("/path/to/file.mpconf")

  This returns a mpconf object. This is a specialized subclass built on
  chanconfobj that adds mp-specific configuration elements to the framework.

  Please see help, chanconfobj for information on the chanconfobj framework, as
  well as help, confobj for more information on the underlying confobj
  framework. Follows are details on how the base class has been specialized.

  The primary difference from the base class is that  mpconfobj has specific
  knowledge of which keys are expected and what format they should be in
  (integer, double, etc.).

  Modified methods:

    mpconf, groups, <groups>, copy=<0|1>
      In addition to the behavior of the base class, this updates Tcl syncs.

    mpconf, read, "/path/to/file.mpconf"
      Overloaded for logging.

    mpconf, profile_add, "<group>", "<profile>"
    mpconf, profile_del, "<group>", "<profile>"
    mpconf, profile_rename, "<group>", "<old_profile>", "<new_profile>"
      In addition to their normal behavior, these will also keep Tcl updated
      with changes to the profile list.

  Internal modified methods:

    mpconf, validate, "<group>"
      Ensures the presence of all required keys, including conditional
      selection of keys based on "decay" setting. Also enforces proper types on
      them (double or integer). Also applies syncing to Tcl.

    mpconf(dumpgroups, compact=<0|1>)
      Extends base class to add bathver to output when compact=0.

    mpconf(cleangroups,)
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

save, scratch, mpconfobj_groups;
func mpconfobj_groups(newgroups, copy=) {
  use, data;

  // Remove syncs
  for(i = 1; i <= data(*); i++) {
    if(!data(noop(i))(*,"active")) continue;
    group = data(*,i);
    drop = data(noop(i)).active(*,);
    tksync, remove,
      swrite(format="mpconf.data.%s.active.%s", group, drop),
      swrite(format="::eaarl::mpconf::settings(%s,%s)", group, drop);
    tksync, remove,
      swrite(format="mpconf.data.%s.active_name", group),
      swrite(format="::eaarl::mpconf::active_profile(%s)", group);
  }

  use_method, chanconfobj_groups, newgroups, copy=copy;

  // Add syncs
  for(i = 1; i <= data(*); i++) {
    tksetval, swrite(format="::eaarl::mpconf::profiles(%s)", data(*,i)),
      strjoin("{"+data(noop(i)).profiles(*,)+"}", " ");
  }
}
save, base, chanconfobj_groups=base.groups;
save, base, groups=mpconfobj_groups;

save, scratch, mpconfobj_validate;
func mpconfobj_validate(group) {
  use_method, chanconfobj_validate, group;

  // Only validate fields on active profile.
  use, data;
  active = data(noop(group)).active;
  channels = data(noop(group)).channels;

  // Values that all confs have
  defaults = save(
    thresh=4.0, max_samples=0, smoothwf=0
  );
  if(numberof(channels) == 1 && channels(1) == 3)
    save, defaults, max_samples=20;
  key_default_and_cast, active, defaults;
  tksync, idleadd,
    swrite(format="mpconf.data.%s.active.%s", group, defaults(*,)),
    swrite(format="::eaarl::mpconf::settings(%s,%s)", group, defaults(*,));

  tksync, idleadd,
    swrite(format="mpconf.data.%s.active_name", group),
    swrite(format="::eaarl::mpconf::active_profile(%s)", group);
}
save, base, chanconfobj_validate=base.validate;
save, base, validate=mpconfobj_validate;

save, scratch, mpconfobj_read;
func mpconfobj_read(fn) {
  use_method, chanconfobj_read, fn;
  if(logger(info)) logger, info, "Loaded mp settings from "+fn;
}
save, base, chanconfobj_read=base.read;
save, base, read=mpconfobj_read;

save, scratch, mpconfobj_cleangroups;
func mpconfobj_cleangroups(void) {
  groups = use_method(chanconfobj_cleangroups,);
  for(i = 1; i <= groups(*); i++) {
    grp = groups(noop(i));

    for(j = 1; j <= grp.profiles(*); j++) {
      prof = grp.profiles(noop(j));
      idx = prof(*, ["thresh", "max_samples", "smoothwf"]);
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
save, base, cleangroups=mpconfobj_cleangroups;

save, scratch, mpconfobj_dumpgroups;
func mpconfobj_dumpgroups(compact=) {
  output = use_method(chanconfobj_dumpgroups, compact=compact);
  if(!compact)
    save, output, mpver=1;
  return output;
}
save, base, chanconfobj_dumpgroups=base.dumpgroups;
save, base, dumpgroups=mpconfobj_dumpgroups;

save, scratch, mpconfobj_profile_add;
func mpconfobj_profile_add(group, profile) {
  use, data;
  use_method, chanconfobj_profile_add, group, profile;
  tksetval, swrite(format="::eaarl::mpconf::profiles(%s)", group),
    strjoin("{"+data(noop(group)).profiles(*,)+"}", " ");
}
save, base, chanconfobj_profile_add=base.profile_add;
save, base, profile_add=mpconfobj_profile_add;

save, scratch, mpconfobj_profile_del;
func mpconfobj_profile_del(group, profile) {
  use, data;
  use_method, chanconfobj_profile_del, group, profile;
  tksetval, swrite(format="::eaarl::mpconf::profiles(%s)", group),
    strjoin("{"+data(noop(group)).profiles(*,)+"}", " ");
}
save, base, chanconfobj_profile_del=base.profile_del;
save, base, profile_del=mpconfobj_profile_del;

save, scratch, mpconfobj_profile_rename;
func mpconfobj_profile_rename(group, oldname, newname) {
  use, data;
  use_method, chanconfobj_profile_rename, group, oldname, newname;
  tksetval, swrite(format="::eaarl::mpconf::profiles(%s)", group),
    strjoin("{"+data(noop(group)).profiles(*,)+"}", " ");
}
save, base, chanconfobj_profile_rename=base.profile_rename;
save, base, profile_rename=mpconfobj_profile_rename;

mpconfobj = closure(mpconfobj, base);
restore, scratch;
