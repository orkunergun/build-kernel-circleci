#!/usr/bin/env bash
#
# Copyright (C) 2022-2023 Neebe3289 <neebexd@gmail.com>
# Copyright (C) 2023-2024 MrErenK <akbaseren4751@gmail.com>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Personal script for kranul compilation !!

# Exit on error
set -e

# Functions for messaging and error handling
function msg() {
  echo "[!] $1"
}

function error() {
  echo "❌ Error: $1"
  exit 1
}

function success() {
  echo "✅ $1"
}

# Function to handle script interruption
function cleanup_on_interrupt() {
  echo "Script interrupted. Cleaning up..."
  cleanup
  exit 1
}

# Catch Ctrl+C and other terminations
trap cleanup_on_interrupt SIGINT SIGTERM

# Load variables from config.env
if [ -f config.env ]; then
  source config.env
else
  error "config.env file not found!"
fi

# Paths
MainPath="$(readlink -f -- $(pwd))"
MainClangPath="${MainPath}/clang"
AnyKernelPath="${MainPath}/anykernel"

# Clone toolchain
[[ "$(pwd)" != "${MainPath}" ]] && cd "${MainPath}"

function getclang() {
  local clang_dir="${MainClangPath}-${ClangName}"
  if [ ! -f "${clang_dir}/bin/clang" ]; then
    msg "Clang is set to ${ClangName}, cloning it..."
    case "${ClangName}" in
    azure)
      git clone https://gitlab.com/Panchajanya1999/azure-clang clang-azure --depth=1 || error "Failed to clone azure-clang"
      ;;
    neutron)
      mkdir -p "${clang_dir}" || error "Failed to create directory ${clang_dir}"
      ;;
    proton)
      git clone https://github.com/kdrag0n/proton-clang clang-proton --depth=1 || error "Failed to clone proton-clang"
      ;;
    zyc)
      mkdir -p ${clang_dir} || error "Failed to create directory ${clang_dir}"
      cd ${clang_dir}
      wget -q $(curl -k https://raw.githubusercontent.com/ZyCromerZ/Clang/main/Clang-main-link.txt) -O "zyc-clang.tar.gz" || error "Failed to download zyc-clang"
      tar -xf zyc-clang.tar.gz || error "Failed to extract zyc-clang"
      rm -f zyc-clang.tar.gz
      cd ..
      ;;
    lilium)
      mkdir -p ${clang_dir} || error "Failed to create directory ${clang_dir}"
      cd ${clang_dir}
      LiliumLatest=$(curl -s https://api.github.com/repos/liliumproject/clang/releases/latest | grep "download_url" | cut -d '"' -f 4)
      wget -q ${LiliumLatest} -O "lilium-clang.tar.gz" || error "Failed to download lilium-clang"
      tar -xf lilium-clang.tar.gz || error "Failed to extract lilium-clang"
      rm -f lilium-clang.tar.gz
      echo "${LiliumLatest}" >lilium-clang-latest.txt
      cd ..
      ;;
    *)
      error "Incorrect clang name. Check config.env for clang names."
      ;;
    esac
    ClangPath="${clang_dir}"
    export PATH="${ClangPath}/bin:${PATH}"
    patch_glibc "${ClangPath}"
  else
    msg "Clang already exists. Skipping..."
    ClangPath="${clang_dir}"
    export PATH="${ClangPath}/bin:${PATH}"
  fi

  if [ -f "${clang_dir}/bin/clang" ]; then
    export KBUILD_COMPILER_STRING="$(${clang_dir}/bin/clang --version | head -n 1 | sed 's/ (.*)//g')"
  else
    export KBUILD_COMPILER_STRING="Unknown"
  fi
}

