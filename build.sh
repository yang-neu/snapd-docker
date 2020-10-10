#! /bin/sh
#
# make sure to have docker installed before running this script!
# (tested with the docker.io deb and the docker snap package under
# ubuntu 16.04)
#

set -e

CONTNAME=snappy
IMGNAME=snapd
RELEASE=18.04

SUDO=""
if [ -z "$(id -Gn|grep docker)" ] && [ "$(id -u)" != "0" ]; then
    SUDO="sudo"
fi

if [ "$(which docker)" = "/snap/bin/docker" ]; then
    export TMPDIR="$(readlink -f ~/snap/docker/current)"
	# we need to run the snap once to have $SNAP_USER_DATA created
	/snap/bin/docker >/dev/null 2>&1
fi

BUILDDIR=$(mktemp -d)

usage() {
    echo "usage: $(basename $0) [options]"
    echo
    echo "  -c|--containername <name> (default: snappy)"
    echo "  -i|--imagename <name> (default: snapd)"
    rm_builddir
}

print_info() {
    echo
    echo "to remove the related image use: $SUDO docker rmi $IMGNAME"
}

clean_up() {
    sleep 1
    $SUDO docker rm -f $CONTNAME >/dev/null 2>&1 || true
    $SUDO docker rmi $IMGNAME >/dev/null 2>&1 || true
    $SUDO docker rmi $($SUDO docker images -f "dangling=true" -q) >/dev/null 2>&1 || true
    rm_builddir
}

rm_builddir() {
    rm -rf $BUILDDIR || true
    exit 0
}

trap clean_up 1 2 3 4 9 15

while [ $# -gt 0 ]; do
       case "$1" in
               -c|--containername)
                       [ -n "$2" ] && CONTNAME=$2 shift || usage
                       ;;
               -i|--imagename)
                       [ -n "$2" ] && IMGNAME=$2 shift || usage
                       ;;
               -h|--help)
                       usage
                       ;;
               *)
                       usage
                       ;;
       esac
       shift
done

if [ -n "$($SUDO docker ps -f name=$CONTNAME -q)" ]; then
    echo "Container $CONTNAME already running!"
    print_info
    rm_builddir
fi

if [ -z "$($SUDO docker images|grep $IMGNAME)" ]; then
    cat << EOF > $BUILDDIR/Dockerfile
FROM ubuntu:$RELEASE
ENV container docker
ENV PATH "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin"
ENV LANG C.UTF-8
ENV LC_ALL C.UTF-8
RUN apt-get update &&\
 DEBIAN_FRONTEND=noninteractive\
 apt-get install -y fuse snapd snap-confine squashfuse sudo &&\
 apt-get clean &&\
 dpkg-divert --local --rename --add /sbin/udevadm &&\
 ln -s /bin/true /sbin/udevadm
RUN systemctl enable snapd
VOLUME ["/sys/fs/cgroup"]
STOPSIGNAL SIGRTMIN+3
CMD ["/sbin/init"]
EOF
    $SUDO docker build -t $IMGNAME --force-rm=true --rm=true $BUILDDIR || clean_up
fi

print_info
rm_builddir
