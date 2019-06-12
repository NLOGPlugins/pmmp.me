#!/bin/bash

LOCAL_PHP_VER="7.3.6"
DIR=$PWD
INSTALLATION_DIR="$DIR/install_data"
LOG="$DIR/install.log"

rm $LOG -f 2>&1
touch $LOG

SYSTEM_PHP="$INSTALLATION_DIR/PHP_local_$LOCAL_PHP_VER.zip"
PM_PHP="$INSTALLATION_DIR/PHP_PM_$LOCAL_PHP_VER.zip"
PHP_CPP_SRC="$INSTALLATION_DIR/PHP-CPP-master.zip"
SO_FILE="$INSTALLATION_DIR/PluginManagement.so"

if ! [ -f "$PM_PHP" ] && ! [ -f "$SYSTEM_PHP" ]
then
    echo "https://github.com/nnnlog/pmmp.me 에서 PHP 파일을 다운로드해주세요."
    echo "파일은 install_data 폴더에 넣어주셔야 합니다."
    exit 1
fi

if ! [ -f "$PHP_CPP_SRC" ]
then
    echo "https://github.com/CopernicaMarketingSoftware/PHP-CPP/archive/master.zip 에서 Zip 파일을 다운로드해주세요."
    echo "파일은 install_data 폴더에 넣어주셔야 합니다."
    exit 1
fi

if ! [ -f "$SO_FILE" ]
then
    echo "https://github.com/CopernicaMarketingSoftware/PHP-CPP/archive/master.zip 에서 PluginManagement.so를 다운로드해주세요."
    echo "파일은 install_data 폴더에 넣어주셔야 합니다."
    exit 1
fi

SYSTEM_PHP="$(realpath $SYSTEM_PHP)"
PM_PHP="$(realpath $PM_PHP)"
PHP_CPP_SRC="$(realpath $PHP_CPP_SRC)"
SO_FILE="$(realpath $SO_FILE)"

echo "Installing package..."
apt update >> $LOG 2>&1 && apt upgrade -y >> $LOG 2>&1
apt install -y unzip make >> $LOG 2>&1

read -p "PMMP가 설치된 경로를 입력해주세요: " pm_dir

if ! [ -d "$pm_dir" ] && ! [ -f "$pm_dir/bin/php7/bin" ]
then
    echo "경로가 존재하지 않습니다."
    exit 1
fi

chmod 777 -R $pm_dir/*

pm_dir="$(realpath $pm_dir)"

cd ./install_data/

function get_php_version() {
    local -n ref=$2
    chmod 777 -R $pm_dir/*
    local PHP="$($1 -r 'echo PHP_EOL . PHP_VERSION;' 2>&1)"
    ref="${PHP##*$'\n'}"
}

function enabled_ZTS() {
    local -n ref=$2
    chmod 777 -R $pm_dir/*
    local PHP="$($1 -r 'echo PHP_EOL . PHP_ZTS;' 2>&1)"
    ref="${PHP##*$'\n'}"
    if [ $ref == "1" ]; then
        ref="ZTS"
    else
        ref="NTS"
    fi
}

function install_php() {
    install_prebuilt_php
}

function install_prebuilt_php() {
    echo "Applying prebuilt PHP Binary..."
    unzip -qq $SYSTEM_PHP
    mv ./php7/ /etc/ 2>&1
    chmod 777 -R /etc/php7/*

    rm /usr/local/bin/php /usr/local/bin/php-config /usr/local/bin/phpize >> $LOG 2>&1
    cp /etc/php7/bin/php /usr/local/bin/php
    cp /etc/php7/bin/php-config /usr/local/bin/php-config
    cp /etc/php7/bin/phpize /usr/local/bin/phpize
}

function change_php_binary() {
    echo "Applying PocketMine PHP Binary..."
    unzip -qq $PM_PHP
    rm -r -f "$pm_dir/bin/"
    mv "./bin/" "$pm_dir/"
}



if ! [ -x "$(command -v php)" ]; then
    install_php
else
    get_php_version 'php' PHP_VER
    enabled_ZTS 'php' PHP_TS

    if [ "$PHP_VER" != "$LOCAL_PHP_VER" ] || [ "$PHP_TS" != "ZTS" ]; then
        install_php
    fi
fi

get_php_version 'php' PHP_VER
enabled_ZTS 'php' PHP_TS

if ! [ -f "$pm_dir/bin/php7/bin/php" ]; then
    change_php_binary "$PHP_VER"
fi

get_php_version "$pm_dir/bin/php7/bin/php" PM_PHP_VER

if [ "$PHP_VER" != "$PM_PHP_VER" ] || [ "$PHP_TS" != "ZTS" ]; then
    change_php_binary
fi

chmod 777 -R $pm_dir/*

rm PHP-CPP-master/ -r -f
echo "Installing PHP-CPP..."
unzip -qq $PHP_CPP_SRC
chmod 777 -R ./*
cd PHP-CPP-master/
echo "Compiling PHP-CPP..."
make -j4 >> $LOG 2>&1
make install >> $LOG 2>&1

cd ../
echo "Copying PluginManagement extension..."

echo "'$($pm_dir/bin/php7/bin/php-config --extension-dir)'에 PluginManagement Extension 이 저장됩니다..."
mkdir -p "$($pm_dir/bin/php7/bin/php-config --extension-dir)"
cp "PluginManagement.so" "$($pm_dir/bin/php7/bin/php-config --extension-dir)"

res="$(find $pm_dir/bin/php7/bin/php.ini -type f -print | xargs grep 'extension=PluginManagement')"

if [ ${#res} -lt 1 ]; then
    echo "extension=PluginManagement" >> "$pm_dir/bin/php7/bin/php.ini"
fi


cd ../