#!/bin/bash
# Copyright 2016 VMware, Inc. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Build the base of a bootable ISO

# exit on failure and configure debug, include util functions
set -e && [ -n "$DEBUG" ] && set -x
DIR=$(dirname $(readlink -f "$0"))
. $DIR/base/utils.sh


function usage() {
echo "Usage: $0 -p package-name(tgz) [-c yum-cache]" 1>&2
exit 1
}

while getopts "c:p:" flag
do
    case $flag in

        p)
            # Required. Package name
            PACKAGE="$OPTARG"
            ;;

        c)
            # Optional. Offline cache of yum packages
            cache="$OPTARG"
            ;;

        *)
            usage
            ;;
    esac
done

shift $((OPTIND-1))

# check there were no extra args and the required ones are set
if [ ! -z "$*" -o -z "$PACKAGE" ]; then
    usage
fi

# prep the build system
ensure_apt_packages cpio rpm tar ca-certificates

PKGDIR=$(mktemp -d)

# initialize the bundle
initialize_bundle $PKGDIR

# base filesystem setup
mkdir -p $(rootfs_dir $PKGDIR)/{etc/yum,etc/yum.repos.d}
ln -s /lib $(rootfs_dir $PKGDIR)/lib64
cp $DIR/base/*.repo $(rootfs_dir $PKGDIR)/etc/yum.repos.d/
cp $DIR/base/yum.conf $(rootfs_dir $PKGDIR)/etc/yum/

# install the core packages
yum_cached -c $cache -u -p $PKGDIR install filesystem coreutils linux-esx --nogpgcheck -y
# strip the cache from the resulting image
yum_cached -c $cache -p $PKGDIR clean all

# move kernel into bootfs /boot directory so that syslinux could load it
mv $(rootfs_dir $PKGDIR)/boot/vmlinuz-* $(bootfs_dir $PKGDIR)/boot/vmlinuz64

# package up the result
pack $PKGDIR $PACKAGE
