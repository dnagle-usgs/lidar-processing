# these values filled in by    yorick -batch make.i
Y_MAKEDIR=/opt/alps/yorick
Y_EXE=/opt/alps/yorick/bin/yorick
Y_EXE_PKGS=
Y_EXE_HOME=/opt/alps/yorick
Y_EXE_SITE=/opt/alps/yorick
Y_HOME_PKG=

# ----------------------------------------------------- optimization flags

# options for make command line, e.g.-   make COPT=-g TGT=exe
COPT=$(COPT_DEFAULT)
TGT=$(DEFAULT_TGT)

# ------------------------------------------------ macros for this package

PKG_NAME=calps
PKG_I=calps.i

OBJS=triangle.o triangle_y.o interp_angles.o gridding.o region.o \
	level_short_dips.o ll2utm.o navd88.o set.o unique.o linux.o \
	profiler.o filebuffer.o eaarl_decode_fast.o centroid.o fs_rx.o \
	timsort.o multidata.o dir.o gpbox.o array.o rle.o

# change to give the executable a name other than yorick
PKG_EXENAME=yorick

# PKG_DEPLIBS=-Lsomedir -lsomelib   for dependencies of this package
# -lrt is required for ytime.h in profiler.c
PKG_DEPLIBS=-lrt
# set compiler (or rarely loader) flags specific to this package
PKG_CFLAGS=
PKG_LDFLAGS=

# list of additional package names you want in PKG_EXENAME
# (typically Y_EXE_PKGS should be first here)
EXTRA_PKGS=$(Y_EXE_PKGS)

# list of additional files for clean
PKG_CLEAN=

# autoload file for this package, if any
PKG_I_START=calps_start.i
# non-pkg.i include files for this package, if any
PKG_I_EXTRA=

# -------------------------------- standard targets and rules (in Makepkg)

# set macros Makepkg uses in target and dependency names
# DLL_TARGETS, LIB_TARGETS, EXE_TARGETS
# are any additional targets (defined below) prerequisite to
# the plugin library, archive library, and executable, respectively
PKG_I_DEPS=$(PKG_I)
Y_DISTMAKE=distmake

include $(Y_MAKEDIR)/Make.cfg
include $(Y_MAKEDIR)/Makepkg
include $(Y_MAKEDIR)/Make$(TGT)

# override macros Makepkg sets for rules and other macros
# Y_HOME and Y_SITE in Make.cfg may not be correct (e.g.- relocatable)
Y_HOME=$(Y_EXE_HOME)
Y_SITE=$(Y_EXE_SITE)

# reduce chance of yorick-1.5 corrupting this Makefile
MAKE_TEMPLATE = protect-against-1.5

# ------------------------------------- targets and rules for this package

# simple example:
#myfunc.o: myapi.h
# more complex example (also consider using PKG_CFLAGS above):
#myfunc.o: myapi.h myfunc.c
#	$(CC) $(CPPFLAGS) $(CFLAGS) -DMY_SWITCH -o $@ -c myfunc.c

triangle.o: triangle.h
triangle_y.o: triangle.h

filebuffer.o: filebuffer.h
eaarl_decode_fast.o: filebuffer.h

multidata.o: multidata.h
timsort.o: multidata.h timsort.h

# -------------------------------------------------------- end of Makefile