function updateclang() {
  [[ "$(pwd)" != "${MainPath}" ]] && cd "${MainPath}"
  case "${ClangName}" in
  neutron)
    msg "Clang is set to neutron, checking for updates..."
    cd clang-neutron
    if [ -z "$(./antman -U | grep 'Nothing to do')" ]; then
      ./antman --patch=glibc || error "Failed to patch glibc"
    else
      msg "No updates have been found, skipping"
    fi
    cd ..
    ;;
  zyc)
    msg "Clang is set to zyc, checking for updates..."
    cd clang-zyc
    ZycLatest="$(curl -k https://raw.githubusercontent.com/ZyCromerZ/Clang/main/Clang-main-lastbuild.txt)"
    if [ "$(grep 'Build Date :' README.md | cut -d: -f2 | sed 's/ //g')" != "${ZycLatest}" ]; then
      msg "An update has been found, updating..."
      sudo rm -rf ./* || error "Failed to clean directory"
      wget -q $(curl -k https://raw.githubusercontent.com/ZyCromerZ/Clang/main/Clang-main-link.txt) -O "zyc-clang.tar.gz" || error "Failed to download zyc-clang"
      tar -xf zyc-clang.tar.gz || error "Failed to extract zyc-clang"
      rm -f zyc-clang.tar.gz
      patch_glibc "${ClangPath}"
    else
      msg "No updates have been found, skipping..."
    fi
    cd ..
    ;;
  azure)
    cd clang-azure
    git fetch origin main
    if [ "$(git rev-parse HEAD)" != "$(git rev-parse @{u})" ]; then
      git pull origin main || error "Failed to pull updates for azure-clang"
      patch_glibc "${ClangPath}"
    else
      msg "No updates have been found, skipping..."
    fi
    cd ..
    ;;
  proton)
    cd clang-proton
    if [ -z "$(git fetch -q origin master | grep 'Already up to date')" ]; then
      git pull origin master || error "Failed to pull updates for proton-clang"
      patch_glibc "${ClangPath}"
    else
      msg "No updates have been found, skipping..."
    fi
    cd ..
    ;;
  lilium)
    cd clang-lilium
    ClangVersion="$(cat lilium-clang-latest.txt)"
    LiliumLatest="$(curl -s https://api.github.com/repos/liliumproject/clang/releases/latest | grep "download_url" | cut -d '"' -f 4)"
    if [ "${ClangVersion}" != "${LiliumLatest}" ]; then
      msg "An update has been found, updating..."
      sudo rm -rf ./* || error "Failed to clean directory"
      wget -q ${LiliumLatest} -O "lilium-clang.tar.gz" || error "Failed to download lilium-clang"
      tar -xf lilium-clang.tar.gz || error "Failed to extract lilium-clang"
      rm -f lilium-clang.tar.gz
      patch_glibc "${ClangPath}"
      echo ${LiliumLatest} >lilium-clang-latest.txt
    else
      msg "No updates have been found, skipping..."
    fi
    cd ..
    ;;
  esac
}

function patch_glibc() {
  cd $1
  curl -LOk "https://raw.githubusercontent.com/Neutron-Toolchains/antman/main/antman" || error "Failed to download antman"
  chmod +x antman || error "Failed to make antman executable"
  ./antman --patch=glibc || error "Failed to patch glibc"
  cd -
}

# Environmental variables
export DEVICE_MODEL="${DeviceModel}"
export DEVICE_CODENAME="${DeviceCodename}"
export DEVICE_DEFCONFIG="${DefConfig}"
export ARCH="${DeviceArch}"
export KBUILD_BUILD_USER="${BuildUser}"
export KBUILD_BUILD_HOST="${BuildHost}"
export KERNEL_NAME="$(cat "arch/${ARCH}/configs/${DEVICE_DEFCONFIG}" | grep "CONFIG_LOCALVERSION=" | sed 's/CONFIG_LOCALVERSION="-*//g' | sed 's/"*//g')"
export SUBLEVEL="v4.14.$(cat "${MainPath}/Makefile" | grep "SUBLEVEL =" | sed 's/SUBLEVEL = *//g')"
export IMAGE="${MainPath}/out/arch/${ARCH}/boot/Image.gz-dtb"
export CORES="$(nproc --all)"

