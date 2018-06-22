# Airborne Lidar Processing System (ALPS)

The Airborne Lidar Processing System (ALPS) was used to process data acquired
by the EAARL-A and EAARL-B lidar systems. The EAARL sensors were operational
between 2001 and 2014. The USGS has no plans for further development or support
of EAARL or of its associated software (including this software).

## Installing ALPS

The main ALPS software runs under a combination of Yorick and Tcl/Tk. The
software also leverages a number of third-party software packages.
Additionally, ALPS also includes a collection of stand-alone scripts and
compiled utility programs that are used for tasks outside of the main program.

The install directory can be used to install the various software that ALPS
requires to run. The software is expected to be installed alongside of this
code repository. For example, if you want to install the software under
/opt/alps, then you would put this repository at /opt/alps/lidar-processing.

To build the software, create a directory named build alongside of the
repository. For example, if the repository is at /opt/alps/lidar-processing,
then the build directory should be located at /opt/alps/build. Then cmake is
used to generate the build files. Then you can download the software and
install it. Using the example installation location of /opt/alps, here are the
commands to run:

```sh
cd /opt/alps
mkdir build
cd build
cmake ../lidar-processing/install
make download
make install
```

Please be advised that you may also have to install additional development
libraries using the package manager (such as apt-get or yum) provided by your
linux distrution.

The idl subdirectory contains code that runs in the IDL programming language.
IDL requires a paid license and must be installed separately from ALPS if you
intend to use the small portions of the software that require it.

ALPS also contains some experimental python integration code. However, Python
and its required packages are not installed as part of the installer process.

## Sources

By default, the installer code will download the source code for each required
package. However, it also supports using a directory of predownloaded files. It
will check for a directory named sources alongside of the build and
lidar-processing directories. For example, if you are installing under
/opt/alps, then it will look for /opt/alps/sources.

If the sources directory exists, then the "make download" step will extract
files from that directory instead of downloading from the internet.

You can generate a sources directory by following the following steps:

```sh
cd /opt/alps
mkdir build
cd build
cmake ../lidar-processing/install
make download
make archive
```

The final command will archive the downloaded sources into the sources
directory.

## License

This software is licensed under [CC0 1.0] and is in the [public domain] because
it contains materials that originally came from the [U.S. Geological Survey
(USGS)], an agency of the [United States Department of Interior]. For more
information, see the [official USGS copyright policy].

[CC0 1.0]: http://creativecommons.org/publicdomain/zero/1.0/
[public domain]: https://en.wikipedia.org/wiki/Public_domain
[U.S. Geological Survey (USGS)]: https://www.usgs.gov/
[United States Department of Interior]: https://www.doi.gov/
[official USGS copyright policy]: http://www.usgs.gov/information-policies-and-instructions/copyrights-and-credits

## Disclaimer

This software is preliminary or provisional and is subject to revision. It is
being provided to meet the need for timely best science. The software has not
received final approval by the U.S. Geological Survey (USGS). No warranty,
expressed or implied, is made by the USGS or the U.S. Government as to the
functionality of the software and related material nor shall the fact of
release constitute any such warranty. The software is provided on the condition
that neither the USGS nor the U.S. Government shall be held liable for any
damages resulting from the authorized or unauthorized use of the software.

The USGS provides no warranty, expressed or implied, as to the correctness of
the furnished software or the suitability for any purpose. The software has
been tested, but as with any complex software, there could be undetected
errors. Users who find errors are requested to report them to the USGS.

References to non-USGS products, trade names, and (or) services are provided
for information purposes only and do not constitute endorsement or warranty,
express or implied, by the USGS, U.S. Department of Interior, or U.S.
Government, as to their suitability, content, usefulness, functioning,
completeness, or accuracy.

Although this program has been used by the USGS, no warranty, expressed or
implied, is made by the USGS or the United States Government as to the accuracy
and functioning of the program and related program material nor shall the fact
of distribution constitute any such warranty, and no responsibility is assumed
by the USGS in connection therewith.

This software is provided "AS IS."
