#!/bin/bash

LOCAL_PHP_VER="7.3.6"
COMPILE_PHP="no"
DIR=$PWD
INSTALLATION_DIR="$DIR/install_data"
LOG="$DIR/install.log"

declare -A SUPPORT_PHP
SUPPORT_PHP["7.3.5"]="true"
SUPPORT_PHP["7.3.6"]="true"

rm $LOG -f 2>&1
touch $LOG

echo "Installing package..."
apt update >> $LOG 2>&1 && apt upgrade -y >> $LOG 2>&1
if [ $COMPILE_PHP == "yes" ]; then
        apt install -y libzip-dev bison autoconf build-essential pkg-config git-core libltdl-dev libbz2-dev libxml2-dev libxslt1-dev libssl-dev libicu-dev libpspell-dev libenchant-dev libmcrypt-dev libpng-dev libjpeg8-dev libfreetype6-dev libmysqlclient-dev libreadline-dev libcurl4-openssl-dev >> $LOG 2>&1
fi
apt install -y unzip >> $LOG 2>&1

read -p "PMMP가 설치된 경로를 입력해주세요: " pm_dir

if ! [ -d "$pm_dir" ] && ! [ -f "$pm_dir/start.sh" ]
then
    echo "경로가 존재하지 않습니다."
    exit 1
fi