# Start Compile
START=$(date +"%s")
msg "Starting kernel build (${KERNEL_NAME}) for ${DEVICE_MODEL} (${DEVICE_CODENAME})"

function compile() {
  if [ "$ClangName" = "proton" ]; then
    sed -i 's/CONFIG_LLVM_POLLY=y/# CONFIG_LLVM_POLLY is not set/g' ${MainPath}/arch/$ARCH/configs/${DEVICE_DEFCONFIG} || echo ""
  else
    sed -i 's/# CONFIG_LLVM_POLLY is not set/CONFIG_LLVM_POLLY=y/g' ${MainPath}/arch/$ARCH/configs/${DEVICE_DEFCONFIG} || echo ""
  fi
  make O=out ARCH=$ARCH $DEVICE_DEFCONFIG || error "Failed to make defconfig"
  make -j"$CORES" ARCH=$ARCH O=out \
    CC=clang \
    LD=ld.lld \
    LLVM=1 \
    LLVM_IAS=1 \
    AR=llvm-ar \
    NM=llvm-nm \
    OBJCOPY=llvm-objcopy \
    OBJDUMP=llvm-objdump \
    STRIP=llvm-strip \
    CLANG_TRIPLE=${CrossCompileFlagTriple} \
    CROSS_COMPILE=${CrossCompileFlag64} \
    CROSS_COMPILE_ARM32=${CrossCompileFlag32} || error "Kernel compilation failed"

  if [[ -f "$IMAGE" ]]; then
    cd ${MainPath}
    if [ "${RegenerateDefconfig}" = "yes" ]; then
      cp out/.config arch/${ARCH}/configs/${DEVICE_DEFCONFIG} && git add arch/${ARCH}/configs/${DEVICE_DEFCONFIG} && git commit -m "defconfig: Regenerate" || error "Failed to regenerate defconfig"
    fi
    msg "Cloning AnyKernel repository..."
    if [ ! -d "${AnyKernelPath}" ]; then
      git clone --depth=1 ${AnyKernelRepo} -b ${AnyKernelBranch} ${AnyKernelPath} || error "Failed to clone AnyKernel repository"
    fi
    cp $IMAGE ${AnyKernelPath} || error "Failed to copy kernel image"
  else
    error "Compile Kernel for $DEVICE_CODENAME failed, Check console log to fix it!"
    if [ "$CLEANUP" = "yes" ]; then
      cleanup
    fi
    exit 1
  fi
}

function write_build_info() {
  echo "Build info for ${KERNEL_ZIP_NAME}:" >$1.txt
  echo "Kernel name: ${KERNEL_NAME}" >>$1.txt
  echo "Sublevel: ${SUBLEVEL}" >>$1.txt
  echo "Kernel variant: ${KERNEL_VARIANT}" >>$1.txt
  echo "Build user: ${KBUILD_BUILD_USER}" >>$1.txt
  echo "Device model: ${DEVICE_MODEL}" >>$1.txt
  echo "Device codename: ${DEVICE_CODENAME}" >>$1.txt
  msg "Build info for ${KERNEL_ZIP_NAME}:"
  msg "Kernel name: ${KERNEL_NAME}"
  msg "Sublevel: ${SUBLEVEL}"
  msg "Kernel variant: ${KERNEL_VARIANT}"
  msg "Build user: ${KBUILD_BUILD_USER}"
  msg "Device model: ${DEVICE_MODEL}"
  msg "Device codename: ${DEVICE_CODENAME}"
}

