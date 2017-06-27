#!/bin/bash

PROJECT_DIR="$(dirname $(dirname ${BASH_SOURCE[0]}))"
BUILT_PRODUCTS_DIR="$(mktemp -d)"

PKG_VERSION="0.$(git rev-list HEAD | wc -l | bc)"

BASE_RELEASE_LOCATION="${PROJECT_DIR}/build"
RELEASE_LOCATION="${BASE_RELEASE_LOCATION}/${PKG_VERSION}"
RELEASE_PRODUCT_LOCATION="${RELEASE_LOCATION}/Products"
RELEASE_DSYM_LOCATION="${RELEASE_LOCATION}/dSYM"

PKG_ROOT="$(mktemp -d)"

mkdir -p "${BUILT_PRODUCTS_DIR}/dSYM"
mkdir -p "${BUILT_PRODUCTS_DIR}/Products"
mkdir -p "${RELEASE_PRODUCT_LOCATION}"
mkdir -p "${RELEASE_DSYM_LOCATION}"

echo "Project location: ${PROJECT_DIR}"
echo "Temporary build dir: ${BUILT_PRODUCTS_DIR}"
echo "Release location: ${RELEASE_LOCATION}"

echo "####### Build project"

for SCHEME_TO_BUILD in EasyLogin elctl EasyLoginAgent EasyLoginOD
do
    echo "### Start building ${SCHEME_TO_BUILD}"

    ARTEFACT_NAME=$(xcodebuild -workspace "${PROJECT_DIR}/EasyLogin.xcworkspace" -configuration Release -scheme ${SCHEME_TO_BUILD} -showBuildSettings | grep WRAPPER_NAME | sed "s/^[ \t]*//" | sed "s/WRAPPER_NAME = //")

    if [ -z "${ARTEFACT_NAME}" ]
    then
        ARTEFACT_NAME=$(xcodebuild -workspace "${PROJECT_DIR}/EasyLogin.xcworkspace" -configuration Release -scheme ${SCHEME_TO_BUILD} -showBuildSettings | grep EXECUTABLE_NAME | sed "s/^[ \t]*//" | sed "s/EXECUTABLE_NAME = //")
    fi

    echo "Product name will be ${ARTEFACT_NAME}"

    xcodebuild -quiet -workspace "${PROJECT_DIR}/EasyLogin.xcworkspace" -configuration Release -scheme ${SCHEME_TO_BUILD} CONFIGURATION_TEMP_DIR="${BUILT_PRODUCTS_DIR}/Intermediates" CONFIGURATION_BUILD_DIR="${BUILT_PRODUCTS_DIR}/Products" DWARF_DSYM_FOLDER_PATH="${BUILT_PRODUCTS_DIR}/dSYM"

    cp -r "${BUILT_PRODUCTS_DIR}/Products/${ARTEFACT_NAME}" "${RELEASE_PRODUCT_LOCATION}"

    echo ""
    echo ""
done

cp -r "${BUILT_PRODUCTS_DIR}/dSYM" "${RELEASE_DSYM_LOCATION}"

echo "####### Create package from build"

mkdir -p "${PKG_ROOT}/Library/Frameworks"
cp -r "${RELEASE_PRODUCT_LOCATION}/EasyLogin.framework" "${PKG_ROOT}/Library/Frameworks"

mkdir -p "${PKG_ROOT}/Library/OpenDirectory/Modules"
cp -r "${RELEASE_PRODUCT_LOCATION}/io.easylogin.EasyLoginOD.xpc" "${PKG_ROOT}/Library/OpenDirectory/Modules"

mkdir -p "${PKG_ROOT}/Library/LaunchDaemons"
cp -r "${PROJECT_DIR}/EasyLoginFrameworkForMac/EasyLoginDB/io.easylogin.EasyLoginDB.plist" "${PKG_ROOT}/Library/LaunchDaemons"
cp -r "${PROJECT_DIR}/EasyLoginAgentForMac/EasyLoginAgent/io.easylogin.EasyLoginAgent.plist" "${PKG_ROOT}/Library/LaunchDaemons"

mkdir -p "${PKG_ROOT}/Library/EasyLogin/db"
chmod 700 "${PKG_ROOT}/Library/EasyLogin/db"

mkdir -p "${PKG_ROOT}/Library/EasyLogin/Agent"
cp -r "${RELEASE_PRODUCT_LOCATION}/EasyLoginAgent.app" "${PKG_ROOT}/Library/EasyLogin/Agent"

mkdir -p "${PKG_ROOT}/usr/local/bin"
cp -r "${RELEASE_PRODUCT_LOCATION}/elctl" "${PKG_ROOT}/usr/local/bin"

#sudo chown -R root:wheel "${PKG_ROOT}"

pkgbuild --root "${PKG_ROOT}" --scripts "${PROJECT_DIR}/Distribution/pkg_scripts" --identifier "io.easylogin.EasyLoginForMac" --version "${PKG_VERSION}" "${RELEASE_LOCATION}/EasyLogin-${PKG_VERSION}.pkg"

rm -rf "${PKG_ROOT}"

echo "####### Cleaning temporary files"

rm -rf "${BUILT_PRODUCTS_DIR}"

exit 0
