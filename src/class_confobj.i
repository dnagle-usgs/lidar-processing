// vim: set ts=2 sts=2 sw=2 ai sr et:

scratch = save(scratch);

func confobj(base, data) {
/* DOCUMENT conf = confobj()
  -or- conf = confobj(save(...))
  -or- conf = confobj("/path/to/file")

  Creates and returns a generic configuration object. This is intended to serve
  as the base class for more specialized configuration objects.

  A configuration object contains one or more groups of profiles. Each group
  can have one active profile at a given time. In the base implementation, only
  one group is permitted; however, the implementation is coded to readily
  support multiple groups for classes that build on this framework.

  Note: Classes that build on this may change the parameters for some methods.

  Methods:

    settings = conf(settings,)
      Returns the current active settings. Classes that build on this framework
      and intend to use multiple groups will want to parameterize this so that
      it can determine which group should be used. The base implementation
      simply returns the first (and only) group's active profile data.

    conf, set, "<group>", "<key>", <val>
      In the given GROUP's active profile, set KEY to VAL.

    val = conf(get, "<group>", "<key">)
      In the given GROUP's active profile, retrieve the VAL for KEY.

    conf, profiles
    conf, profiles, "<group>"
      Show a list of each group and its profile names (or only the given GROUP,
      if specified).

    profs = conf(profiles,)
      Returns an oxy group whose keys are group names and whose values are
      string arrays containing the profile names for the corresponding groups.

    profs = conf(profiles, "<group>")
      Returns an array of strings containing the profile names for the given
      GROUP.

    conf, profile_select, "<group>", "<profile>"
      For the given GROUP, make PROFILE the active profile.

    conf, profile_add, "<group>", "<profile>"
      For the given GROUP, add a new PROFILE (but does not make it active).

    conf, profile_del, "<group>", "<profile>"
      For the given GROUP, delete PROFILE. If it's the active profile, the
      first remaining profile will be made active. If it's the only profile, an
      error will occur because you need at least one profile per group.

    conf, profile_rename, "<group>", "<old_profile>", "<new_profile>"
      For the given GROUP, rename OLD_PROFILE to NEW_PROFILE. There must be no
      other profile already named NEW_PROFILE for GROUP.

    conf, groups, <new groups object>, copy=<0|1>
      Changes the group definitions. When called by third-party code, the new
      groups object will generally just be an object defining the new groups:
        save(group1=save(), group2=save())
      By default, copy=1 which means settings will be copied from the old
      groups layout to the new. It's up to subclasses to figure out how to
      sensibly do that.

    conf, write, "<filename>"
      Saves the current configuration out to file. The file will be in a JSON
      format.

    conf, read, "<filename>"
      Reads a configuration in from file. Any existing configuration is
      discarded.

    conf, clear
      Clears the current configuration, giving you a default empty
      configuration.

    conf, display
    conf, display, "<group>"
    conf, display, "<group>", "<profile>"
      Displays configuration info on the command line. If GROUP is omitted, all
      groups are shown. If PROFILE is omitted, then the active profile is
      shown. Otherwise, GROUP and/or PROFILE specified are shown.

  Internal methods:
  These methods are only intended to be used internally by confobj or by
  classes that build on confobj. They generally shouldn't need to be used by
  outside code or by end-users.

    conf, validate, "<group>"
      Performs validation on the specific GROUP and its current active profile.
      This class primarily just makes sure it has the expected structure.
      Subclasses may also wish to enforce the presence and type of specific
      keys in the active profile.

    conf, groups_migrate, <oldgroups>, <newgroups>, <oldmap>, <newmap>
      Called by conf,groups when copy=1. This handles the actual copying from
      old to new. OLDGROUPS is the current groups configuration and NEWGROUP is
      the new. OLDMAP and NEWMAP are arrays of strings, with equal lengths,
      that specify which groups to copy from and to. For example, if your old
      groups had a single group A and you wanted to have two new groups X and Y
      that each receive a copy from A, you would have oldmap=["A","A"] and
      newmap=["X","Y"]. As another example, if your old groups had groups X and
      Y that you wanted to merge into a single new group A, you would have
      oldmap=["X","Y"] and newmap=["A"].

    conf, json, "<json>"
      This decodes the given JSON and then passes the decoded object to
      conf,groups (using copy=0). This is used primarily by conf,read.

    conf(json, compact=<0|1>)
      Returns the current configuration in a JSON format. By default compact=0
      which means it's more human readable and contains additional information
      suitable for future import. With compact=1, the output is more compact
      but shouldn't be used for long-term storage. This is primarily used by
      conf,write.

    <dumped> = conf(dumpgroups, compact=<0|1>)
      Internal method used to prepare group data to be encapsulated by
      conf(json,).

    <groups> = conf(cleangroups,)
      This returns a "clean" form of the groups data. While the validate method
      makes sure everything we use is valid, it doesn't generally throw
      anything away. This method goes returns a copy of the configuration that
      throws away anything extra that shouldn't be there. This is used
      primarily during conf,write.

    conf, upgrade, <working groups>
      This is used by conf,read on the loaded new groups object. If it's using
      an older version of confobj, it will get upgraded.
*/
  conf = obj_copy(base);
  save, conf, data=save(null=save());
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
base = save();

save, scratch, confobj_settings;
func confobj_settings(void) {
  use, data;
  return data(1).active;
}
save, base, settings=confobj_settings;

save, scratch, confobj_set;
func confobj_set(group, key, val) {
  use, data;
  if(!data(*,group)) error, "invalid group";
  save, data(noop(group)).active, noop(key), val;

  use_method, validate, group;
}
save, base, set=confobj_set;

save, scratch, confobj_get;
func confobj_get(group, key) {
  use, data;
  if(!data(*,group)) error, "invalid group";
  active = data(noop(group)).active;
  return is_void(key) ? active : active(noop(key));
}
save, base, get=confobj_get;

save, scratch, confobj_profiles;
func confobj_profiles(group, fh=) {
  use, data;

  if(!am_subroutine()) {
    if(!is_void(group)) {
      if(!data(*,group)) error, "invalid group";
      return data(noop(group)).profiles(*,);
    }
    result = save();
    for(i = 1; i <= data(*); i++) {
      save, result, data(*,i), data(noop(i)).profiles(*,);
    }
    return result;
  }

  if(is_void(group)) group = data(*,);

  for(i = 1; i <= numberof(group); i++) {
    if(!data(*,group(i))) error, "invalid group";
    write, fh, format="%s:\n", group(i);
    profs = data(group(i)).profiles(*,);
    for(j = 1; j <= numberof(profs); j++) {
      write, fh, format="    %s\n", profs(j);
    }
    if(i < numberof(group)) write, fh, format="%s", "\n";
  }
}
save, base, profiles=confobj_profiles;

save, scratch, confobj_profile_select;
func confobj_profile_select(group, profile) {
  use, data;
  if(!data(*,group)) error, "invalid group";
  grp = data(noop(group));
  if(!grp.profiles(*,profile)) error, "invalid profile";
  save, grp, active_name=profile;
  use_method, validate, group;
}
save, base, profile_select=confobj_profile_select;

save, scratch, confobj_profile_add;
func confobj_profile_add(group, profile) {
  use, data;
  if(!data(*,group)) error, "invalid group";
  grp = data(noop(group));
  // Adding a profile that already exists is a no-op
  if(grp.profiles(*,profile)) return;
  save, grp.profiles, noop(profile), obj_copy(grp.active, recurse=1);
}
save, base, profile_add=confobj_profile_add;

save, scratch, confobj_profile_del;
func confobj_profile_del(group, profile) {
  use, data;
  if(!data(*,group)) error, "invalid group";

  grp = data(noop(group));
  profiles = grp.profiles;

  // Removing a profile that doesn't exist is a no-op
  if(!profiles(*,profile)) return;
  if(profiles(*) == 1) error, "cannot remove only profile";

  // obj_delete changes reference, need to re-save
  obj_delete, profiles, noop(profile);
  save, grp, profiles;

  // in case the active group was deleted
  if(grp.active_name == profile)
    save, grp, active_name=profiles(*,1);

  use_method, validate, group;
}
save, base, profile_del=confobj_profile_del;

save, scratch, confobj_profile_rename;
func confobj_profile_rename(group, oldname, newname) {
  use, data;
  if(!data(*,group)) error, "invalid group";

  grp = data(noop(group));
  profiles = grp.profiles;

  if(!profiles(*,oldname))
    error, "invalid profile";
  if(profiles(*,newname))
    error, "new name conflicts with existing profile";

  // obj_pop changes reference, need to re-save
  tmp = obj_pop(profiles, noop(oldname));
  save, profiles, noop(newname), tmp;
  save, grp, profiles;

  // in case active group was renamed
  if(grp.active_name == oldname)
    save, grp, active_name=newname;

  use_method, validate, group;
}
save, base, profile_rename=confobj_profile_rename;

save, scratch, confobj_groups;
func confobj_groups(newgroups, copy=) {
// Default implementation permits only one group
// So, this simplifies to a rename
  default, copy, 1;
  use, data;

  if(newgroups(*) != 1)
    error, "only one group allowed";

  oldgroups = data;
  oldmap = oldgroups(*,1);
  newmap = newgroups(*,1);

  if(copy)
    use_method, groups_migrate, oldgroups, newgroups, oldmap, newmap;

  data = newgroups;

  for(i = 1; i <= data(*); i++) {
    use_method, validate, data(*,i);
  }
}
save, base, groups=confobj_groups;

save, scratch, confobj_groups_migrate;
func confobj_groups_migrate(oldgroups, newgroups, oldmap, newmap) {
  // Make sure each new group has a profile entry; for now, it can be empty
  for(i = 1; i <= newgroups(*); i++) {
    grp = newgroups(noop(i));
    if(!grp(*,"profiles"))
      save, grp, profiles=save();
  }

  // Map old groups to new, to prevent us from repeating copies
  w = munique(oldmap, newmap);
  oldmap = oldmap(w);
  newmap = newmap(w);

  // Look for name conflicts for imports
  cinfo = save();
  count = numberof(oldmap);
  for(i = 1; i <= count; i++) {
    if(!cinfo(*,newmap(i))) {
      save, cinfo, noop(newmap(i)),
        save(conflicts=[], names=newgroups(newmap(i)).profiles(*,));
    }
    cur = cinfo(newmap(i));
    names = oldgroups(oldmap(i)).profiles(*,);
    conflicts = set_remove_duplicates(
      grow(cur.conflicts, set_intersection(cur.names, names)));
    names = set_remove_duplicates(grow(cur.names, names));
    save, cur, conflicts, names;
  }

  // Now actually do imports
  for(i = 1; i <= numberof(oldmap); i++) {
    // Get the names of the old and new groups
    oldgrp = oldmap(i);
    newgrp = newmap(i);
    // Retrieve profile objects for each
    oldprof = oldgroups(noop(oldgrp)).profiles;
    newprof = newgroups(noop(newgrp)).profiles;
    // Retrieve the information we just populated for conflicts and names
    conflicts = cinfo(noop(newgrp)).conflicts;
    names = cinfo(noop(newgrp)).names;

    // Iterate over the profiles in the old group (to import each)
    for(j = 1; j <= oldprof(*); j++) {
      // Retrieve the profile name
      profname = oldprof(*,noop(j));

      // If there was a conflict, try appending the old group name in parens;
      // that should generally give a unique name. But if it doesn't, we find
      // an integer that we can add to it that does make it unique.
      if(anyof(conflicts == profname)) {
        profname = swrite(format="%s (%s)", profname, oldgrp);
        if(anyof(names == profname)) {
          k = 1;
          do {
            profname = swrite(format="%s %d", profname, k++);
          } while(anyof(names == profname));
          grow, names, profname;
        }
      }

      // Save to the new profiles group with the new name
      save, newprof, noop(profname), oldprof(noop(j));
    }

    // In case we added any names, save them back to cinfo
    save, cinfo(noop(newgrp)), names;
  }
}
save, base, groups_migrate=confobj_groups_migrate;

save, scratch, confobj_validate;
func confobj_validate(group) {
// Perform basic validation to make sure the state is consistent.
// This should probably be overridden and wrapped around.
//
//    func myconf_validate(group) {
//      use_method, confobj_validate, group;
//      // custom stuff
//    }
//    save, myconf, confobj_validate=myconf.validate;
//    save, myconf, validate=myconf_validate;
//
  use, data;

  if(!data(*,group)) error, "invalid group";
  grp = data(noop(group));

  if(!grp(*,"profiles"))
    save, grp, profiles=save();
  if(!grp.profiles(*))
    save, grp.profiles, "default", save();
  if(!grp(*,"active_name"))
    save, grp, active_name=grp.profiles(*,1);

  save, grp, active=grp.profiles(grp.active_name);
}
save, base, validate=confobj_validate;

save, scratch, confobj_write;
func confobj_write(fn) {
  f = open(fn, "w");
  write, f, format="%s\n", use_method(json,);
  close, f;
  if(logger(info)) logger, info, "Saved bathy settings to "+fn;
}
save, base, write=confobj_write;

save, scratch, confobj_read;
func confobj_read(fn) {
  f = open(fn, "r");
  use_method, json, rdfile(f);
  close, f;
  if(logger(info)) logger, info, "Loaded bathy settings from "+fn;
}
save, base, read=confobj_read;

save, scratch, confobj_clear;
func confobj_clear(void) {
  working = save(default=save());
  use_method, groups, working, copy=0;
}
save, base, clear=confobj_clear;

save, scratch, confobj_json;
func confobj_json(json, compact=) {
  use, data;

  if(!is_void(json)) {
    working = json_decode(json, objects="");
    working = use_method(upgrade, working);
    use_method, groups, working.groups, copy=0;
  }

  if(!am_subroutine()) {
    output = use_method(dumpgroups, compact=compact);
    return json_encode(output, indent=(compact ? [] : 2));
  }
}
save, base, json=confobj_json;

save, scratch, confobj_dumpgroups;
func confobj_dumpgroups(compact=) {
  output = save();
  if(!compact)
    save, output, confver=1;
  save, output, groups=use_method(cleangroups,);
  if(!compact) {
    save, output, "save environment", save(
      "user", get_user(),
      "host", get_host(),
      "timestamp", soe2iso8601(getsoe()),
      "repository", _hgid
    );
  }
  return output;
}
save, base, dumpgroups=confobj_dumpgroups;

save, scratch, confobj_cleangroups;
func confobj_cleangroups(void) {
  use, data;
  groups = save();
  for(i = 1; i <= data(*); i++) {
    grp = obj_copy(data(noop(i)), recurse=1);
    grp = obj_delete(grp, "active");
    save, groups, data(*,i), grp;
  }
  return groups;
}
save, base, cleangroups=confobj_cleangroups;

save, scratch, confobj_upgrade;
func confobj_upgrade(versions, working) {
  if(!working(*,"confver"))
    save, working, confver=1;
  if(is_string(working.confver))
    save, working, confver=atoi(working.confver);

  for(i = working.confver; i <= versions(*); i++) {
    working = versions(noop(i), working);
  }

  maxver = versions(*) + 1;
  if(working.confver > maxver) {
    write, format=" WARNING: configuration formation is version %d!\n",
      working.confver;
    write, format=" This version of ALPS can only handle up to version %d.\n",
      maxversion;
    write, "Attempting to use anyway, but errors may ensue...";
  }

  return working;
}

scratch = save(scratch, versions);
versions = save();

/*
  At the moment, there's only one version. If we need to upgrade later,
  uncomment this section and modify to suit. Each new version gets an addition
  to the versions object.

func confobj_upgrade_version1(working) {
  // do something to update working here...
  save, working, confver=2;
  return working;
}
save, versions, confobj_upgrade_version1

*/

save, base, upgrade=closure(confobj_upgrade, versions);
restore, scratch;

save, scratch, confobj_display;
func confobj_display(group, profile, fh=) {
  use, data;
  if(is_void(group)) {
    for(i = 1; i <= data(*); i++) {
      use_method, display, data(*,i), fh=fh;
    }
    return;
  }

  if(!data(*,group)) error, "invalid group";
  grp = data(noop(group));
  default, profile, grp.active_name;
  if(!grp.profiles(*,profile)) error, "invalid profile";
  prof = grp.profiles(noop(profile));
  lines = strsplit(obj_show(prof), "\n");
  lines(1) = swrite(format="%s -> %s", group, profile);
  write, fh, format="%s\n", lines;
}
save, base, display=confobj_display;

confobj = closure(confobj, base);
restore, scratch;
