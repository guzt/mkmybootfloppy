#!/bin/bash
# Copyleft 2005 Arjun Asthana. You are allowed to use, modify, distribute,
# sell or even eat this script under the terms of GNU General Public Lisence
# version 2.0, or, at your discretion, later.
#
# coding on ver 0.1 started on Friday - June 11 2004
# and finished on Sunday - June 13 2004
#
# coding for ver 0.2 started on Saturday - Jun 19 2004
# and ended on the next day
# Changes:
# 	You may now include your own application in the floppy
# 	Fs is now writable (ext2 instead of romfs)
# 	Added /dev/random and /dev/urandom
# Fixed a bug which would stop it from booting -> 0.2.1
# Removed a 'Read-only' message which would come when the
#   script has finished and also the requirement for genromfs
#   and fixed zero device -> 0.2.2
# Too many bus fixed and partially tested on RHL 7.2. Too many
#   bugs to mention -> 0.2.3
#
# coding for ver 0.3 started on Tuesday - Jan 07 2005
# and finished on the same day
# Changes:
# 	squashfs is the new fs, which will optimise the speed
# 		and is recommended, although comparatively new.
# 		It is again read-only, but reccomended.
#	Fixed the "Add new application" bug which overwrites
#		the inittab.
#
# C'mon! Send in some bug reports guys! Will I have to all by
# my self? ;-) I'm a lazy bone and dont like to do tough stuff.

# Following is for gnubies
# NOTE: Should you get any error, conact me.
# To patch your kernel and make it good enough for squashfs, do:
# 1) Download squashfs from squashfs.sf.net
# 2) Open a terminal and untar it using
# 	$ tar -xzvf <filename>.tar.gz <OR> <filename>.tgz
#		<OR>
# 	$ tar -xjvf <filename>.tar.bz2
# 3) Then, change to the newly created directory (to know which
# 	directory, the first column in the last line using the /
# 	as the seperator is the directory)
# 4) Run the command:
# 	$ uname -r
# 5) Type `ls' and press enter
# 6) Note the name of the directory matching the closest to the
# 	number you got from `uname -r'. Chose the lower number
# 	if your number is not there.
# 7) Enter that directory using:
# 	$ cd linux-2.X.Y
# 8) Type `pwd' and press enter and note what you got
# 9) Enter the directory where you have the kernel source code
# 	(install it from your distribution's CD if you dont have
# 	any). It usually is /usr/src/linux
# 10) Run the command
# 	$ patch -p1 < <result of step 8>
# 	Dont forget the '<' in the command
# 11) Edit `Makefile' and change `EXTRAVERSION = <something>' to
# 	`EXTRAVERION = <samething><your-name>'
# 12) Run the commands:
# 	$ make mrproper
# 	$ make oldconfig
# 	(go get yourself a coffee)
# 	(Select Squashfs as 'y' or 'm')(if `make xconfig' fails,
# 	run `make menuconfig')
# 	$ make dep
# 	$ make && make bzImage
# 	(go take a nice warm bath)
#	$ make modules
# 	(India is a nice place for a holiday. Got my point?)
# 	$ make modules_install
# 13) Then, copy `arch/i386/boot/bzImage' to /boot as
# 	`bzImageSquashfs'
# 	using:
# 	$ cp arch/i386/boot/bzImage /boot/bzImageSquashfs
# 14) We will also need to create an initrd. Remember the result
# 	of step4? Run:
# 	$ mkinitrd /boot/initrd-squashfs.img <step4result><name from step11>
#
# (SEE NOTE IN STEP 15 FOR AN EASIER, TEMPORARY STEP 15)
# 15) If your bootloader is grub ('e' edits, 'c' commandline,
# 	and all	that shit), edit your /boot/grub/menu.lst and
# 	duplicate the lines that look somewhat like:
# 		title Some thing here
# 		root (hd0,0)
# 	        kernel /boot/vmlinuz-<version> <kernel parameters here>
# 	        initrd /boot/initrd-<same-version>.img
# 	at the end of the paragraph seperating both with a line
# 	feed/carriage return/enter. You might not need to do
# 	anything if the file contains the term "automagic
# 	kernels". You *might*.
# 	Then edit the `kernel' line and make it look like this:
# 		kernel /boot/bzImageSquashfs <original kernel parameters here>
# 	It could even be /bzImageSquashfs if your /boot is on a
# 	seperate partition. Look at the original in your config
# 	file and see what it is. Append Squashfs to the title.
# 	If there are many lines, look for something like
# 	'default <num>'
# 	It specifies the entry number to duplicate.
#
# 	NOTE: If this seems difficult, when your system boots
# 	and you get the splash screen asking you to select a
# 	kernel, press 'e'. Select the `kernel *' line and press
# 	`e' and change `vmlinuz<whatever>' to
# 	`vmlinuz<whatever><the name you gave in step 11>' and
# 	press enter. Then, select the line `initrd <whatever>'
# 	and change it to `initrd <whatever><your name from step 11>'
# 	 Press `enter' followed by `b'.
#
# 16) LILO users (the most probably all others), just edit your
# 	/etc/lilo.conf and duplicate the paragraph which
# 	contains `label = <whatever>" and all that. In the first
# 	few lines of your file,	you'll see the `default = "
# 	entry. That names the entry to be duplicated. Change
# 	from vmlinuz* from `image = ' section to bzImageSquashfs
# 	and change the label to squash_linux And try to make a
# 	change from LILO to GRUB.
# 17) Go to the squashfs-tools directory in the squashfs
# 	directory. Type `make' and press enter. When it is done,
# 	run:
# 	$ cp mksquashfs /usr/bin

