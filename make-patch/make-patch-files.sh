#!/bin/bash


BINUTILSVERSION=2.24
GCCVERSION=4.8-2014.02
NEWLIBVERSION=2.1.0
OOCDVERSION=0.7.0


# FTP options ... some environments do not support non-passive FTP
FETCH_NO_CERTCHECK="--no-check-certificate "

TARFLAGS=v

PATCH_DIR=$(pwd)
SOURCES=${PATCH_DIR}/sources
PATCHES=${PATCH_DIR}/patches

##############################################################################
# Tool section
##############################################################################
TAR=tar

# Fetch a versioned file from a URL
function fetch {
	if [ ! -e ${SOURCES}/$1 ]; then
    	log "Downloading $1 sources..."
	    wget -c ${FETCH_NO_PASSIVE} ${FETCH_NO_CERTCHECK} $2
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

mkdir -p ${SOURCES} ${PATCHES}

cd ${SOURCES}

# Download

BINUTILS=binutils-${BINUTILSVERSION}
BINUTILSURL=http://ftp.gnu.org/gnu/binutils/${BINUTILS}.tar.bz2

GCC=gcc-linaro-${GCCVERSION}
GCCURL=http://launchpad.net/gcc-linaro/$(echo $GCCVERSION | awk -F'-' '{print $1}')/${GCCVERSION}/+download/${GCC}.tar.xz

NEWLIB=newlib-${NEWLIBVERSION}
NEWLIBURL=ftp://sourceware.org/pub/newlib/${NEWLIB}.tar.gz

OOCD=openocd-${OOCDVERSION}
OOCDURL=http://sourceforge.net/projects/openocd/files/openocd/${OOCDVERSION}/${OOCD}.tar.bz2

fetch ${BINUTILS} ${BINUTILSURL}
fetch ${GCC} ${GCCURL}
fetch ${NEWLIB} ${NEWLIBURL}
fetch ${OOCD} ${OOCDURL}

cd ${PATCH_DIR}

if [ ! -e patches/patch-binutils-${BINUTILSVERSION}-svc-cortexm3.diff ]; then
	
	if [ ! -d ${BINUTILS}]; then
		unpack ${BINUTILS}
	fi
	
	cd ${BINUTILS}

	if [ ! -e include/opcode/arm.h.orig ]; then
		cp include/opcode/arm.h include/opcode/arm.h.orig
	fi
	
	nano include/opcode/arm.h
	
	diff -Nur include/opcode/arm.h.orig include/opcode/arm.h > ../patches/patch-binutils-${BINUTILSVERSION}-svc-cortexm3.diff
	
	cd ..

fi

if [ ! -e patches/patch-gcc-${GCCVERSION}-multilib-support.diff ]; then

	if [ ! -d ${GCC} ]; then
		unpack ${GCC}
	fi
	
	cd ${GCC}
	
	if [ ! -e gcc/config/arm/t-arm-elf.orig ]; then
		cp gcc/config/arm/t-arm-elf gcc/config/arm/t-arm-elf.orig
	fi

	if [ ! -e libgcc/Makefile.in.orig ]; then
		cp libgcc/Makefile.in libgcc/Makefile.in.orig
	fi
		
	nano gcc/config/arm/t-arm-elf
	nano libgcc/Makefile.in
	
	diff -Nur gcc/config/arm/t-arm-elf.orig gcc/config/arm/t-arm-elf > ../patches/patch-gcc-${GCCVERSION}-multilib-support.diff
	diff -Nur libgcc/Makefile.in.orig libgcc/Makefile.in >> ../patches/patch-gcc-${GCCVERSION}-multilib-support.diff
	
	cd ..

fi

if [ ! -e patches/patch-newlib-${NEWLIBVERSION}.diff ]; then
	
	if [ ! -d ${NEWLIB} ]; then
		unpack ${NEWLIB}
	fi
	
	cd ${NEWLIB}

	if [ ! -e libgloss/arm/cpu-init/Makefile.in.orig ]; then
		cp libgloss/arm/cpu-init/Makefile.in libgloss/arm/cpu-init/Makefile.in.orig
	fi

	nano libgloss/arm/cpu-init/Makefile.in
	
	diff -Nur libgloss/arm/cpu-init/Makefile.in.orig libgloss/arm/cpu-init/Makefile.in > ../patches/patch-newlib-${NEWLIBVERSION}.diff

	cd ..

fi

if [ ! -e patches/patch-openocd-${OOCDVERSION}-arm7m-registers.diff ]; then
	
	if [ ! -d ${OOCD} ]; then
		unpack ${OOCD}
	fi
	
	cd ${OOCD}

	if [ ! -e Makefile.am.orig ]; then
		cp Makefile.am Makefile.am.orig
	fi
	
	if [ ! -e configure.ac.orig ]; then	
		cp configure.ac configure.ac.orig
	fi
	
	if [ ! -e src/target/armv7m.c.orig ]; then	
		cp src/target/armv7m.c src/target/armv7m.c.orig
	fi

	if [ ! -e src/target/armv7m.h.orig ]; then	
		cp src/target/armv7m.h src/target/armv7m.h.orig
	fi
	
	nano Makefile.am
	nano configure.ac
	nano src/target/armv7m.c
	nano src/target/armv7m.h
	
	diff -Nur Makefile.am.orig Makefile.am > ../patches/patch-openocd-${OOCDVERSION}-arm7m-registers.diff
	diff -Nur configure.ac.orig configure.ac >> ../patches/patch-openocd-${OOCDVERSION}-arm7m-registers.diff
	diff -Nur src/target/armv7m.c.orig src/target/armv7m.c >> ../patches/patch-openocd-${OOCDVERSION}-arm7m-registers.diff
	diff -Nur src/target/armv7m.h.orig src/target/armv7m.h >> ../patches/patch-openocd-${OOCDVERSION}-arm7m-registers.diff
	
	cd ..
	
fi