chmod 777 -R $pm_dir/*

pm_dir="$(realpath $pm_dir)"

rm -r -f ./install_data/ >> $LOG 2>&1
mkdir ./install_data/ >> $LOG 2>&1
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
    if [ $COMPILE_PHP == "yes" ]; then
        compile_php $1
    else
        install_prebuilt_php $1
    fi
}
function compile_php() {
    echo "Downloading PHP $1..."
    curl -sL https://github.com/php/php-src/archive/php-$1.tar.gz -o php-$1.tar.gz
    tar --extract --gzip --file "php-$1.tar.gz"

    cd "php-src-php-$1/"
    ./buildconf --force >> $LOG 2>&1

    CONFIGURE_STRING="--prefix=/etc/php7 --with-bz2 --with-zlib --enable-zip --disable-cgi \
    --enable-soap --enable-intl --with-openssl --with-readline --with-curl --enable-ftp \
    --enable-mysqlnd --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --enable-sockets \
    --enable-pcntl --with-pspell --with-enchant --with-gettext --with-gd --enable-exif \
    --with-jpeg-dir --with-png-dir --with-freetype-dir --with-xsl --enable-bcmath \
    --enable-mbstring --enable-calendar --enable-simplexml --enable-json --enable-hash \
    --enable-session --enable-xml --enable-wddx --enable-opcache --with-pcre-regex \
    --with-config-file-path=/etc/php7/cli --with-config-file-scan-dir=/etc/php7/etc \
    --enable-cli --enable-fpm --with-fpm-user=www-data --with-fpm-group=www-data \
    --with-mcrypt --enable-sysvmsg --enable-sysvsem --enable-sysvshm --enable-shmop \
    --enable-pthreads --with-tsrm-pthreads --enable-maintainer-zts"

    echo "Configuring PHP..."
    ./configure $CONFIGURE_STRING >> $LOG 2>&1
    echo "Compiling PHP..."
    make -j4 >> $LOG 2>&1
    echo "Installing PHP..."
    make install >> $LOG 2>&1

    chmod o+x /etc/php7/bin/phpize
    chmod o+x /etc/php7/bin/php-config

    echo "Installing pthreads..."
    git clone https://github.com/krakjoe/pthreads.git >> $LOG 2>&1

    cd pthreads
    /etc/php7/bin/phpize >> $LOG 2>&1
    ./configure --prefix='/etc/php7' --with-libdir='/lib/x86_64-linux-gnu' --enable-pthreads=shared --with-php-config='/etc/php7/bin/php-config' >> $LOG 2>&1
    make -j4 >> $LOG 2>&1
    make install >> $LOG 2>&1

    cd ..
    mkdir -p /etc/php7/cli/
    cp php.ini-production /etc/php7/cli/php.ini

    echo "extension=pthreads.so" >> /etc/php7/cli/php.ini
    echo "zend_extension=opcache.so" >> /etc/php7/cli/php.ini

    rm /usr/local/bin/php /usr/local/bin/php-config /usr/local/bin/phpize >> $LOG 2>&1
    cp /etc/php7/bin/php /usr/local/bin/php
    cp /etc/php7/bin/php-config /usr/local/bin/php-config
    cp /etc/php7/bin/phpize /usr/local/bin/phpize

    echo "Installing mcrypto..."
    git clone https://github.com/php/pecl-encryption-mcrypt.git >> $LOG 2>&1
    cd pecl-encryption-mcrypt
    /etc/php7/bin/phpize >> $LOG 2>&1
    ./configure --prefix='/etc/php7' --with-libdir='/lib/x86_64-linux-gnu' --with-php-config='/etc/php7/bin/php-config' --enable-mcrypt=shared >> $LOG 2>&1
    make -j4 >> $LOG 2>&1
    make install >> $LOG 2>&1
    echo "extension=mcrypt.so" >> /etc/php7/cli/php.ini
}

function install_prebuilt_php() {
    local ver=$1
    echo "Downloading prebuilt PHP Binary..."
    curl -sL "https://github.com/nnnlog/pmmp.me/raw/master/PHP_$ver/PHP_local_$ver.zip" -o php7.zip 2>&1
    unzip -qq php7.zip
    cp ./php7/ /etc/ -r 2>&1
    chmod 777 -R /etc/php7/*

    rm /usr/local/bin/php /usr/local/bin/php-config /usr/local/bin/phpize >> $LOG 2>&1
    cp /etc/php7/bin/php /usr/local/bin/php
    cp /etc/php7/bin/php-config /usr/local/bin/php-config
    cp /etc/php7/bin/phpize /usr/local/bin/phpize
}

function change_php_binary() {
    local ver=$1
    echo "Change PocketMine PHP Binary..."
    curl -sL "https://github.com/nnnlog/pmmp.me/raw/master/PHP_$ver/PHP_PM_$ver.zip" -o bin.zip
    unzip -qq bin.zip
    rm -r -f "$pm_dir/bin/"
    cp -r "./bin/" "$pm_dir/"
}

if ! [ -x "$(command -v php)" ]; then
    install_php $LOCAL_PHP_VER
else
    get_php_version 'php' PHP_VER
    enabled_ZTS 'php' PHP_TS

    if [ "$PHP_VER" != "$LOCAL_PHP_VER" ] || [ "$PHP_TS" != "ZTS" ] || ! [ ${SUPPORT_PHP[$PHP_VER]+_} ]; then
        install_php "$LOCAL_PHP_VER"
    fi
fi

get_php_version 'php' PHP_VER
enabled_ZTS 'php' PHP_TS

if ! [ -f "$pm_dir/start.sh" ]; then
    change_php_binary "$PHP_VER"
fi

get_php_version "$pm_dir/bin/php7/bin/php" PM_PHP_VER
enabled_ZTS "$pm_dir/bin/php7/bin/php" PM_PHP_TS

if [ "$PHP_VER" != "$PM_PHP_VER" ] || [ "$PHP_TS" != "$PM_PHP_TS" ] || ! [ ${SUPPORT_PHP[$PM_PHP_VER]+_} ]; then
    change_php_binary "$PHP_VER"
fi

chmod 777 -R $pm_dir/*

echo "Download PHP-CPP..."
cd ../../
git clone https://github.com/CopernicaMarketingSoftware/PHP-CPP/ >> $LOG 2>&1
cd PHP-CPP/
echo "Compiling PHP-CPP..."
make -j4 >> $LOG 2>&1
make install >> $LOG 2>&1

echo "Downloading PluginManagement extension..."
curl -sL "https://github.com/nnnlog/pmmp.me/raw/master/PHP_$PHP_VER/PluginManagement.so" -o "PluginManagement.so"

echo "'$($pm_dir/bin/php7/bin/php-config --extension-dir)'에 PluginManagement Extension 이 저장됩니다..."
mkdir -p "$($pm_dir/bin/php7/bin/php-config --extension-dir)"
cp "PluginManagement.so" "$($pm_dir/bin/php7/bin/php-config --extension-dir)"

res="$(find $pm_dir/bin/php7/bin/php.ini -type f -print | xargs grep 'extension=PluginManagement')"

if [ ${#res} -lt 1 ]; then
    echo "extension=PluginManagement" >> "$pm_dir/bin/php7/bin/php.ini"
fi


cd ../
rm -r -f ./install_data/ >> $LOG 2>&1