initialdir=`pwd`
inst-fail() {
	echo Installation failed
	exit $1
}

if ! [ $USER = root ]; then
	echo You have to be root to use mknod '('used for
	echo making devices')' and many other things. \`su\'
	echo wont work. You need to use \`su -\'.
	exit 6
fi
	

cat << -EOF- | more
Welcome to mkmybootfloppy!
-=-=-=-=-=-=-=-=-=-=-=-=-=
This is a script which will help you make a boot floppy.
The boot floppy will be based on busybox (a swiss army knife
software which has 200+ GNU utilities replacement executables).
The prerequisites are:
(1) busybox static build (or source)
    NOTE: You will have some problems with the pre-compiled
    binary. Using the source-code is recommended.
(2) linux kernel compiled without modules and with squashfs
    support (optional) ~1/2MB (or source)
(3) syslinux, which is, usually present on RedHat & Debian
(4) mknod and makedevs (latter in busybox)
(5) squashfs patch (skip if already in the pre-compiled kernel)
    and utilities that come with it (squashfs is optional but
    highly recommended)
    NOTE: To use squashfs, you will have to compile your running
    kernel with squashfs patch and have installed the utilities 
    so that we can create a squashfs. I recommend you take the
    trouble to do so if you want a decent boot floppy. Though it
    is highly reccommended, this script does not patch or compile
    your running kernel as that would require changing the boot
    loader which is beyond the scope of this script. View the
    script using an editor and check the comments on how to do so.

Hit CTRL-C any time to exit this script.
If you come accross any problems, essppeelinng meestakess, have
any sugesstions, criticisms or just want to know how I am, mail me at: "Arjun Asthana" <arjunasthana@gmx.net>

Please, please, PPPLLLEEEAAASSSEEE help me fix this script. I
know it has tons of problems. You just have to report them. I
wont kill you for sending bug reports! I wont murder you! I'll not even shout at you even if the report is false! I'll just be
thankful to you for taking the trouble of sending bug reports.
-EOF-

echo Please make sure your capslock is not on.

dobusybox() {
echo -n Do you have busybox \(or source\)\? \(y\/n\)\ 
read -n 1 bbyn
if ! [ $bbyn = y ]; then
	echo You need busybox for this.
	echo get it from busybox.net.
	exit 1
fi

echo
echo -n Is it Source, pre-Compiled, Packaged'(rpm,deb,slack-tgz)' or on Apt-get\? '(s/c/p/a) (if you dont make it from source, you are going to have problems later, and if you dont install it from packages, you will have to compile everything again that uses busybox. Oh! I forgot that this was only for libraries. You can safely install from source since this is not a lib) '
read -n 1 bbscpa

echo
echo Where is the source\/binary package\? Give the full path or just the package name if it is in your home dir. Leave this if you answered c or a.\ 
read pack

cd
[ $pack ] && cd `dirname $pack`

case $bbscpa in
s)	case $pack in
		*bz2) alias tarc="tar -xjvf" ;;
		*gz)  alias tarc="tar -xzvf" ;;
	esac

	if ! [ -e $pack ]; then echo $pack does not exist; exit 1; fi

	tarc `basename $pack` | tee /tmp/bbpack.$$
	cd `head -n 1 /tmp/bbpack.$$`

	cat << EOM
The Buffer allocation policy should be "Allocate in the .bss section"
(in General configuration) and the build should be static (in build
options)
EOM
	read

	make menuconfig || make config
	confexit=$?

	[ $confexit = 0 ] && make ; makeexit=$?

	if ! [ $confexit = 0 ];then
		echo
		echo You don\'t have the things required for busybox.
		exit 1
	elif ! [ $makeexit = 0 ]; then
		echo
		echo You don\'t have the things required for busybox.
		exit 1
	fi

	bbbin2=`pwd`/busybox
;;

c)	echo
	echo Where is the compiled binary? Leave blank if it is in your path. No trailing \/ at the end please.
	read bbbin

	if [ -z $bbbin ]; then
		if ! [ -x `which busybox` ];then
			echo
			echo "Busybox isn't in your path"
			exit 1
		fi
		bbbin2=`which busybox`
	else
		if ! [ -x "$bbbin"/busybox ]; then
			echo
			echo "Busybox isn't there"
			exit 1
		fi
		bbbin2="$bbbin"/busybox
	fi
;;

p)	if ! [ -e $pack ]; then
		echo
		echo The package does not exist
		exit 1
	fi

	case $pack in
		*rpm)	alias packrc="rpm -ivh";;
		*deb)	alias packrc="deb -i";;
		*)	echo Which command\+argument installs this package\? eg. rpm -i or rpm -ivh or deb -i or installpkg. These are only examples, not choices.
			read packrc
			;;
	esac

	packrc $pack ; packrcexit=$?

	if ! [ $packrcexit = 0 ]; then
		echo
		echo Package installation failed
		exit 1
	fi

	if ! [ -x `which busybox` ]; then
		echo Busybox executable not found
		exit 1
	fi

	bbbin2=`which busybox`
;;
a)	if ! [ -x `which apt-get` ]; then
		echo You dont have apt-get
		exit 1
	fi

	apt-get update && apt-get install busybox || inst-fail 1

	if ! [ -x `which busybox` ]; then
		echo Busybox not found
		inst-fail 1
	fi

	bbbin2=`which busybox`
;;
*)	echo Please enter a valid choice
	dobusybox
;;
esac
}

dokernel() {
echo 'Do you have kernel Source or pre-Compiled kernel (without modules, which means your existing kernel wont work)? (s/p) You are strongly recommended to compile from source unless you have already done so using this script.'
read -n 1 kernelsp

echo 'Do you want to use squashfs? To use squashfs, I assume that you have already patched and re-compiled your _current_ kernel (not the one to be used in the floppy) because we will need to make a filesystem using squashfs. And I also assume that the sources of both the kernels are in the same directory and you have already installed the tools. So, I wont patch it. Please see the comments in this file for more information.'
read -n 1 squashfsyn

case $kernelsp in
s)	echo Where is the kernel? Leave blank for the default /usr/src/linux. NO trailing \/ please. And dont use /usr/src/linux unless it was already installed by your distribution or by the kernel src rpm in the installation CD of your distro.
	read kernelloc

	if ! [ $kernelloc ]; then
		kernelloc=/usr/src/linux
	fi
	if ! [ -e $kernelloc ]; then
		echo $kernelloc does not exist
		exit 2
	fi

	cd $kernelloc

	cat << -EOM-
	This is very important for making the kernel for the
	floppy. You *MUST* disable modules and you *MUST* include
	the following things in the kernel or the floppy will not
	work:
	* RAM disk support, in the Block Devices menu
	* Initial RAM disk 'initrd' support, also in the Block
	  Devices menu
-EOM-
	  
[ $squashfsyn = y ] && echo '	* Squashed filesystem, in Miscellaneous filesystems
	  under File systems menu'

	cat << -EOM-
	Write these things down somewhere so that you dont
	forget them.
-EOM-

	read

	make xconfig || make menuconfig || make config || inst-fail 2

	make dep
	kerneldepexit=$?
	if ! [ $kerneldepexit = 0 ]; then
		echo Dependencies could not be sorted out
		inst-fail 2
	fi

	make bzImage
	kernelimageexit=$?
	if ! [ $kernelimageexit = 0 ]; then
		echo Kernel image could not be made
		inst-fail 2
	fi

	kernelimg=`pwd`/arch/i386/boot/bzImage
;;
p)	echo Where is the kernel\? Your existing kernel will not work for this floppy
	read kernelwhereis

	if ! [ -e $kernelwhereis ]; then
		echo $kernelwhereis does not exist
		exit 2
	else
		kernelimg=$kernelwhereis
	fi
;;
*)	echo Please enter a valid choice
	dokernel
esac
}

blahfailed() {
echo Sorry, it failed. Exiting
exit 10 
}

dobusybox && dokernel || blahfailed

if ! [ -x `which syslinux` ]; then
	echo You dont have syslinux. It is used
	echo for booting into linux from dos fs
	echo formatted floppies. Google for it\'s
	echo download location
	echo \'
	exit 4
fi

if ! [ -x `which mknod` ]; then
	echo You need mknod for making the devices
	exit 5
fi

cd
echo Where would you like to store the temporary
echo files for the floppy\? The files are not so
echo temporary that they are stored in /tmp. No
echo trailing \/ please. Enter the full path
echo starting from \/
read floppytmp

if ! [ -d $floppytmp ]; then
	echo Creating $floppytmp
	mkdir $floppytmp
fi

cd $floppytmp
echo Creating directory mybootlinux
mkdir mybootlinux

echo cd\'ing into it
cd mybootlinux

echo Creating normal linux directories
mkdir dev etc etc/init.d bin proc mnt tmp var var/shm
chmod 755 . dev etc etc/init.d bin proc mnt tmp var var/shm

echo cd\'ing into dev dir and making the devices
cd dev

echo Creating hda'(1-8)'
$bbbin2 makedevs hda b 3 0 0 8 s

echo Creating hdb'(1-8)'
$bbbin2 makedevs hdb b 3 64 0 8 s

echo Creating tty'(1-8)'
mknod tty c 5 0
$bbbin2 makedevs tty c 4 1 1 8

echo Creating console
mknod console c 5 1

echo Creating ram device
mknod ram0 b 1 0

echo Creating null device
mknod null c 1 3

echo Creating zero device
mknod zero c 1 5

echo Creating random thingies
mknod random c 1 8
mknod urandom c 1 9

echo Setting permissions
chmod 666 *

echo Making startup scripts and blah, blah, blah....
cd ../etc/init.d
cat << EOF > rcS
#!/bin/sh
mount -a
EOF
chmod 744 rcS

cd ..
cat << EOT > fstab
proc  /proc      proc    defaults     0      0
none  /var/shm   shm     defaults     0      0
EOT
chmod 644 fstab

echo Would you like to include your own application in this?
read -n 1 incappyn
if [ $incappyn = y ]; then
	echo Please type in the full path to the app.
	echo Please note that many things have to fit
	echo on a single floppy. The app should be small
	read apploc
	if [ -e $apploc ]; then
		cp $apploc ..
		chmod 755 ../`basename $apploc`
		echo Done
		echo Making modified inittab to include your app
		echo '::sysinit:/etc/init.d/rcS' > inittab
		echo '::askfirst:/'`basename $apploc` >> inittab
	else
		echo $apploc does not exist
		cat << EOB > inittab
::sysinit:/etc/init.d/rcS
::askfirst:/bin/sh
EOB
	fi
else
	cat << EOB > inittab
::sysinit:/etc/init.d/rcS
::askfirst:/bin/sh
EOB
fi
chmod 644 inittab

echo Making mount directories
cd ../dev
for i in hd*
do
	mkdir ../mnt/"$i"
done

echo Copying busybox
cd ../bin
cp $bbbin2 ./busybox 
sleep 2
cd ..
cd "$floppytmp"/mybootlinux

floppyfail() {
echo Could not make floppy
echo Last process returned exit code $1
exit 10
}

cd "$floppytmp"
if ! [ $squashfsyn = y ] ; then
	echo Making filesystem
	dd if=/dev/zero of=floppyfs bs=1k count=4000 || floppyfail $?
	echo Making ext2 fs
	mkfs.ext2 -F -i 2000 floppyfs || floppyfail $?
	mkdir loop
        echo Connecting loop filesystem
        losetup /dev/loop0 "$floppytmp"/floppyfs
	echo Mounting filesystem
	mount -o loop floppyfs loop/ || floppyfail $?
	echo Copying files to the fs
	cp -R mybootlinux/* loop/ || floppyfail $?
else
	echo Making squashfs filesystem
	mkquashfs "$floppytmp"/mybootlinux "$floppytmp"/floppyfs || floppyfail $?
	echo Connecting loop filesystem
	losetup /dev/loop0 "$floppytmp"/floppyfs	
	echo Mounting filesystem
        mount -o loop floppyfs loop/ || floppyfail $?
fi



cd loop
echo Now comes the tough part - making links to
echo 200+ executables. If you installed it from
echo -e source, this is easy since it provides a \\n script.

if ! [ $bbscpa = s ]; then
	echo Is the version of your busybox later than 1.0pre1?
	read -n 1 veryn
	if [ $veryn = y ]; then
		cat << EOF > /tmp/bblinks
usr/bin/[
bin/addgroup
bin/adduser
sbin/adjtimex
usr/bin/arping
bin/ash
usr/bin/awk
usr/bin/basename
usr/bin/bunzip2
usr/bin/bzcat
usr/bin/cal
bin/cat
bin/chgrp
bin/chmod
bin/chown
usr/sbin/chroot
usr/bin/chvt
usr/bin/clear
usr/bin/cmp
bin/cp
bin/cpio
usr/sbin/crond
usr/bin/crontab
usr/bin/cut
bin/date
usr/bin/dc
bin/dd
usr/bin/deallocvt
bin/delgroup
bin/deluser
sbin/devfsd
bin/df
usr/bin/dirname
bin/dmesg
usr/bin/dos2unix
usr/bin/dpkg
usr/bin/dpkg-deb
usr/bin/du
bin/dumpkmap
usr/bin/dumpleases
bin/echo
bin/egrep
usr/bin/env
usr/bin/expr
bin/false
usr/sbin/fbset
bin/fdflush
usr/bin/fdformat
sbin/fdisk
bin/fgrep
usr/bin/find
usr/bin/fold
usr/bin/free
sbin/freeramdisk
sbin/fsck.minix
usr/bin/ftpget
usr/bin/ftpput
bin/getopt
sbin/getty
bin/grep
bin/gunzip
bin/gzip
sbin/halt
sbin/hdparm
usr/bin/head
usr/bin/hexdump
usr/bin/hostid
bin/hostname
usr/sbin/httpd
bin/hush
sbin/hwclock
usr/bin/id
sbin/ifconfig
sbin/ifdown
sbin/ifup
usr/sbin/inetd
sbin/init
sbin/insmod
usr/bin/install
bin/ip
bin/ipaddr
bin/ipcalc
bin/iplink
bin/iproute
bin/iptunnel
bin/kill
usr/bin/killall
sbin/klogd
bin/lash
usr/bin/last
usr/bin/length
linuxrc
bin/ln
usr/bin/loadfont
sbin/loadkmap
usr/bin/logger
bin/login
usr/bin/logname
sbin/logread
sbin/losetup
bin/ls
sbin/lsmod
sbin/makedevs
usr/bin/md5sum
usr/bin/mesg
bin/mkdir
usr/bin/mkfifo
sbin/mkfs.minix
bin/mknod
sbin/mkswap
bin/mktemp
sbin/modprobe
bin/more
bin/mount
bin/msh
bin/mv
sbin/nameif
usr/bin/nc
bin/netstat
usr/bin/nslookup
usr/bin/od
usr/bin/openvt
usr/bin/passwd
usr/bin/patch
bin/pidof
bin/ping
bin/ping6
bin/pipe_progress
sbin/pivot_root
sbin/poweroff
usr/bin/printf
bin/ps
bin/pwd
usr/sbin/rdate
usr/bin/readlink
usr/bin/realpath
sbin/reboot
usr/bin/renice
usr/bin/reset
bin/rm
bin/rmdir
sbin/rmmod
sbin/route
bin/rpm
usr/bin/rpm2cpio
bin/run-parts
bin/sed
usr/bin/seq
usr/bin/setkeycodes
bin/sh
bin/sleep
usr/bin/sort
sbin/start-stop-daemon
usr/bin/strings
bin/stty
bin/su
sbin/sulogin
sbin/swapoff
sbin/swapon
bin/sync
sbin/sysctl
bin/syslogd
usr/bin/tail
bin/tar
usr/bin/tee
usr/bin/telnet
usr/sbin/telnetd
usr/bin/test
usr/bin/tftp
usr/bin/time
usr/bin/top
bin/touch
usr/bin/tr
usr/bin/traceroute
bin/true
usr/bin/tty
sbin/udhcpc
usr/sbin/udhcpd
bin/umount
bin/uname
bin/uncompress
usr/bin/uniq
usr/bin/unix2dos
usr/bin/unzip
usr/bin/uptime
bin/usleep
usr/bin/uudecode
usr/bin/uuencode
sbin/vconfig
bin/vi
usr/bin/vlock
bin/watch
sbin/watchdog
usr/bin/wc
usr/bin/wget
usr/bin/which
usr/bin/who
usr/bin/whoami
usr/bin/xargs
usr/bin/yes
bin/zcat
EOF
		for i in `cat /tmp/bblinks`
		do
			mkdir -p `dirname $i`
			ln bin/busybox $i
		done
		echo Done making links
	else
		echo Hoping that busybox was compiled as a
		echo '"'standalone shell'"'
		echo Or, can you point me to a downloaded or
		echo some other busybox.links file '('usually
		echo found in the busybox source dir')'? '(y/n)'
		read -n 1 bblinksyn
		if [ $bblinksyn = y ]; then
			echo Where is it?
			read bblinksloc
			if ! [ -e $bblinksloc ]; then
				echo Sorry\, this doesnt exist. Best of luck
				echo Making link to '/bin/sh' and /sbin/init
				ln bin/busybox bin/sh
				ln bin/busybox sbin/init
			else
				echo Making links
				for i in `cat $bblinksloc`
				do
					case $i in
					\/*) ln bin/busybox ."$i";;
					*) ln bin/busybox "$i" ;;
					esac
				done
			fi
		else
			echo Making a link to \'bin/sh\' for the shell
			ln bin/busybox bin/sh
			echo Making link to /sbin/init for init
			ln bin/busybox sbin/init
		fi
	fi

else
	echo cd\'ing into bubusybox source dir and making links \'
	cd `dirname $bbbin2`
	make PREFIX="$floppytmp"/mybootlinux install
	linksexit=$?
	if ! [ $linksexit = 0 ]; then
		echo Link making failed
		exit 10
	else
		echo Link making succeeded
	fi
fi                                    

cd "$floppytmp"
if ! [ $squashfsyn = y ] ; then
        echo Making filesystem
        dd if=/dev/zero of=floppyfs bs=1k count=4000 || floppyfail $?
        echo Making ext2 fs
        mkfs.ext2 -F -i 2000 floppyfs || floppyfail $?
        mkdir loop
        echo Connecting loop filesystem
        losetup /dev/loop0 "$floppytmp"/floppyfs
	echo Mounting filesystem
	mount -o loop floppyfs loop/ || floppyfail $?
	echo Copying files to the fs
	cp -R mybootlinux/* loop/ || floppyfail $?
	echo Unmounting fs
	umount loop/ || floppyfail $?
	echo Disconnecting loopfile
	losetup -d /dev/loop0 || floppyfail $?
	echo Compressing it
	gzip -9 floppyfs
	mv -f floppyfs.gz floppyfs
else            
	echo Making squashfs filesystem
	mkquashfs "$floppytmp"/mybootlinux "$floppytmp"/floppyfs || floppyfail $?
fi

echo Please insert a floppy into drive /dev/fd0 but
echo DONT mount it
read

echo Last chance to quit before destroying any data
echo 'on /dev/fd0 (CTRL-C to quit)'
read

echo Formatting floppy
mformat /dev/fd0 || floppyfail $?
echo Inserting syslinux bootloader
syslinux /dev/fd0 || floppyfail $?
mkdir /mnt/mybootlinux
echo Mounting floppy
mount -t msdos /dev/fd0 /mnt/mybootlinux || floppyfail $?
echo Copying fs
cd floppyfs /mnt/mybootlinux || floppyfail $?
echo Copying kernel
cp $kernelimg /mnt/mybootlinux/linux || floppyfail $?
cd /mnt/mybootlinux
echo Creating syslinux config
cat << EOF > syslinux.cfg
TIMEOUT 20
DEFAULT linux

LABEL linux
    KERNEL linux
    APPEND root=/dev/ram0 initrd=floppyfs
EOF
umount /mnt/mybootfloppy

echo Congrats\! Your boot floppy has been written\!
echo
echo Would you like to save an image of this floppy
echo to a file on your hd\?
read -n 1 imgyn
if [ $imgyn = y ]; then
	echo Where would you like to store it\?
	read imgloc
	echo Running dd. It might take some time
	dd if=/dev/fd0 of=$imgloc
	echo You can use \`dd if="$imgloc" of=/dev/fd0"'"
	echo if you want to make another copy of this
	echo on another floppy
fi

cd $initialdir
