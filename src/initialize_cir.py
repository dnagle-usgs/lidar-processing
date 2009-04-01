"""cir_initialize.py - Initialize a cir dataset for mosaic processing."""
# $Id$
# Original David B. Nagle 2009-03-31

import optparse
import os
import os.path
import re
import shutil
import tarfile

SSH_AVAIL = True
try:
    import paramiko
except ImportError as err:
    SSH_AVAIL = False

COMPILED_RE = {}

class Error(Exception):
    pass

class LocalFSOpenError(Error, IOError):
    pass

class NoSSHError(Error):
    pass

class MultipleCirError(Error):
    pass

class InvalidArgCount(Error):
    pass

class BaseFS:
    """Base class for representing a file system."""
    def __del__(self):
        pass
    def exists(self, path):
        """Does the path exist?"""
        pass
    def isdir(self, path):
        """Is the path a directory?"""
        pass
    def walk(self, top, topdown=True):
        """Analogous to os.walk"""
        pass
    def listdir(self, path):
        """Analogouus to os.listdir"""
        pass
    def open(self, path, mode='r'):
        """Opens a file"""
        pass
    def mkdir(self, path):
        """Creates a directory"""
        pass
    def makedirs(self, path):
        """Creates a directory and all parents.
        
        Does not raise an error if the directory exists already.
        """
        pass

    def isfile(self, path):
        """Is path a file?"""
        return self.exists(path) and not self.isdir(path)

    def writefileobj(self, obj, path):
        """Writes a file object's data to the given path."""
        dst_file = self.open(path, "wb")
        shutil.copyfileobj(obj, dst_file)
        dst_file.close()

class LocalFS(BaseFS):
    """Represents a local file system."""
    def exists(self, path):
        return os.path.exists(path)

    def isdir(self, path):
        return os.path.isdir(path)

    def walk(self, top, topdown=True):
        for result in os.walk(top, topdown=topdown, followlinks=True):
            yield result

    def listdir(self, path):
        return os.listdir(path)

    def open(self, path, mode='r', tries=3):
        while tries:
            try:
                return open(path, mode)
            except IOError as (errno, errmsg):
                if errno == 2:
                    tries -= 1
                else:
                    print "Unexpected error:", sys.exc_info()[0]
                    raise
        else:
            raise LocalFSOpenError()

    def mkdir(self, path):
        os.mkdir(path)

    def makedirs(self, path):
        try:
            os.makedirs(path)
        except OSError as (errno, errmsg):
            if errno != 17:
                print "Unexpected error:", sys.exc_info()[0]
                raise

class RemoteFS(BaseFS):
    """Represents a remote filesystem accessed via SSH."""
    def __init__(self, host):
        self.host = host
        self.client = paramiko.SSHClient()
        self.client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        self.client.connect(self.host)
        self.sftp = self.client.open_sftp()

    def __del__(self):
        self.sftp.close()
        self.client.close()

    def exists(self, path):
        result = True
        try:
            self.sftp.normalize(path)
        except IOError:
            result = False
        return result

    def isdir(self, path):
        result = self.exists(path)
        if result:
            try:
                self.sftp.listdir(path)
            except IOError as (errno, strerror):
                # If it's a file, then it fails with err 2
                if errno == 2:
                    result = False
        return result

    def walk(self, top, topdown=True):
        if self.isdir(top):
            dirs = []
            files = []
            for name in self.sftp.listdir(top):
                if self.isfile(os.path.join(top, name)):
                    files.append(name)
                elif self.isdir(os.path.join(top, name)):
                    dirs.append(name)
            if topdown:
                yield (top, dirs, files)
            for dir in dirs:
                for result in self.walk(os.path.join(top, dir)):
                    yield result
            if not topdown:
                yield (top, dirs, files)

    def listdir(self, path):
        return self.sftp.listdir(path)

    def open(self, path, mode='r'):
        return self.sftp.open(path, mode)

    def mkdir(self, path):
        self.sftp.mkdir(path)

    def makedirs(self, path):
        if not self.exists(path):
            self.makedirs(os.path.dirname(path))
            self.mkdir(path)

def open_fs(path):
    """Parses the path and returns an appropriate filesystem object."""
    result = re.search("^([a-zA-Z.0-9]+):(.*)", path)
    if result:
        if SSH_AVAIL:
            server = result.group(1)
            path = result.group(2)
            fs = RemoteFS(server)
        else:
            raise NoSSHError()
    else:
        fs = LocalFS()
    return fs, path

def sync(fs_a, path_a, fs_b, path_b):
    """Syncs the first location to the second location.

    At present, this will copy files from _a to _b if they are missing in _b.
    It will not check to make sure they match, so changes do not propogate. It
    also does not check for deletions.
    """
    for root, dirs, files in fs_a.walk(path_a):
        for name in dirs:
            full_a = os.path.join(root, name)
            rel_a = os.path.relpath(full_a, path_a)
            full_b = os.path.join(path_b, rel_a)
            if not fs_b.isdir(full_b):
                fs_b.makedirs(full_b)
        for name in files:
            full_a = os.path.join(root, name)
            rel_a = os.path.relpath(full_a, path_a)
            full_b = os.path.join(path_b, rel_a)
            if not fs_b.isfile(full_b):
                fs_b.makedirs(os.path.dirname(full_b))
                fobj = fs_a.open(full_a, "rb")
                fs_b.writefileobj(fobj, full_b)
                fobj.close()

