#!/bin/bash
function err_and_exit() {
  echo "$1" >&2
  exit 1
}

function install_minisat() {
  local target_dir=$(cd $1 && pwd)
  local build_dir=${target_dir}/build
  local dist_dir=${target_dir}/dist
  mkdir -p ${target_dir}/{src,build,dist}
  cd ${target_dir} 
  if [ -z "$(ls -A src)" ]; then
    git clone https://github.com/stp/minisat.git src
  fi
  cd build
  cmake -DSTATIC_BINARIES=ON -DCMAKE_INSTALL_PREFIX=${dist_dir} ../src || err_and_exit "failed to configure minisat"
  make -j $(nproc) || err_and_exit "failed to compile minisat"
  make install || err_and_exit "failed to install minisat"
}

function install_cryptominisat() {
  local version=$1
  local release_url="https://github.com/msoos/cryptominisat/archive/${version}.tar.gz"
  local target_dir=$(cd $2 && pwd)/${version}
  local dist_dir=${target_dir}/dist
  mkdir -p ${target_dir}/{src,build,dist}
  cd ${target_dir} 
  if [ -z "$(ls -A src)" ]; then
    wget ${release_url} || err_and_exit "failed to get cryptominisat release ${version}"
    tar xzvf ${version}.tar.gz -C src --strip-components=1
    rm ${version}.tar.gz
  fi
  cd build
  cmake -DSTATICCOMPILE=ON -DCMAKE_INSTALL_PREFIX=${dist_dir}  ../src || err_and_exit "failed to configure cryptominisat"
  make -j $(nproc) || err_and_exit "failed to make cryptominisat"
  make install || err_and_exit "failed to install cryptominisat"
}

function install_stp() {
  local version=$1
  local release_url="https://github.com/stp/stp/archive/${version}.tar.gz"
  local target_dir=$(cd $2 && pwd)/${version}
  local dist_dir=${target_dir}/dist
  local minisat_dist_dir=$(cd $3 && pwd)
  local cryptominisat_dist_dir=$(cd $4 && pwd)
  mkdir -p ${target_dir}/{src,build,dist}
  cd ${target_dir} 
  if [ -z "$(ls -A src)" ]; then
    wget ${release_url} || err_and_exit "failed to get stp release ${version}"
    tar xzvf ${version}.tar.gz -C src --strip-components=1
    rm ${version}.tar.gz
  fi
  cd build
  cmake -DSTATICCOMPILE=ON -DCMAKE_INSTALL_PREFIX=${dist_dir} -DCMAKE_PREFIX_PATH=${cryptominisat_dist_dir} -DMINISAT_INCLUDE_DIRS=${minisat_dist_dir}/include -DMINISAT_LIBDIR=${minisat_dist_dir}/lib ../src || err_and_exit "failed to configure stp"
  make -j $(nproc) || err_and_exit "failed to compile stp"
  make install || err_and_exit "failed to install stp"
}

re_ver="^[0-9\.]+$"
if [ $# -ne 2 ] || ! [[ "$1" =~ ${re_ver} ]]; then
  echo "Usage: $0 <version> <directory>" >&2
  exit 1
fi
version=$1
mkdir -p $2 || err_and_exit "failed to create dest directory $2"
dest_dir=$(cd $2 && pwd)
mkdir -p ${dest_dir}/../{minisat,cryptominisat}
minisat_base=$(dirname ${dest_dir})/minisat
cryptominisat_base=$(dirname ${dest_dir})/cryptominisat
cryptominisat_version=5.6.5

install_minisat ${minisat_base}
minisat_dist_dir=${minisat_base}/dist
echo "MiniSAT installed to ${minisat_dist_dir}"
install_cryptominisat ${cryptominisat_version} ${cryptominisat_base}
cryptominisat_dist_dir=${cryptominisat_base}/${cryptominisat_version}/dist
echo "CryptoMiniSAT installed to ${cryptominisat_dist_dir}"
install_stp $version ${dest_dir} ${minisat_dist_dir} ${cryptominisat_dist_dir}
stp_dist_dir=${dest_dir}/${version}/dist
echo "STP installed to ${stp_dist_dir}"
stp_cmake_target=${stp_dist_dir}/lib/cmake/STP/STPTargets.cmake
if [ -f "${stp_cmake_target}" ]; then
  echo "Patching STP CMake targets..."
  cryptominisat_lib_path="${cryptominisat_dist_dir}/lib/libcryptominisat5.a"
  sed -i 's@\(INTERFACE_LINK_LIBRARIES .*\);libcryptominisat5;@\1;'"${cryptominisat_lib_path}"';@' "${stp_cmake_target}"
fi
