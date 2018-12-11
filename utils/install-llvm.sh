#!/bin/bash

function err_and_exit() {
  echo "$1" >&2
  exit 1
}

os="`uname`"
if [ $os == "Linux" ]; then
  num_cores=$(nproc)
elif [ $os == "Darwin" ]; then
  num_cores=$(sysctl -n hw.ncpu)
else
  num_cores=1
fi
target_dir=./
re_ver="^[0-9\.]+$"

if [ $# -lt 2 ] || ! [[ "$1" =~ ${re_ver} ]] || ! [ -d "$2" ]; then
	echo "usage: $0 <version> <directory> [<binutils_dir>]" >&2
	echo -e "\n\nexample: \n\t$0 5.0.1 /data/share/software/llvm" >&2
	echo -e "\t$0 5.0.1 /data/share/software/llvm /data/share/software/binutils/dist" >&2
	exit 1
fi
use_existing_binutils=0
if [ $# -eq 3 ] ; then
  use_existing_binutils=1
  binutils_dir=$(cd $3 && pwd)
  if [ ! -d ${binutils_dir}/include ]; then
    echo "${binutils_dir}/include does not exist" >&2
    exit 1
  fi
fi

version=$1
release_tag="RELEASE_${version//.}"
target_dir=$(cd $2 && pwd)
src_dir="${target_dir}/${version}/src"
build_dir="${target_dir}/${version}/build"
dist_dir="${target_dir}/${version}/dist"
mkdir -p ${target_dir}/${version}/{src,build,dist}

echo "Getting the complete LLVM source code"
echo "Get llvm"
svn checkout http://llvm.org/svn/llvm-project/llvm/tags/${release_tag}/final/ ${src_dir} || err_and_exit "failed to checkout llvm"
cd ${src_dir}
echo "Get clang"
svn checkout http://llvm.org/svn/llvm-project/cfe/tags/${release_tag}/final/ clang || err_and_exit "failed to checkout clang"
cd clang/tools
echo "Get clang-tools-extra"
svn checkout http://llvm.org/svn/llvm-project/clang-tools-extra/tags/${release_tag}/final/ extra || err_and_exit "failed to checkout clang-tools-extra"
cd ../..
echo "Get lld"
svn checkout http://llvm.org/svn/llvm-project/lld/tags/${release_tag}/final/ lld || err_and_exit "failed to checkout lld"
echo "Get polly"
svn checkout http://llvm.org/svn/llvm-project/polly/tags/${release_tag}/final/ polly || err_and_exit "failed to checkout polly"
cd ../projects
echo "Get compiler-rt"
svn checkout http://llvm.org/svn/llvm-project/compiler-rt/tags/${release_tag}/final compiler-rt || err_and_exit "failed to checkout compiler-rt"
echo "Get openmp"
svn checkout http://llvm.org/svn/llvm-project/openmp/tags/${release_tag}/final openmp || err_and_exit "failed to checkout openmp"
echo "Get libcxx"
svn checkout http://llvm.org/svn/llvm-project/libcxx/tags/${release_tag}/final libcxx || err_and_exit "failed to checkout libcxx"
echo "Get libcxxabi"
svn checkout http://llvm.org/svn/llvm-project/libcxxabi/tags/${release_tag}/final libcxxabi || err_and_exit "failed to checkout libcxxabi"
echo "Get test-suite"
svn checkout http://llvm.org/svn/llvm-project/test-suite/tags/${release_tag}/final test-suite || err_and_exit "failed to checkout test-suite"
if [ $use_existing_binutils -eq 0 ]; then
  cd ..
  echo "Get new-ld with plugin support"
  binutils_dir=$(cd binutils && pwd)
  git clone --depth 1 git://sourceware.org/git/binutils-gdb.git binutils
  cd binutils
  mkdir build
  cd build
  echo "build binutils"
  ../configure --disable-werror
  make -j${num_cores} all-ld || err_and_exit "failed to build binutils"
fi
echo "LLVM source code and plugins are set up"
echo "Build the LLVM project"
cd ${build_dir} || err_and_exit "failed to go to ${build_dir}" 
cmake -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX=${dist_dir} -DCMAKE_BUILD_TYPE=Release -DLLVM_ENABLE_CXX1Y=ON -DLLVM_ENABLE_EH=ON -DLLVM_ENABLE_RTTI=ON -DLLVM_BUILD_LLVM_DYLIB=ON -DLLVM_BINUTILS_INCDIR=${binutils_dir}/include ../src
make -j${num_cores}
echo "Installing LLVM"
make install
echo "Successfully installed LLVM"
