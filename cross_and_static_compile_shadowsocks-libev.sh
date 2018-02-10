#!/bin/sh

# cross & static compile shadowsocks-libev

PCRE_VER=8.41
PCRE_FILE="http://ftp.csx.cam.ac.uk/pub/software/programming/pcre/pcre-$PCRE_VER.tar.gz"

MBEDTLS_VER=2.6.0
MBEDTLS_FILE="https://tls.mbed.org/download/mbedtls-$MBEDTLS_VER-gpl.tgz"

LIBSODIUM_VER=1.0.15
LIBSODIUM_FILE="https://download.libsodium.org/libsodium/releases/libsodium-$LIBSODIUM_VER.tar.gz"

LIBEV_VER=4.24
LIBEV_FILE="http://dist.schmorp.de/libev/libev-$LIBEV_VER.tar.gz"

LIBC_ARES_VER=1.13.0
LIBC_ARES_FILE="https://c-ares.haxx.se/download/c-ares-$LIBC_ARES_VER.tar.gz"

SHADOWSOCKS_LIBEV_VER=3.1.0
SHADOWSOCKS_LIBEV_FILE="https://github.com/shadowsocks/shadowsocks-libev"

SIMPLE_OBFS_VER=0.0.4
SIMPLE_OBFS_FILE="https://github.com/shadowsocks/simple-obfs"

cur_dir=$(pwd)

prepare() {
    rm -rf $cur_dir/build && mkdir $cur_dir/build
}

compile_pcre() {
    [ -d $prefix/pcre ] && return

    cd $cur_dir/build
    wget --no-check-certificate $PCRE_FILE
    tar xvf pcre-$PCRE_VER.tar.gz
    cd pcre-$PCRE_VER
    CPPFLAGS="-DNEED_PRINTF" ./configure --prefix=$prefix/pcre --host=$host --enable-jit --enable-utf8 --enable-unicode-properties --disable-shared
    make -j$(getconf _NPROCESSORS_ONLN) && make install
}

compile_mbedtls() {
    [ -d $prefix/mbedtls ] && return

    cd $cur_dir/build
    wget --no-check-certificate $MBEDTLS_FILE
    tar xvf mbedtls-$MBEDTLS_VER-gpl.tgz
    cd mbedtls-$MBEDTLS_VER
    prefix_reg=$(echo $prefix | sed "s/\//\\\\\//g")
    sed -i "s/DESTDIR=\/usr\/local/DESTDIR=$prefix_reg\/mbedtls/g" Makefile
    [ -z $host ] && make install -j$(getconf _NPROCESSORS_ONLN) || CC=$host-gcc AR=$host-ar LD=$host-ld make install -j$(getconf _NPROCESSORS_ONLN)
}

compile_libsodium() {
    [ -d $prefix/libsodium ] && return

    cd $cur_dir/build
    wget --no-check-certificate $LIBSODIUM_FILE
    tar xvf libsodium-$LIBSODIUM_VER.tar.gz
    cd libsodium-$LIBSODIUM_VER
    ./configure --prefix=$prefix/libsodium --host=$host --disable-ssp --disable-shared
    make -j$(getconf _NPROCESSORS_ONLN) && make install
}

compile_libev() {
    [ -d $prefix/libev ] && return

    cd $cur_dir/build
    wget --no-check-certificate $LIBEV_FILE
    tar xvf libev-$LIBEV_VER.tar.gz
    cd libev-$LIBEV_VER
    ./configure --prefix=$prefix/libev --host=$host --disable-shared
    make -j$(getconf _NPROCESSORS_ONLN) && make install
}

compile_libc_ares() {
    [ -d $prefix/libc-ares ] && return

    cd $cur_dir/build
    wget --no-check-certificate $LIBC_ARES_FILE
    tar xvf c-ares-$LIBC_ARES_VER.tar.gz
    cd c-ares-$LIBC_ARES_VER
    ./configure --prefix=$prefix/libc-ares --host=$host --disable-shared
    make -j$(getconf _NPROCESSORS_ONLN) && make install
}

compile_shadowsocks_libev() {
    [ -f $prefix/shadowsocks-libev/bin/ss-local ] && return

    cd $cur_dir/build
    git clone --branch v$SHADOWSOCKS_LIBEV_VER --single-branch --depth 1 $SHADOWSOCKS_LIBEV_FILE
    cd shadowsocks-libev
    git submodule update --init --recursive
    ./autogen.sh
    LIBS="-lpthread -lm" LDFLAGS="-Wl,-static -static-libgcc -L$prefix/libc-ares/lib -L$prefix/libev/lib" CFLAGS="-I$prefix/libc-ares/include -I$prefix/libev/include" ./configure --prefix=$prefix/shadowsocks-libev --host=$host --disable-ssp --disable-documentation --with-mbedtls=$prefix/mbedtls --with-pcre=$prefix/pcre --with-sodium=$prefix/libsodium
    make -j$(getconf _NPROCESSORS_ONLN) && make install
}

compile_simple_obfs() {
    [ -f $prefix/shadowsocks-libev/bin/obfs-local ] && return

    cd $cur_dir/build
    git clone --branch v$SIMPLE_OBFS_VER --single-branch --depth 1 $SIMPLE_OBFS_FILE
    cd simple-obfs
    git submodule update --init --recursive
    ./autogen.sh
    LIBS="-lpthread -lm" LDFLAGS="-Wl,-static -static-libgcc -L$prefix/libc-ares/lib -L$prefix/libev/lib -L$prefix/libsodium/lib" CFLAGS="-I$prefix/libc-ares/include -I$prefix/libev/include -I$prefix/libsodium/include" ./configure --prefix=$prefix/shadowsocks-libev --host=$host --disable-ssp --disable-documentation
    make -j$(getconf _NPROCESSORS_ONLN) && make install
}

clean() {
    cd $cur_dir
    rm -rf $cur_dir/build
}

while [ ! -z $1 ]; do
    case $1 in
        -h | --help)
            echo "Useage: sh $0 [--host=<host>] [--prefix=<path>]"
            echo ""
            echo "Options:"
            echo "     --host=<host>    the machine that you are building for"
            echo "     --prefix=<path>  install architecture-independent files in prefix[$cur_dir/dists]"
            exit 0
            ;;
        --host)
            shift
            host=$1
            ;;
        --host=*)
            arr=(${1//=/ })
            host=${arr[1]}
            ;;
        --prefix)
            shift
            prefix=$1
            ;;
        --prefix=*)
            arr=(${1//=/ })
            prefix=${arr[1]}
            ;;
    esac
    shift
done

red="\033[0;31m"
green="\033[0;32m"
plain="\033[0m"

[ -z $host ] && compiler=gcc || compiler=$host-gcc
if [ -f "$(which $compiler)" ]; then
	echo -e "found cross compiler ${green}$(which ${compiler})${plain}"
else
	echo -e "${red}Error:${plain} not found cross compiler ${green}${compiler}${plain}"
	exit -1
fi

[ -z $prefix ] && prefix=$cur_dir/dists
echo -e "binaries will be installed in ${green}${prefix}${plain}"

prepare
compile_pcre
compile_mbedtls
compile_libsodium
compile_libev
compile_libc_ares
compile_shadowsocks_libev
compile_simple_obfs
clean
