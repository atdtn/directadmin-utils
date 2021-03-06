#!/bin/bash
#
# A script to install/update/remove pecl extension
# for all installed by CustomBuild 2.x PHP versions
# Written by Alex Grebenschikov(support@poralix.com)
#
# =====================================================
# versions: 0.4-beta $ Tue May 15 14:08:57 +07 2018
#           0.3-beta $ Wed May  2 20:36:54 +07 2018
#           0.2-beta $ Tue Mar 17 12:40:51 NOVT 2015
# =====================================================
#set -x

PWD=`pwd`;
WORKDIR="/usr/local/src";
PECL=`ls -1 /usr/local/php*/bin/pecl | head -1`;
LANG=C;
FILE="";
EXT="";
PHPVER="";
BN="`tput -Txterm bold`"
BF="`tput -Txterm sgr0`"

function do_usage()
{
    echo "
# ===================================================== #
# A script to install/update/remove pecl extension      #
# for all installed by CustomBuild 2.x PHP versions     #
# Written by Alex Grebenschikov(support@poralix.com)    #
# Version: 0.4-beta $ Tue May 15 14:08:57 +07 2018      #
# ===================================================== #

Usage:

$0 <command> <pecl_extension> [<php-version>]

        Supported commands:

            install - to install extension
            remove  - to remove extension

        php-version - digits only (only one version at a time):

            52, 53, 54, 55, 56, 70, 71, 72, etc
";

    exit 1;
}

