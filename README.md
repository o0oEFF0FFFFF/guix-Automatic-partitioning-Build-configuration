# guix-Automatic-partitioning-Build-configuration
This is a small script that auto-partitions with auto-write grub configuration files.

use$ in next is shell

It is best to use the installation image of GUIX to use
in guix iso shell

use$ guix shell -m run.scm

run a environment to run this script

first to use edit
disk-layout.conf

use$ setup-disk.scm --help

to get help

then

use$ ./setup-disk.sh to start part

if no error 
disk.scm will be creat

and check all the .scm file expect run.scm it is not system config file

then

mount yourself partition on /mnt

you must creatdir need in / mount point
if default disk-layout.conf
use$ sudo mount /dev/... /mnt
use$ mkdir /mnt/boot/efi
use$ mkdir /home
use$ sudo mount /dev/... /mnt/boot/efi
use$ sudo mount /dev/... /mnt/home

then

use$ guix system init /mnt

guix will do everthing！

if want install guix in moveusb,

use$ ./grub_move_install.sh

if in china net slow

look this https://mirrors.sjtug.sjtu.edu.cn/docs/guix
and you can use
guix shell -m run.scm --substitute-urls="https://mirror.sjtu.edu.cn/guix/"
guix system init /mnt --substitute-urls="https://mirror.sjtu.edu.cn/guix/"
