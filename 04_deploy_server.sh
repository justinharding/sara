#! /bin/bash
#
# SARA - Sentinel Australasia Regional Access
# 
# Deployment script
#
# Author : Jérôme Gasperi (https://github.com/jjrom)
# Date   : 2017.02.19
#
#
#CONFIG=config
FORCE=NO
WWW_USER=nginx:nginx
PWD=`pwd`
SRC_DIR=`pwd`
LOCALHOST=localhost
function showUsage {
    echo ""
    echo "   SARA - Sentinel Australasia Regional Access server deployment"
    echo ""
    echo "   Usage $0 [options]"
    echo ""
    echo "      -C | --config : local config file containing parameters to build config.php file"
    echo "      -F | --force : force suppression of endpoint directory (i.e. ${SARA_SERVER_TARGET_DIR}/${SARA_SERVER_VERSION_ENDPOINT} and ${SARA_CLIENT_TARGET_DIR})"
    echo "      -h | --help : show this help"
    echo ""
    echo ""
}

# Parsing arguments
while [[ $# > 0 ]]
do
	key="$1"

	case $key in
        -C|--config)
            CONFIG="$2"
            shift # past argument
            ;;
        -F|--force)
            FORCE=YES
            shift # past argument
            ;;
        -h|--help)
            showUsage
            exit 0
            shift # past argument
            ;;
            *)
        shift # past argument
        # unknown option
        ;;
	esac
done

if [ "${CONFIG}" == "" ]
then
    showUsage
    echo ""
    echo "   ** Missing mandatory config file ** ";
    echo ""
    exit 0
fi

# Source config file
. ${CONFIG}

# Set endpoints
SARA_SERVER_ENDPOINT=${SARA_SERVER_TARGET_DIR}${SARA_SERVER_VERSION_ENDPOINT}

if [ "${FORCE}" == "YES" ]
then
  echo " ==> Suppress ${SARA_SERVER_ENDPOINT}"
  rm -Rf ${SARA_SERVER_ENDPOINT}
fi

mkdir -p ${SARA_SERVER_TARGET_DIR}

echo " ==> Deploy resto in ${SARA_SERVER_ENDPOINT}"
${SRC_DIR}/resto/_install/deploy.sh -s ${SRC_DIR}/resto -t ${SARA_SERVER_ENDPOINT}

# Fix RewriteBase path
ESCAPED_SARA_PATH=$(echo "${SARA_SERVER_SUB}${SARA_SERVER_VERSION_ENDPOINT}" | sed -r -e 's/\//\\\//g')
sed -i -r -e "s/\/resto\//${ESCAPED_SARA_PATH}\//g" ${SARA_SERVER_ENDPOINT}/.htaccess

echo " ==> Copy models under ${SARA_SERVER_ENDPOINT}/include/resto/Models"
cp -R ${SRC_DIR}/sara.server/Models/*.php ${SARA_SERVER_ENDPOINT}/include/resto/Models/

echo " ==> Use ${CONFIG} file to generate ${SARA_SERVER_ENDPOINT}/include/config.php";
${SRC_DIR}/sara.server/generate_config.sh -C ${CONFIG} > ${SARA_SERVER_ENDPOINT}/include/config.php
chmod 0600 ${SARA_SERVER_ENDPOINT}/include/config.php

echo " ==> Set ${SARA_SERVER_ENDPOINT} rights to ${WWW_USER}"
chown -R ${WWW_USER} ${SARA_SERVER_ENDPOINT}

echo " ==> Update property mappings for collections"

# change JSON file properties
for i in {1..3};do 
	fileName=${SRC_DIR}/sara.server/collections/"S$i.json"; 
        outName=${SRC_DIR}/sara.server/collections/"SARA-S$i.json";
	awk -v SEN=$i -v PATH=$DATA_ROOT_PATH -v PROTO=$SERVER_PROTOCOL -v SERVER=$SARA_SERVER_URL '{if((/"quicklook"/)||(/"thumbnail"/)||(/"resource"/)){if(/"resource"/){print "\t\"resource\" : \""PATH"Sentinel-"SEN"{:resource:}/{:productIdentifier:}.zip\""}; if(/"quicklook"/){print "\t\"quicklook\" : \""PROTO"://"SERVER"/data/Sentinel-"SEN"{:resource:}/{:productIdentifier:}.png\","}; if(/"thumbnail"/){print "\t\"thumbnail\" : \""PROTO"://"SERVER"/data/Sentinel-"SEN"{:resource:}/{:productIdentifier:}.png\","};}else{print $0;}}' $fileName > $outName; done

if [ "${SERVER_PROTOCOL}" == "https" ]
then
    curlcmd="curl -k"
else
    curlcmd="curl"
fi

echo " ==> Install S1 collection"
$curlcmd -X POST -H "Content-Type: application/json" -d @${SRC_DIR}/sara.server/collections/SARA-S1.json ${SERVER_PROTOCOL}://${RESTO_ADMIN_USER}:${RESTO_ADMIN_PASSWORD}@${LOCALHOST}${SARA_SERVER_SUB}${SARA_SERVER_VERSION_ENDPOINT}/collections
echo ""

echo " ==> Install S2 collection"
$curlcmd -X POST -H "Content-Type: application/json" -d @${SRC_DIR}/sara.server/collections/SARA-S2.json ${SERVER_PROTOCOL}://${RESTO_ADMIN_USER}:${RESTO_ADMIN_PASSWORD}@${LOCALHOST}${SARA_SERVER_SUB}${SARA_SERVER_VERSION_ENDPOINT}/collections
echo ""

echo " ==> Install S3 collection"
$curlcmd -X POST -H "Content-Type: application/json" -d @${SRC_DIR}/sara.server/collections/SARA-S3.json ${SERVER_PROTOCOL}://${RESTO_ADMIN_USER}:${RESTO_ADMIN_PASSWORD}@${LOCALHOST}${SARA_SERVER_SUB}${SARA_SERVER_VERSION_ENDPOINT}/collections
echo ""

echo " Done !"