function do_update()
{
    tmpdir=`mktemp -d ${WORKDIR}/tmp.XXXXXXXXXX`;
    PHPIZE=$1;
    if [ -x "${PHPIZE}" ];
    then
    {
        PHPVER=`echo ${PHPIZE} | cut -d\/ -f4`
        echo "${BN}Installing ${EXT} for ${PHPVER}${BF}";
        PHPDIR=`dirname ${PHPIZE}`;
        cd ${WORKDIR};
        rm -rfv ${tmpdir}/*;
        tar -zxvf ${FILE} --directory=${tmpdir};
        DIR=`ls -1d ${tmpdir}/${EXT}* | head -1`;
        if [ -d "${DIR}" ];
        then
        {
            cd ${DIR};
            ${PHPIZE};
            ./configure --with-php-config=${PHPDIR}/php-config;
            RETVAL=$?;
            if [ "${RETVAL}" == "0" ];
            then
            {
                make && make install;
                RETVAL=$?;
                if [ "${RETVAL}" == "0" ];
                then
                {
                    echo "${BN}[OK] Installation of ${EXT} for ${PHPVER} completed!${BF}";
                }
                else
                {
                    echo "${BN}[ERROR] Installation of ${EXT} for ${PHPVER} failed${BF}";
                }
                fi;
                echo -ne '\007';
            }
            else
            {
                echo "${BN}[ERROR] Configure of ${EXT} failed${BF}";
            }
            fi;
        }
        fi;
    }
    else
    {
        echo "ERROR! Executable ${PHPIZE} not found!";
        exit 1;
    }
    fi;
    rm -rf ${tmpdir};
}

do_update_ini()
{
    EXT_DIR=$(/usr/local/${1}/bin/php -i 2>&1 | grep ^extension_dir | awk '{print $3}');
    INI_DIR="/usr/local/${1}/lib/php.conf.d";
    INI_FILE="${INI_DIR}/99-custom.ini";
    [ -f "${INI_FILE}" ] || INI_FILE="/usr/local/${1}/lib/php.conf.d/90-custom.ini";
    ROW="extension=${EXT}.so";

    if [ -f "${EXT_DIR}/${EXT}.so" ];
    then
    {
        echo "${BN}[OK] Found ${EXT}.so. Enabling the extension in ${INI_FILE}${BF}";
        grep -m1 -q "^${ROW}" "${INI_FILE}" || echo "${ROW}" >> ${INI_FILE};
        /usr/local/${1}/bin/php -i 2>&1 | grep -i "^${EXT}" | grep -v 'Configure Command' | head -3;
    }
    else
    {
        for INI_FILE in `ls -1 ${INI_DIR}/*.ini`;
        do
            echo "${BN}[ERROR] Could not find ${EXT_DIR}/${EXT}.so. Removing extension from ${INI_FILE}${BF}";
            grep -m1 -q "^${ROW}" "${INI_FILE}" &&  perl -pi -e  "s#^${ROW}##" ${INI_FILE};
        done;
    }
    fi;
}


verify_php_version()
{
    if [ -n "${PVN}" ];
    then
    {
        if [ -d "/usr/local/php${PVN}" ] && [ -f "/usr/local/php${PVN}/bin/php" ];
        then
        {
            PHPVER="php${PVN}";
        }
        else
        {
            echo "${BN}[ERROR] PHP version php${PVN} was not found!${BF}";
            exit 2;
        }
        fi;
    }
    fi;
}


do_remove()
{
    verify_php_version;
    if [ -n "${PVN}" ]; then
    {
        PHP_VERSIONS="${PVN}";
    }
    else
    {
        PHP_VERSIONS=`ls -1 /usr/local/php*/bin/php | sort -n | egrep -o '(5|7)[0-9]+' | xargs`;
    }
    fi;

    for PHP_VERSION in ${PHP_VERSIONS};
    do
    {
        PHPVER="php${PHP_VERSION}";

        EXT_DIR=$(/usr/local/${PHPVER}/bin/php -i 2>&1 | grep ^extension_dir | awk '{print $3}');
        EXT_FILE="${EXT_DIR}/${EXT}.so";
        if [ -f "${EXT_FILE}" ]; then
        {
            rm -f "${EXT_FILE}";
            echo "${BN}[OK] The extension ${EXT} for PHP ${PHP_VERSION} found! Removing it...${BF}";
        }
        else
        {
            echo "${BN}[Warning] The extension ${EXT} for PHP ${PHP_VERSION} not found! Nothing to disable...${BF}";
        }
        fi;
        do_update_ini ${PHPVER} >/dev/null 2>&1;
        cat ${INI_FILE};
    }
    done;
}

do_install()
{
    verify_php_version;

    cd ${WORKDIR};

    if [ -x "${PECL}" ];
    then
    {
        tmpfile=$(mktemp ${WORKDIR}/tmp.XXXXXXXXXX);
        ${PECL} channel-update pecl.php.net;
        ${PECL} download ${EXT} 2>&1 | tee ${tmpfile};
        FILE=$(cat ${tmpfile} | grep ^File | grep downloaded | cut -d\  -f2);
        rm -f ${tmpfile};
    }
    else
    {
        echo "${BN}[ERROR] No pecl found in ${PECL}${BF}";
        exit 1;
    }
    fi;

    if [ -f "${FILE}" ]
    then
    {
        if [ -z "${PHPVER}" ];
        then
        {
            for PHPIZE in `ls -1 /usr/local/php*/bin/phpize`;
            do
            {
                PHPVER=$(echo ${PHPIZE} | grep -o "[0-9]*");
                do_update ${PHPIZE};
                do_update_ini ${PHPVER};
            }
            done;
        }
        else
        {
            do_update /usr/local/${PHPVER}/bin/phpize;
            do_update_ini ${PHPVER};
        }
        fi;
    }
    else
    {
        echo "Failed to download a file";
        exit 2;
    }
    fi;

    [ -d "${PWD}" ] && cd ${PWD};
}

CMD="${1}";
EXT="${2}";
PVN=`echo "${3}" | egrep -o '^(5|7)[0-9]+'`;

[ "${PVN}" == "${3}" ] || do_usage;
[ -n "${CMD}" ] || do_usage;
[ -n "${EXT}" ] || do_usage;

case "${CMD}" in
    install)
        do_install;
    ;;
    remove)
        do_remove;
    ;;
    *)
        do_usage;
    ;;
esac;


exit 0;
