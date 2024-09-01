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

# Load variables from config.env
source config.env

# Path
MainPath="$(readlink -f -- $(pwd))"
MainClangPath="${MainPath}/clang"
AnyKernelPath="${MainPath}/anykernel"
CrossCompileFlagTriple="aarch64-linux-gnu-"
CrossCompileFlag64="aarch64-linux-gnu-"
CrossCompileFlag32="arm-linux-gnueabi-"

# Clone toolchain
[[ "$(pwd)" != "${MainPath}" ]] && cd "${MainPath}"
function getclang() {
  if [ "${ClangName}" = "azure" ]; then
    if [ ! -f "${MainClangPath}-azure/bin/clang" ]; then
      echo "[!] Clang is set to azure, cloning it..."
      git clone https://gitlab.com/Panchajanya1999/azure-clang clang-azure --depth=1
      ClangPath="${MainClangPath}"-azure
      export PATH="${ClangPath}/bin:${PATH}"
      patch_glibc "${ClangPath}"
    else
      echo "[!] Clang already exists. Skipping..."
      ClangPath="${MainClangPath}"-azure
      export PATH="${ClangPath}/bin:${PATH}"
    fi
  elif [ "${ClangName}" = "neutron" ] || [ "${ClangName}" = "" ]; then
    if [ ! -f "${MainClangPath}-neutron/bin/clang" ]; then
      echo "[!] Clang is set to neutron, cloning it..."
      mkdir -p "${MainClangPath}"-neutron
      ClangPath="${MainClangPath}"-neutron
      export PATH="${ClangPath}/bin:${PATH}"
      patch_glibc "${ClangPath}"
    else
      echo "[!] Clang already exists. Skipping..."
      ClangPath="${MainClangPath}"-neutron
      export PATH="${ClangPath}/bin:${PATH}"
    fi
  elif [ "${ClangName}" = "proton" ]; then
    if [ ! -f "${MainClangPath}-proton/bin/clang" ]; then
      echo "[!] Clang is set to proton, cloning it..."
      git clone https://github.com/kdrag0n/proton-clang clang-proton --depth=1
      ClangPath="${MainClangPath}"-proton
      export PATH="${ClangPath}/bin:${PATH}"
      patch_glibc "${ClangPath}"
    else
      echo "[!] Clang already exists. Skipping..."
      ClangPath="${MainClangPath}"-proton
      export PATH="${ClangPath}/bin:${PATH}"
    fi
  elif [ "${ClangName}" = "zyc" ]; then
    if [ ! -f "${MainClangPath}-zyc/bin/clang" ]; then
      echo "[!] Clang is set to zyc, cloning it..."
      mkdir -p ${MainClangPath}-zyc
      cd clang-zyc
      wget -q $(curl -k https://raw.githubusercontent.com/ZyCromerZ/Clang/main/Clang-main-link.txt 2>/dev/null) -O "zyc-clang.tar.gz"
      tar -xf zyc-clang.tar.gz
      rm -f zyc-clang.tar.gz
      cd ..
      ClangPath="${MainClangPath}"-zyc
      export PATH="${ClangPath}/bin:${PATH}"
      patch_glibc "${ClangPath}"
    elif [ "${ClangName}" = "lilium" ]; then
      echo "[!] Clang is set to lilium, cloning it..."
      mkdir -p ${MainClangPath}-lilium
      cd ${MainClangPath}-lilium
      LiliumLatest=$(curl -s https://api.github.com/repos/liliumproject/clang/releases/latest | grep "download_url" | cut -d '"' -f 4)
      wget -q ${LiliumLatest} -O "lilium-clang.tar.gz"
      tar -xf lilium-clang.tar.gz
      rm -f lilium-clang.tar.gz
      ClangPath="${MainClangPath}"-lilium
      export PATH="${ClangPath}/bin:${PATH}"
      patch_glibc "${ClangPath}"
    else
      echo "[!] Clang already exists. Skipping..."
      ClangPath="${MainClangPath}"-zyc
      export PATH="${ClangPath}/bin:${PATH}"
    fi
  else
    echo "[!] Incorrect clang name. Check config.env for clang names."
    exit 1
  fi
  if [ ! -f '${MainClangPath}-${ClangName}/bin/clang' ]; then
    export KBUILD_COMPILER_STRING="$(${MainClangPath}-${ClangName}/bin/clang --version | head -n 1)"
  else
    export KBUILD_COMPILER_STRING="Unknown"
  fi
}

# Update clang function
function updateclang() {
  [[ "$(pwd)" != "${MainPath}" ]] && cd "${MainPath}"
  if [ "${ClangName}" = "neutron" ] || [ "${ClangName}" = "" ]; then
    echo "[!] Clang is set to neutron, checking for updates..."
    cd clang-neutron
    if [ "$(./antman -U | grep "Nothing to do")" = "" ];then
      ./antman --patch=glibc
    else
      echo "[!] No updates have been found, skipping"
    fi
    cd ..
    elif [ "${ClangName}" = "zyc" ]; then
      echo "[!] Clang is set to zyc, checking for updates..."
      cd clang-zyc
      ZycLatest="$(curl -k https://raw.githubusercontent.com/ZyCromerZ/Clang/main/Clang-main-lastbuild.txt)"
      if [ "$(cat README.md | grep "Build Date : " | cut -d: -f2 | sed "s/ //g")" != "${ZycLatest}" ];then
        echo "[!] An update have been found, updating..."
        sudo rm -rf ./*
        wget -q $(curl -k https://raw.githubusercontent.com/ZyCromerZ/Clang/main/Clang-main-link.txt 2>/dev/null) -O "zyc-clang.tar.gz"
        tar -xf zyc-clang.tar.gz
        rm -f zyc-clang.tar.gz
      else
        echo "[!] No updates have been found, skipping..."
      fi
      cd ..
    elif [ "${ClangName}" = "azure" ]; then
      cd clang-azure
      git fetch -q origin main
      git pull origin main
      cd ..
    elif [ "${ClangName}" = "proton" ]; then
      cd clang-proton
      git fetch -q origin master
      git pull origin master
      cd ..
  fi
}

function patch_glibc() {
  cd $1
  curl -LOk "https://raw.githubusercontent.com/Neutron-Toolchains/antman/main/antman"
  chmod +x antman
  ./antman --patch=glibc
  cd -
}

# Enviromental variable
DEVICE_MODEL="Redmi Note 8 Pro"
DEVICE_CODENAME="begonia"
export DEVICE_DEFCONFIG="begonia_user_defconfig"
export ARCH="arm64"
export KBUILD_BUILD_USER="EreN"
export KBUILD_BUILD_HOST="kernel"
export KERNEL_NAME="$(cat "arch/arm64/configs/$DEVICE_DEFCONFIG" | grep "CONFIG_LOCALVERSION=" | sed 's/CONFIG_LOCALVERSION="-*//g' | sed 's/"*//g' )"
export SUBLEVEL="v4.14.$(cat "${MainPath}/Makefile" | grep "SUBLEVEL =" | sed 's/SUBLEVEL = *//g')"
IMAGE="${MainPath}/out/arch/arm64/boot/Image.gz-dtb"
CORES="$(nproc --all)"
BRANCH="$(git rev-parse --abbrev-ref HEAD)"

# Start Compile
START=$(date +"%s")

compile(){
if [ "$ClangName" = "proton" ]; then
  sed -i 's/CONFIG_LLVM_POLLY=y/# CONFIG_LLVM_POLLY is not set/g' ${MainPath}/arch/$ARCH/configs/$DEVICE_DEFCONFIG || echo ""
else
  sed -i 's/# CONFIG_LLVM_POLLY is not set/CONFIG_LLVM_POLLY=y/g' ${MainPath}/arch/$ARCH/configs/$DEVICE_DEFCONFIG || echo ""
fi
make O=out ARCH=$ARCH $DEVICE_DEFCONFIG
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
    CROSS_COMPILE_ARM32=${CrossCompileFlag32}

   if [[ -f "$IMAGE" ]]; then
      cd ${MainPath}
      cp out/.config arch/${ARCH}/configs/${DEVICE_DEFCONFIG} && git add arch/${ARCH}/configs/${DEVICE_DEFCONFIG} && git commit -m "defconfig: Regenerate"
      git clone --depth=1 ${AnyKernelRepo} -b ${AnyKernelBranch} ${AnyKernelPath}
      cp $IMAGE ${AnyKernelPath}
   else
      echo "❌ Compile Kernel for $DEVICE_CODENAME failed, Check console log to fix it!"
      if [ "$CLEANUP" = "yes" ];then
        cleanup
      fi
      exit 1
   fi
}

# Zipping function
function zipping() {
    cd ${AnyKernelPath} || exit 1
    if [ "$KERNELSU" = "yes" ];then
      sed -i "s/kernel.string=.*/kernel.string=${KERNEL_NAME} ${SUBLEVEL} ${KERNEL_VARIANT} by ${KBUILD_BUILD_USER} for ${DEVICE_MODEL} (${DEVICE_CODENAME}) | KernelSU Version: ${KERNELSU_VERSION}/g" anykernel.sh
    else
      sed -i "s/kernel.string=.*/kernel.string=${KERNEL_NAME} ${SUBLEVEL} ${KERNEL_VARIANT} by ${KBUILD_BUILD_USER} for ${DEVICE_MODEL} (${DEVICE_CODENAME})/g" anykernel.sh
    fi
    zip -r9 "[${KERNEL_VARIANT}]"-${KERNEL_NAME}-${SUBLEVEL}-${DEVICE_CODENAME}.zip * -x .git README.md *placeholder
    upload "\[${KERNEL_VARIANT}\]-${KERNEL_NAME}-${SUBLEVEL}-${DEVICE_CODENAME}.zip"
    cd ..
    mkdir -p builds
    zipname="$(basename $(echo ${AnyKernelPath}/*.zip | sed "s/.zip//g"))"
    cp ${AnyKernelPath}/*.zip ./builds/${zipname}-$DATE.zip
    cleanup
}

# Cleanup function
function cleanup() {
    cd ${MainPath}
    sudo rm -rf ${AnyKernelPath}
    sudo rm -rf out/
}

# KernelSU function
function kernelsu() {
    if [ "$KERNELSU" = "yes" ];then
      KERNEL_VARIANT="${KERNEL_VARIANT}-KernelSU"
      if [ ! -f "${MainPath}/KernelSU/README.md" ]; then
        cd ${MainPath}
        curl -LSsk "https://raw.githubusercontent.com/tiann/KernelSU/main/kernel/setup.sh" | bash -s v0.9.5
        cd KernelSU
        git revert --no-commit 898e9d4f8ca9b2f46b0c6b36b80a872b5b88d899
        cd ..
        git apply KSU.patch
      fi
      KERNELSU_VERSION="$((10000 + $(cd KernelSU && git rev-list --count HEAD) + 200))"
      git submodule update --init; cd ${MainPath}/KernelSU; git pull origin main; cd ..
    fi
}

# Upload function
function upload() {
    cd ${AnyKernelPath}
    set +o history
    RESPONSE=$(curl -X POST https://storage.erensprojects.web.tr/api/upload -H "x-api-key: ${STORAGE_API_KEY}" -F "files=@$1")
    set -o history
    URL=$(echo $RESPONSE | jq -r '.files[0].url')
    echo "File uploaded successfully. Download URL: $URL"
}

getclang
updateclang
kernelsu
compile
zipping
END=$(date +"%s")
DIFF=$(($END - $START))
