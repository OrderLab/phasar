#!/bin/bash

if [ $# -ne 1 ] || [ ! -d "$1" ]; then
  echo "usage: $0 <directory>" >&2
  exit 1
fi
target_dir=$(cd $1 && pwd)
os="`uname`"
if [ $os == "Linux" ]; then
  num_cores=$(nproc)
elif [ $os == "Darwin" ]; then
  num_cores=$(sysctl -n hw.ncpu)
else
  num_cores=1
fi

cd ${target_dir}
mkdir -p ${target_dir}/{src,build,dist}
echo "Getting the source code of binutils"
git clone --depth 1 git://sourceware.org/git/binutils-gdb.git ${target_dir}/src
cd ${target_dir}/build
../src/configure --prefix=${target_dir}/dist --enable-gold --enable-plugins --disable-werror
make -j${num_cores} all-gold
if [ $? -ne 0 ]; then
  echo "make failed" >&2
  exit 1
fi
make -j${num_cores}
make install