def cirfile_re():
    """Creates and returns a regular expression object for CIR files.

    The pattern is similar to ######-######-###-cir.jpg.
    """
    global COMPILED_RE
    if 'cirfile' in COMPILED_RE:
        return COMPILED_RE['cirfile']

    dmreg = r"0[0-9]|1[01]"
    ddreg = r"0[1-9]|[12][0-9]|3[01]"
    dyreg = r"[890123][0-9]"
    threg = r"[01][0-9]|2[0-3]"
    tmreg = r"[0-5][0-9]"
    tsreg = r"[0-5][0-9]"
    msreg = r"[0-9][0-9][0-9]"

    date_reg = "(?P<dm>{0})(?P<dd>{1})(?P<dy>{2})".format(dmreg, ddreg, dyreg)
    time_reg = "(?P<th>{0})(?P<tm>{1})(?P<ts>{2})".format(threg, tmreg, tsreg)
    
    full_reg = "^(?P<date>{0})-(?P<time>{1})-{2}-cir.jpg$".format(
        date_reg, time_reg, msreg)

    COMPILED_RE['cirfile'] = re.compile(full_reg)
    return COMPILED_RE['cirfile']

def tarfile_re():
    """Creates and returns a regular expression object for tar files.

    This matches *.tar, *.tar.gz, and *.tar.bz2.
    """
    global COMPILED_RE
    if 'tarfile' in COMPILED_RE:
        return COMPILED_RE['tarfile']

    COMPILED_RE['tarfile'] = re.compile('\.tar(\.bz2|\.gz)?$')
    return COMPILED_RE['tarfile']

def handle_mission(src, dst):
    """Initialize dst with the mission found in src."""
    src_fs, src = open_fs(src)
    dst_fs, dst = open_fs(dst)
    if not src_fs.isdir(src):
        print "Source path is not a valid directory. Aborting."
    else:
        for missionday in src_fs.listdir(src):
            mday_dir = os.path.join(src, missionday)
            if src_fs.isdir(mday_dir):
                print "Testing", missionday
                mday_cir = None
                mday_traj = None
                for name in src_fs.listdir(mday_dir):
                    if name[:3] == 'cir':
                        if mday_cir is None:
                            mday_cir = os.path.join(mday_dir, name)
                        else:
                            raise MultipleCirError()
                    elif name == 'trajectories':
                        mday_traj = os.path.join(mday_dir, name)
                if mday_cir and mday_traj:
                    # copy images
                    dst_cir = os.path.join(dst, missionday, 'photos')
                    extract_all_tars(src_fs, mday_cir, dst_fs, dst_cir)
                    # copy trajectories
                    dst_traj = os.path.join(dst, missionday, 'trajectories')
                    sync(src_fs, mday_traj, dst_fs, dst_traj)
            elif src_fs.isfile(mday_dir):
                if re.search("\.json$", missionday):
                    json_file_src = mday_dir
                    json_file_dst = os.path.join(dst, missionday)
                    # copy
                    fobj = src_fs.open(json_file_src, "rb")
                    dst_fs.writefileobj(fobj, json_file_dst)
                    fobj.close()

def extract_all_tars(src_fs, src_dir, dest_fs, dest_dir):
    """Extract CIR images from tar files."""
    tarlist = generate_tarlist(src_fs, src_dir)
    all_extr = 0
    all_skip = 0
    tar_count = 0
    for name, tarobj in tarlist:
        tar_count += 1
        print "Processing", name
        (extr, skip) = extract_tar_images(tarobj, dest_fs, dest_dir)
        all_extr += extr
        all_skip += skip
    print ""
    print tar_count, "tar files processed."
    print all_extr, "images were extracted."
    if all_skip > 0:
        print all_skip, "images were skipped that already existed."

def generate_tarlist(fs, src_dir):
    """Finds candidate tar files."""
    tar_re = tarfile_re()
    for root, dirs, files in fs.walk(src_dir):
        for name in files:
            if tar_re.search(name):
                full_name = os.path.join(root, name)
                fobj = fs.open(full_name, "rb")
                yield (name, fobj)
                fobj.close()

def extract_tar_images(src_tar_obj, dest_fs, dest_dir, overwrite=False):
    """Extract CIR images from a single tar file."""
    cir_re = cirfile_re()
    tar_obj = tarfile.open(fileobj=src_tar_obj)
    count_extr = 0
    count_skip = 0
    if tar_obj is not None:
        for tarinfo in tar_obj:
            file_name = os.path.split(tarinfo.name)[1]
            match = cir_re.search(file_name)
            if match:
                dst_filename = "{0}-{1}-cir.jpg".format(
                    match.group('date'), match.group('time'))
                subdir_name = "{0}{1}".format(match.group('th'), match.group('tm'))
        
                dst_subdir = os.path.join(dest_dir, subdir_name)
                dst_filename = os.path.join(dst_subdir, dst_filename)

                if os.path.isfile(dst_filename) or overwrite:
                    count_skip += 1
                else:
                    if not os.path.isdir(dst_subdir):
                        os.makedirs(dst_subdir)

                    src_file = tar_obj.extractfile(tarinfo)
                    dest_fs.writefileobj(src_file, dst_filename)
                    src_file.close()
                    count_extr += 1
        if count_skip > 0:
            print "  Skipped", count_skip, "files that already existed"
        if count_extr > 0:
            print "  Extracted", count_extr, "files"
    return (count_extr, count_skip)

def launch_from_commandline():
    """Parses command line arguments and runs the program."""
    parser = optparse.OptionParser()
    (options, args) = parser.parse_args()
    if len(args) != 2:
        raise InvalidArgCount()
    path_src, path_dst = args
    handle_mission(path_src, path_dst)

if __name__ == '__main__':
    launch_from_commandline()