function zipping() {
  cd ${AnyKernelPath} || error "Failed to change directory to ${AnyKernelPath}"
  if [ "$KERNELSU" = "yes" ]; then
    sed -i "s/kernel.string=.*/kernel.string=${KERNEL_NAME} ${SUBLEVEL} ${KERNEL_VARIANT} by ${KBUILD_BUILD_USER} for ${DEVICE_MODEL} (${DEVICE_CODENAME}) | KernelSU Version: ${KERNELSU_VERSION}/g" anykernel.sh || error "Failed to update kernel string in anykernel.sh"
  else
    sed -i "s/kernel.string=.*/kernel.string=${KERNEL_NAME} ${SUBLEVEL} ${KERNEL_VARIANT} by ${KBUILD_BUILD_USER} for ${DEVICE_MODEL} (${DEVICE_CODENAME})/g" anykernel.sh || error "Failed to update kernel string in anykernel.sh"
  fi
  KERNEL_ZIP_NAME="[${KERNEL_VARIANT}]-${KERNEL_NAME}-${SUBLEVEL}-${DEVICE_CODENAME}.zip"
  msg "Zipping kernel: ${KERNEL_ZIP_NAME}"
  zip -r9 "${KERNEL_ZIP_NAME}" * -x .git README.md *placeholder || error "Failed to zip kernel"
  mkdir -p ${MainPath}/builds || error "Failed to create builds directory"
  cp ${AnyKernelPath}/*.zip ${MainPath}/builds || error "Failed to copy zip file to builds directory"
  write_build_info ${MainPath}/builds/${KERNEL_ZIP_NAME}
  upload "${MainPath}/builds/${KERNEL_ZIP_NAME}" || error "Failed to upload kernel"
  cd ..
  mkdir -p builds || error "Failed to create builds directory"
  zipname="$(basename $(echo ${AnyKernelPath}/*.zip | sed "s/.zip//g"))"
  cp ${AnyKernelPath}/*.zip ./builds/${zipname}-$DATE.zip || error "Failed to copy zip file to builds directory"
  cleanup
}

function cleanup() {
  if [ "$CLEANUP" = "yes" ]; then
    cd ${MainPath}
    msg "Cleaning up..."
    sudo rm -rf ${AnyKernelPath} || error "Failed to remove ${AnyKernelPath}"
    sudo rm -rf out/ || error "Failed to remove out/ directory"
    success "Cleanup completed successfully"
  else
    msg "Cleanup is disabled, skipping..."
  fi
}

function kernelsu() {
  if [ "$KERNELSU" = "yes" ]; then
    KERNEL_VARIANT="${KERNEL_VARIANT}-KernelSU"
    if [ ! -f "${MainPath}/KernelSU/LICENSE" ]; then
      cd ${MainPath}
      curl -LSsk "https://raw.githubusercontent.com/tiann/KernelSU/main/kernel/setup.sh" | bash -s v0.9.5 || error "Failed to setup KernelSU"
      cd KernelSU
      git revert --no-commit 898e9d4f8ca9b2f46b0c6b36b80a872b5b88d899 || msg "Warning: Failed to revert commit 898e9d4f8ca9b2f46b0c6b36b80a872b5b88d899"
      cd ..
      if ! git apply KSU.patch; then
        msg "Warning: Failed to apply KSU.patch. Skipping patch application."
      fi
      msg "KernelSU setup completed successfully"
    fi
    KERNELSU_VERSION="$((10000 + $(cd KernelSU && git rev-list --count HEAD) + 200))"
    cd ${MainPath}
    msg "KernelSU version: ${KERNELSU_VERSION}"
  fi
}

function upload() {
  msg "Uploading file: $1"
  cd ${AnyKernelPath}
  [ -z "$STORAGE_API_KEY" ] && error "STORAGE_API_KEY is not set"
  RESPONSE=$(curl -X POST https://storage.erensprojects.web.tr/api/upload -H "x-api-key: ${STORAGE_API_KEY}" -F "files=@$1") || error "Failed to upload file"
  URL=$(echo $RESPONSE | jq -r '.files[0].url')
  if [ -z "$URL" ]; then
    error "Failed to retrieve upload URL"
  else
    success "File uploaded successfully. Download URL: $URL"
  fi
}

getclang
updateclang
kernelsu
compile
zipping
END=$(date +"%s")
DIFF=$(($END - $START))
success "Build completed successfully for ${DEVICE_MODEL} (${DEVICE_CODENAME}) in $(($DIFF / 60)) minutes and $(($DIFF % 60)) seconds."
