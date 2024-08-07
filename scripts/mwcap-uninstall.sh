#!/bin/sh

LOGFILE=mwcap_install.log

SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd)"
PROCAPTURE_TOP_DIR=$SCRIPT_PATH/..
SRC_DIR=$PROCAPTURE_TOP_DIR/src
MODULE_NAME=ProCapture
MODULE_INSTALL_DIR=/usr/local/share/ProCapture
MODULE_VERSION=1.3.0.4390

echo_string ()
{
    echo "$1" | tee -a $LOGFILE
}

echo_string_nonewline ()
{
    echo -n "$1" | tee -a $LOGFILE
}

NO_REBOOT_PROMPT=""
while getopts "n" flag ; do
   case "$flag" in
      n)NO_REBOOT_PROMPT="YES";;
   esac
done

if [ `id -u` -ne 0 ] ; then
    sudo su -c "$0 $*"
    exit $?
fi

DEPMOD=`which depmod 2>/dev/null`
if [ ! -e "$DEPMOD" ]; then
    echo_string ""
    echo_string "ERROR: Failed to find command: depmod"
    echo_string "   Please install depmod first!"
    echo_string ""
    exit
fi

remove_module ()
{
    KERNEL_VERSION=`uname -r`
    MODULE_PATH=`find /lib/modules/$KERNEL_VERSION -name ${MODULE_NAME}.ko`
    echo_string_nonewline "Removing $MODULE_PATH ... "
    rm -vf $MODULE_PATH >> $LOGFILE 2>&1
    RET=$?
    if [ $RET -ne 0 ] ; then
        echo_string "Remove $MODULE_PATH failed!"
        exit
    fi
    echo_string "Done."

    if [ -e $DEPMOD ] ; then
        echo_string_nonewline "Re-generating modules.dep and map files ... "
        $DEPMOD -a >> $LOGFILE 2>&1
        echo_string "Done."
    fi

    if [ -d /usr/src/${MODULE_NAME}-${MODULE_VERSION} ] || [ -h /usr/src/${MODULE_NAME}_${MODULE_VERSION} ]; then
        dkms remove -m ${MODULE_NAME} -v ${MODULE_VERSION} --all
        rm -vf /usr/src/${MODULE_NAME}_${MODULE_VERSION} >> $LOGFILE 2>&1
    fi

    for binname in `ls $MODULE_INSTALL_DIR/bin`; do
        if [ -h /usr/bin/$binname ]; then
            rm -vf /usr/bin/$binname >> $LOGFILE 2>&1
        fi
    done

    if [ -d $MODULE_INSTALL_DIR ]; then
        echo_string_nonewline "Removing installed files ... "
        rm -vrf $MODULE_INSTALL_DIR >> $LOGFILE 2>&1
        echo_string "Done."
    fi

    if [ -e /usr/bin/mwcap-repair.sh ]; then
        rm -vf /usr/bin/mwcap-repair.sh >> $LOGFILE 2>&1
    fi

    if [ -e /usr/bin/mwcap-uninstall.sh ]; then
        rm -vf /usr/bin/mwcap-uninstall.sh >> $LOGFILE 2>&1
    fi

    if [ -e /etc/udev/rules.d/10-procatpure-event-dev.rules ]; then
        rm -vf /etc/udev/rules.d/10-procatpure-event-dev.rules >> $LOGFILE 2>&1
    fi

    if [ -e /etc/modprobe.d/ProCapture.conf ]; then
        rm -vf /etc/modprobe.d/ProCapture.conf >> $LOGFILE 2>&1
    fi
}

remove_module

MODULE_LOADED=`lsmod | grep ProCapture`
echo_string ""
if [ -z "$MODULE_LOADED" -o x"$NO_REBOOT_PROMPT" = x"YES" ]; then
echo_string "Uninstall Successfully!"
else
    echo_string "Uninstall Successfully!"
    echo_string "!!!!Reboot is needed to unload module!"
    echo_string_nonewline "Do you wish to reboot now (Y/N) [N]: "
    read cont

    if [ "$cont" != "YES" -a "$cont" != "yes" -a \
        "$cont" != "Y" -a "$cont" != "y" ] ; then
        echo_string "Reboot canceled! You should reboot your system manually later."
    else
        reboot
    fi
fi
echo_string ""

