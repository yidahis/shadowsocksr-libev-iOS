#!/bin/sh

make distclean

CONFIGURE_FLAGS="--disable-shared --disable-frontend"

ARCHS="arm64 armv7s x86_64 i386 armv7"

# directories
# SOURCE是下载的第三方库源码包，解压后的目录，可以把sh脚本放到这个目录，source改为""
SOURCE=""
# FAT是所有指令集build后，输出的目录，所有静态库被合并成一个静态库
FAT="fat-libtool"

# SCRATCH是下载源码包，解压后的目录
SCRATCH="./"
# must be an absolute path
# THIN 各自指令集build后输出的静态库所在的目录，每个指令集为一个静态库
THIN=`pwd`/"thin-libtool"

COMPILE="y"
LIPO="y"

if [ "$*" ]
then
if [ "$*" = "lipo" ]
then
# skip compile
COMPILE=
else
ARCHS="$*"
if [ $# -eq 1 ]
then
# skip lipo
LIPO=
fi
fi
fi

if [ "$COMPILE" ]
then
CWD=`pwd`
echo "$CWD/$SOURCE........."
for ARCH in $ARCHS
do
echo "building $ARCH..."
mkdir -p "$SCRATCH/$ARCH"
cd "$SCRATCH/$ARCH"

if [ "$ARCH" = "i386" -o "$ARCH" = "x86_64" ]
then
PLATFORM="iPhoneSimulator"
if [ "$ARCH" = "x86_64" ]
then
SIMULATOR="-mios-simulator-version-min=7.0"
HOST=x86_64-apple-darwin
else
SIMULATOR="-mios-simulator-version-min=5.0"
HOST=i386-apple-darwin
fi
else
PLATFORM="iPhoneOS"
SIMULATOR=
HOST=arm-apple-darwin
fi

XCRUN_SDK=`echo $PLATFORM | tr '[:upper:]' '[:lower:]'`
CC="xcrun -sdk $XCRUN_SDK clang -arch $ARCH"
#AS="$CWD/$SOURCE/extras/gas-preprocessor.pl $CC"
CFLAGS="-arch $ARCH $SIMULATOR"
CXXFLAGS="$CFLAGS"
LDFLAGS="$CFLAGS"

CC=$CC $CWD/$SOURCE/configure \
$CONFIGURE_FLAGS \
--host=$HOST \
--prefix="$THIN/$ARCH" \
CC="$CC" CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS"

make -j3 install
cd $CWD
done
fi

if [ "$LIPO" ]
then
echo "building fat binaries..."
mkdir -p $FAT/lib
set - $ARCHS
CWD=`pwd`
cd $THIN/$1/lib
for LIB in *.a
do
cd $CWD
lipo -create `find $THIN -name $LIB` -output $FAT/lib/$LIB
done

cd $CWD
cp -rf $THIN/$1/include $FAT
fi
