// vim: set ts=2 sts=2 sw=2 ai sr et:

func sbconfobj(base, data) {
/* DOCUMENT sbconf = sbconfobj()
  -or- sbconf = sbconfobj(save(...))
  -or- sbconf = sbconfobj("/path/to/file.sbconf")

  This returns a sbconf object. This is a specialized subclass built on
  chanconfobj that adds veg-specific configuration elements to the framework.

  Please see help, chanconfobj for information on the chanconfobj framework, as
  well as help, confobj for more information on the underlying confobj
  framework. Follows are details on how the base class has been specialized.

  The primary difference from the base class is that  sbconfobj has specific
  knowledge of which keys are expected and what format they should be in
  (integer, double, etc.).

  Modified methods:

    sbconf, groups, <groups>, copy=<0|1>
      In addition to the behavior of the base class, this updates Tcl syncs.

    sbconf, read, "/path/to/file.sbconf"
      Overloaded for logging.

    sbconf, profile_add, "<group>", "<profile>"
    sbconf, profile_del, "<group>", "<profile>"
    sbconf, profile_rename, "<group>", "<old_profile>", "<new_profile>"
      In addition to their normal behavior, these will also keep Tcl updated
      with changes to the profile list.

  Internal modified methods:

    sbconf, validate, "<group>"
      Ensures the presence of all required keys, including conditional
      selection of keys based on "decay" setting. Also enforces proper types on
      them (double or integer). Also applies syncing to Tcl.

    sbconf(dumpgroups, compact=<0|1>)
      Extends base class to add bathver to output when compact=0.

    sbconf(cleangroups,)
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

save, scratch, sbconfobj_groups;
func sbconfobj_groups(newgroups, copy=) {
  use, data;

  // Remove syncs
  for(i = 1; i <= data(*); i++) {
    if(!data(noop(i))(*,"active")) continue;
    group = data(*,i);
    drop = data(noop(i)).active(*,);
    tksync, remove,
      swrite(format="sbconf.data.%s.active.%s", group, drop),
      swrite(format="::eaarl::sbconf::settings(%s,%s)", group, drop);
    tksync, remove,
      swrite(format="sbconf.data.%s.active_name", group),
      swrite(format="::eaarl::sbconf::active_profile(%s)", group);
  }

  use_method, chanconfobj_groups, newgroups, copy=copy;

  // Add syncs
  for(i = 1; i <= data(*); i++) {
    tksetval, swrite(format="::eaarl::sbconf::profiles(%s)", data(*,i)),
      strjoin("{"+data(noop(i)).profiles(*,)+"}", " ");
  }
}
save, base, chanconfobj_groups=base.groups;
save, base, groups=sbconfobj_groups;

save, scratch, sbconfobj_validate;
func sbconfobj_validate(group) {
  use_method, chanconfobj_validate, group;

  // Only validate fields on active profile.
  use, data;
  active = data(noop(group)).active;

  // Values that all confs have
  defaults = save(
    thresh=4.0
  );
  key_default_and_cast, active, defaults;
  tksync, idleadd,
    swrite(format="sbconf.data.%s.active.%s", group, defaults(*,)),
    swrite(format="::eaarl::sbconf::settings(%s,%s)", group, defaults(*,));

  tksync, idleadd,
    swrite(format="sbconf.data.%s.active_name", group),
    swrite(format="::eaarl::sbconf::active_profile(%s)", group);
}
save, base, chanconfobj_validate=base.validate;
save, base, validate=sbconfobj_validate;

save, scratch, sbconfobj_read;
func sbconfobj_read(fn) {
  use_method, chanconfobj_read, fn;
  if(logger(info)) logger, info, "Loaded veg settings from "+fn;
}
save, base, chanconfobj_read=base.read;
save, base, read=sbconfobj_read;

save, scratch, sbconfobj_cleangroups;
func sbconfobj_cleangroups(void) {
  groups = use_method(chanconfobj_cleangroups,);
  for(i = 1; i <= groups(*); i++) {
    grp = groups(noop(i));

    for(j = 1; j <= grp.profiles(*); j++) {
      prof = grp.profiles(noop(j));
      idx = prof(*, ["thresh"]);
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
save, base, cleangroups=sbconfobj_cleangroups;

save, scratch, sbconfobj_dumpgroups;
func sbconfobj_dumpgroups(compact=) {
  output = use_method(chanconfobj_dumpgroups, compact=compact);
  if(!compact)
    save, output, vegver=2;
  return output;
}
save, base, chanconfobj_dumpgroups=base.dumpgroups;
save, base, dumpgroups=sbconfobj_dumpgroups;

save, scratch, sbconfobj_profile_add;
func sbconfobj_profile_add(group, profile) {
  use, data;
  use_method, chanconfobj_profile_add, group, profile;
  tksetval, swrite(format="::eaarl::sbconf::profiles(%s)", group),
    strjoin("{"+data(noop(group)).profiles(*,)+"}", " ");
}
save, base, chanconfobj_profile_add=base.profile_add;
save, base, profile_add=sbconfobj_profile_add;

save, scratch, sbconfobj_profile_del;
func sbconfobj_profile_del(group, profile) {
  use, data;
  use_method, chanconfobj_profile_del, group, profile;
  tksetval, swrite(format="::eaarl::sbconf::profiles(%s)", group),
    strjoin("{"+data(noop(group)).profiles(*,)+"}", " ");
}
save, base, chanconfobj_profile_del=base.profile_del;
save, base, profile_del=sbconfobj_profile_del;

save, scratch, sbconfobj_profile_rename;
func sbconfobj_profile_rename(group, oldname, newname) {
  use, data;
  use_method, chanconfobj_profile_rename, group, oldname, newname;
  tksetval, swrite(format="::eaarl::sbconf::profiles(%s)", group),
    strjoin("{"+data(noop(group)).profiles(*,)+"}", " ");
}
save, base, chanconfobj_profile_rename=base.profile_rename;
save, base, profile_rename=sbconfobj_profile_rename;

sbconfobj = closure(sbconfobj, base);
restore, scratch;
