#!/bin/bash


GCCVERSION=4.8-2014.03
GDBVERSION=7.6-2013.05
BINUTILSVERSION=2.26
NEWLIBVERSION=2.4.0
OOCDVERSION=0.9.0


# Stop if any command fails
set -e

##############################################################################
# Default settings section
##############################################################################
TARGET=arm-none-eabi							# Or: TARGET=arm-elf
PREFIX=${HOME}/Developer/ARM/vgx-arm-toolchain	# Install location of your final toolchain
DARWIN_OPT_PATH=/usr/local						# Path in which MacPorts or Fink is installed

# Override automatic detection of cpus to compile on
CPUS=

##############################################################################
# Flags section
##############################################################################

if [ "x${CPUS}" == "x" ]; then
	if which getconf > /dev/null; then
		CPUS=$(getconf _NPROCESSORS_ONLN)
	else
		CPUS=1
	fi

	PARALLEL=-j$((CPUS + 1))
else
	PARALLEL=-j${CPUS}
fi

echo "${CPUS} cpu's detected running make with '${PARALLEL}' flag"

GCCFLAGS="${GCCFLAGS} \
				--with-gmp=${DARWIN_OPT_PATH} \
	          	--with-mpfr=${DARWIN_OPT_PATH} \
	          	--with-mpc=${DARWIN_OPT_PATH} \
		  		--with-libiconv-prefix=${DARWIN_OPT_PATH}"

GDBFLAGS=
BINUTILFLAGS=

OOCD_CFLAGS="-I${DARWIN_OPT_PATH}/include"
OOCD_LDFLAGS="-L${DARWIN_OPT_PATH}/lib"
 
MAKEFLAGS=${PARALLEL}
TARFLAGS=v

export PATH="${PREFIX}/bin:${PATH}"

BUILD_DIR=$(pwd)
SOURCES=${BUILD_DIR}/sources
STAMPS=${BUILD_DIR}/stamps
FTDIDRV=${BUILD_DIR}/ftdi


if gcc --version | grep llvm-gcc > /dev/null ; then
	echo "Found you are using llvm gcc, switching to clang for gcc compile."
	GCC_CC=llvm-gcc
fi

FETCH_NO_CERTCHECK="--no-check-certificate "

##############################################################################
# Tool section
##############################################################################
TAR=tar

##############################################################################
# Functions
##############################################################################

# Fetch a versioned file from a URL
function fetch {
    if [ ! -e ${STAMPS}/$1.fetch ]; then
        if [ ! -e ${SOURCES}/$1 ]; then
            log "Downloading $1 sources..."
	    wget -c ${FETCH_NO_PASSIVE} ${FETCH_NO_CERTCHECK} $2 && touch ${STAMPS}/$1.fetch
        fi
    fi
}

# Log a message out to the console
function log {
    echo "******************************************************************"
    echo "* $*"
    echo "******************************************************************"
}

# Unpack an archive
function unpack {
    log Unpacking $*
    # Use 'auto' mode decompression.  Replace with a switch if tar doesn't support -a
    ARCHIVE=$(ls ${SOURCES}/$1.tar.*)
    case ${ARCHIVE} in
	*.bz2)
	    echo "archive type bz2"
	    TYPE=j
	    ;;
	*.xz)
	    echo "archive type xz"
	    TYPE=J
	    ;;	    
	*.gz)
	    echo "archive type gz"
	    TYPE=z
	    ;;
	*)
	    echo "Unknown archive type of $1"
	    echo ${ARCHIVE}
	    exit 1
	    ;;
    esac
    ${TAR} xf${TYPE}${TARFLAGS} ${SOURCES}/$1.tar.*
}

# Install a build
function install {
    log $1
    ${SUDO} make ${MAKEFLAGS} $2 $3 $4 $5 $6 $7 $8
}

##############################################################################
# OS detection
##############################################################################
case "$(uname)" in
	Darwin)
	echo "Found Darwin OS."
	;;
	*)
	echo "Found unknown OS. Aborting!"
	exit 1
	;;	
esac

##############################################################################
# Download 
##############################################################################
mkdir -p ${STAMPS} ${SOURCES}

