#!/bin/bash

set -e
set -x

mkdir -p ~/softether && cd ~/softether

BASE=`pwd`
SRC=$BASE/src
WGET="wget --prefer-family=IPv4"
DEST=$BASE/opt
LDFLAGS="-L$DEST/lib"
CPPFLAGS="-I$DEST/include"
CFLAGS="-march=armv7-a -mtune=cortex-a9"
CXXFLAGS=$CFLAGS
CONFIGURE="./configure --prefix=/opt --host=arm-linux"
MAKE="make -j`nproc`"

mkdir -p $SRC

######## ####################################################################
# ZLIB # ####################################################################
######## ####################################################################

mkdir -p $SRC/zlib && cd $SRC/zlib
$WGET http://zlib.net/zlib-1.2.9.tar.gz
tar zxvf zlib-1.2.9.tar.gz
cd zlib-1.2.9

LDFLAGS=$LDFLAGS \
CPPFLAGS=$CPPFLAGS \
CFLAGS=$CFLAGS \
CXXFLAGS=$CXXFLAGS \
CROSS_PREFIX=arm-linux-gnueabi- \
./configure \
--prefix=/opt \
--static

$MAKE
make install DESTDIR=$BASE

########### #################################################################
# OPENSSL # #################################################################
########### #################################################################

mkdir -p $SRC/openssl && cd $SRC/openssl
$WGET https://www.openssl.org/source/openssl-1.0.2j.tar.gz
tar zxvf openssl-1.0.2j.tar.gz
cd openssl-1.0.2j

./Configure linux-armv4 -march=armv7-a -mtune=cortex-a9 \
--prefix=/opt zlib \
--with-zlib-lib=$DEST/lib \
--with-zlib-include=$DEST/include

make CC=arm-linux-gnueabi-gcc
make CC=arm-linux-gnueabi-gcc install INSTALLTOP=$DEST OPENSSLDIR=$DEST/ssl

########### #################################################################
# NCURSES # #################################################################
########### #################################################################

mkdir -p $SRC/curses && cd $SRC/curses
$WGET http://ftp.gnu.org/gnu/ncurses/ncurses-6.0.tar.gz
tar zxvf ncurses-6.0.tar.gz
cd ncurses-6.0

export TARGETMACH=arm-linux-gnueabi
export CROSS=arm-linux-gnueabi
export CC=${CROSS}-gcc
export LD=${CROSS}-ld
export AS=${CROSS}-as

LDFLAGS=$LDFLAGS \
CPPFLAGS="-P $CPPFLAGS" \
CFLAGS=$CFLAGS \
CXXFLAGS=$CXXFLAGS \
$CONFIGURE \
--enable-widec \
--enable-overwrite \
--with-normal \
--with-shared \
--enable-rpath \
--with-fallbacks=xterm

$MAKE
make install DESTDIR=$BASE

############### #############################################################
# LIBREADLINE # #############################################################
############### #############################################################

mkdir -p $SRC/libreadline && cd $SRC/libreadline
$WGET http://ftp.gnu.org/gnu/readline/readline-6.3.tar.gz
tar zxvf readline-6.3.tar.gz
cd readline-6.3

$WGET https://raw.githubusercontent.com/johnnyslt/SoftEtherVPN-arm-static/master/patches/readline.patch
patch < readline.patch

LDFLAGS=$LDFLAGS \
CPPFLAGS=$CPPFLAGS \
CFLAGS=$CFLAGS \
CXXFLAGS=$CXXFLAGS \
$CONFIGURE \
--disable-shared \
bash_cv_wcwidth_broken=no \
bash_cv_func_sigsetjmp=yes

$MAKE
make install DESTDIR=$BASE

############ ################################################################
# LIBICONV # ################################################################
############ ################################################################

mkdir -p $SRC/libiconv && cd $SRC/libiconv
$WGET http://ftp.gnu.org/pub/gnu/libiconv/libiconv-1.14.tar.gz
tar zxvf libiconv-1.14.tar.gz
cd libiconv-1.14

$WGET https://raw.githubusercontent.com/johnnyslt/SoftEtherVPN-arm-static/master/patches/libiconv.patch

patch srclib/stdio.in.h < libiconv.patch

LDFLAGS=$LDFLAGS \
CPPFLAGS=$CPPFLAGS \
CFLAGS=$CFLAGS \
CXXFLAGS=$CXXFLAGS \
$CONFIGURE \
--enable-static \
--disable-shared

$MAKE
make install DESTDIR=$BASE

unset TARGETMACH
unset CROSS
unset CC
unset LD
unset AS

############# ###############################################################
# SOFTETHER # ###############################################################
############# ###############################################################

mkdir -p $SRC/softether && cd $SRC/softether
git clone https://github.com/SoftEtherVPN/SoftEtherVPN.git

cd SoftEtherVPN
#git checkout c0c1b914db8d27fa2f60fb88ee45b032b881aa28
cd ..

cp -rfv SoftEtherVPN SoftEtherVPN_host
cd SoftEtherVPN_host

if [ "`uname -m`" == "x86_64" ];then
	cp ./src/makefiles/linux_64bit.mak ./Makefile
else
	cp ./src/makefiles/linux_32bit.mak ./Makefile
fi

$MAKE

cd ../SoftEtherVPN

$WGET https://raw.githubusercontent.com/johnnyslt/SoftEtherVPN-arm-static/master/patches/100-ccldflags.patch
$WGET https://raw.githubusercontent.com/johnnyslt/SoftEtherVPN-arm-static/master/patches/iconv.patch
patch -p1 < 100-ccldflags.patch
patch -p1 < iconv.patch

cp ./src/makefiles/linux_32bit.mak ./Makefile
sed -i 's,#CC=gcc,CC=arm-linux-gnueabi-gcc,g' Makefile
sed -i 's,-lncurses -lz,-lncursesw -lz -liconv -ldl,g' Makefile
sed -i 's,ranlib,arm-linux-gnueabi-ranlib,g' Makefile

CCFLAGS="$CPPFLAGS $CFLAGS" \
LDFLAGS="-static $LDFLAGS" \
$MAKE \
|| true

cp ../SoftEtherVPN_host/tmp/hamcorebuilder ./tmp/

CCFLAGS="$CPPFLAGS $CFLAGS" \
LDFLAGS="-static $LDFLAGS" \
$MAKE
