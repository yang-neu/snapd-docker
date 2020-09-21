#! /bin/sh
#
# make sure to have docker installed before running this script!
# (tested with the docker.io deb and the docker snap package under
# ubuntu 16.04)
#

set -e

CONTNAME=snappy_w_port
IMGNAME=snapd
RELEASE=18.04

SUDO=""
if [ -z "$(id -Gn|grep docker)" ] && [ "$(id -u)" != "0" ]; then
    SUDO="sudo"
fi

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


# start the detached container
$SUDO docker run \
    --name=$CONTNAME \
    -ti \
    -p 80:80 \
    -p 1080:1080 \
    -p 443:443 \
    --tmpfs /run \
    --tmpfs /run/lock \
    --tmpfs /tmp \
    --cap-add SYS_ADMIN \
    --device=/dev/fuse \
    --security-opt apparmor:unconfined \
    --security-opt seccomp:unconfined \
    -v /sys/fs/cgroup:/sys/fs/cgroup:ro \
    -v /lib/modules:/lib/modules:ro \
    -d $IMGNAME || clean_up

# wait for snapd to start
TIMEOUT=100
SLEEP=0.1
echo -n "Waiting up to $(($TIMEOUT/10)) seconds for snapd startup "
while [ "$($SUDO docker exec $CONTNAME sh -c 'systemctl status snapd.seeded >/dev/null 2>&1; echo $?')" != "0" ]; do
    echo -n "."
    sleep $SLEEP || clean_up
    if [ "$TIMEOUT" -le "0" ]; then
        echo " Timed out!"
        clean_up
    fi
    TIMEOUT=$(($TIMEOUT-1))
done
echo " done"

$SUDO docker exec $CONTNAME snap install core --edge || clean_up
echo "container $CONTNAME started ..."