cd ${SOURCES}


BINUTILS=binutils-${BINUTILSVERSION}
BINUTILSURL=http://ftp.gnu.org/gnu/binutils/${BINUTILS}.tar.bz2

GCC=gcc-linaro-${GCCVERSION}
GCCURL=http://launchpad.net/gcc-linaro/$(echo $GCCVERSION | awk -F'-' '{print $1}')/${GCCVERSION}/+download/${GCC}.tar.xz

NEWLIB=newlib-${NEWLIBVERSION}
NEWLIBURL=ftp://sourceware.org/pub/newlib/${NEWLIB}.tar.gz

GDB=gdb-linaro-${GDBVERSION}
GDBURL=http://launchpad.net/gdb-linaro/$(echo $GDBVERSION | awk -F'-' '{print $1}')/${GDBVERSION}/+download/${GDB}.tar.bz2


OOCD=openocd-${OOCDVERSION}
OOCDURL=http://sourceforge.net/projects/openocd/files/openocd/${OOCDVERSION}/${OOCD}.tar.bz2

fetch ${BINUTILS} ${BINUTILSURL}
fetch ${GCC} ${GCCURL}
fetch ${NEWLIB} ${NEWLIBURL}
fetch ${GDB} ${GDBURL}
fetch ${OOCD} ${OOCDURL}

cd ${BUILD_DIR}

##############################################################################
# Install FTDI 
##############################################################################

if [ ! -e ${DARWIN_OPT_PATH}/lib/libftd2xx.dylib ]; then
	log "Install FTDI D2XX"
	cp ${FTDIDRV}/libftd2xx.1.2.2.dylib ${DARWIN_OPT_PATH}/lib/libftd2xx.1.2.2.dylib
	cp ${FTDIDRV}/WinTypes.h ${DARWIN_OPT_PATH}/include/WinTypes.h
	cp ${FTDIDRV}/ftd2xx.h ${DARWIN_OPT_PATH}/include/ftd2xx.h
	ln -sf ${DARWIN_OPT_PATH}/lib/libftd2xx.1.2.2.dylib ${DARWIN_OPT_PATH}/lib/libftd2xx.dylib    
fi

##############################################################################
# Building 
##############################################################################

if [ ! -e build ]; then
    mkdir build
fi

# Build Binutils
if [ ! -e ${STAMPS}/${BINUTILS}.build ]; then
    unpack ${BINUTILS}

	if [ -e patches/patch-binutils-${BINUTILSVERSION}-svc-cortexm3.diff]; then
    	log "Patching binutils to allow SVC support on cortex-m3"
    	cd ${BINUTILS}
    	patch -p0 -i ../patches/patch-binutils-${BINUTILSVERSION}-svc-cortexm3.diff
    	cd ..
    fi
    
    cd build
    
    log "Configuring ${BINUTILS}"    
    ../${BINUTILS}/configure --target=${TARGET} \
								 --prefix=${PREFIX} \
								 --enable-multilib \
								 --with-gnu-as \
								 --with-gnu-ld \
								 --disable-nls \
								 --disable-werror \
								 ${BINUTILFLAGS}
    
    log "Building ${BINUTILS}"
    make ${MAKEFLAGS}
    install ${BINUTILS} install
    cd ..

    log "Cleaning up ${BINUTILS}"
    touch ${STAMPS}/${BINUTILS}.build
    rm -rf build/* ${BINUTILS}
fi

# Build GCC & NEWLIB
if [ ! -e ${STAMPS}/${GCC}-${NEWLIB}.build ]; then
    unpack ${GCC}
    unpack ${NEWLIB}

    log "Adding newlib symlink to gcc"
    ln -fs `pwd`/${NEWLIB}/newlib ${GCC}
    
    log "Adding libgloss symlink to gcc"
    ln -fs `pwd`/${NEWLIB}/libgloss ${GCC}

	if [ -e patches/patch-gcc-${GCCVERSION}-multilib-support.diff ]; then
		log "Patching gcc to add multilib support"
		cd ${GCC}
		patch -p0 -i ../patches/patch-gcc-${GCCVERSION}-multilib-support.diff
		cd ..
	fi

	if [ -e patches/patch-newlib-${NEWLIBVERSION}.diff ]; then
		log "Patching newlib"
		cd ${NEWLIB}
		patch -p0 -i ../patches/patch-newlib-${NEWLIBVERSION}.diff
		cd ..
	fi
			
    cd build

    if [ "X${GCC_CC}" != "X" ] ; then
	    export GLOBAL_CC=${CC}
	    log "Overriding the default compiler with: \"${GCC_CC}\""
	    export CC=${GCC_CC}
    fi

    log "Configuring ${GCC} and ${NEWLIB}"
    ../${GCC}/configure --target=${TARGET} \
						 --prefix=${PREFIX} \
						 --enable-multilib \
						 --enable-languages="c,c++" \
						 --with-newlib \
						 --with-gnu-as \
						 --with-gnu-ld \
						 --disable-nls \
						 --disable-shared \
						 --disable-threads \
						 --with-headers=newlib/libc/include \
						 --disable-libssp \
						 --disable-libstdcxx-pch \
						 --disable-libmudflap \
						 --disable-libgomp \
						 --disable-werror \
						 --with-system-zlib \
						 --disable-newlib-supplied-syscalls \
						 --disable-newlib-fvwrite-in-streamio \
						 --disable-newlib-fseek-optimization \
						 --disable-newlib-wide-orient \
						 --disable-newlib-atexit-dynamic-alloc \
						 --enable-newlib-reent-small \
						 --enable-newlib-io-c99-formats \
						 ${GCCFLAGS}

    
    log "Building ${GCC} and ${NEWLIB}"
    make ${MAKEFLAGS}
    install ${GCC} install
    cd ..
    
    log "Cleaning up ${GCC} and ${NEWLIB}"

    if [ "X${GCC_CC}" != "X" ] ; then
	    unset CC
	    CC=${GLOBAL_CC}
	    unset GLOBAL_CC
    fi

    touch ${STAMPS}/${GCC}-${NEWLIB}.build
    rm -rf build/* ${GCC} ${NEWLIB}
	        
fi

# Build GDB
if [ ! -e ${STAMPS}/${GDB}.build ]; then
    unpack ${GDB}
    cd build

    log "Configuring ${GDB}"
    ../${GDB}/configure --target=${TARGET} \
						 --prefix=${PREFIX} \
						 --enable-multilib \
						 --disable-werror \
						 ${GDBFLAGS}

    log "Building ${GDB}"
    make ${MAKEFLAGS}
    install ${GDB} install
    cd ..

    log "Cleaning up ${GDB}"
    touch ${STAMPS}/${GDB}.build
    rm -rf build/* ${GDB}
fi

# Build OpenOCD
if [ ! -e ${STAMPS}/${OOCD}.build ]; then
    
    
    unpack ${OOCD}
    
    if [ -e patches/patch-openocd-${OOCDVERSION}-arm7m-registers.diff ]; then
    	log "Patching openocd to support arm7m registers"
    	cd ${OOCD}
    	patch -p0 -i ../patches/patch-openocd-${OOCDVERSION}-arm7m-registers.diff
    	cd ..
    fi
    
    cd build

    log "Configuring openocd-${OOCD}"
    CFLAGS="${CFLAGS} ${OOCD_CFLAGS}" \
    LDFLAGS="${LDFLAGS} ${OOCD_LDFLAGS}" \
    ../${OOCD}/configure --enable-maintainer-mode \
							 --disable-option-checking \
							 --disable-werror \
							 --prefix=${PREFIX} \
							 --enable-dummy \
							 --enable-legacy-ft2232_ftd2xx \
							 --enable-usbprog \
							 --enable-jlink \
							 --enable-vsllink \
							 --enable-rlink \
							 --enable-stlink \
							 --enable-arm-jtag-ew

    log "Building ${OOCD}"
    make ${MAKEFLAGS}
    install ${OOCD} install
    cd ..

    log "Cleaning up ${OOCD}"
    touch ${STAMPS}/${OOCD}.build
    rm -rf build/* ${OOCD}
fi
