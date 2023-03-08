#!/bin/bash
CRTDIR=$(pwd)
base=$1
profile=$2
ui=$3
glversion1=$4
glversion2=$5

istore=$6
isdocker=$7

echo $base
if [ ! -e "$base" ]; then
    echo "Please enter base folder"
    exit 1
else
    if [ ! -d $base ]; then
        echo "Openwrt base folder not exist"
        exit 1
    fi
fi

if [ ! -n "$profile" ]; then
    profile=target_wlan_ap-gl-ax1800
fi

if [ ! -n "$ui" ]; then
    ui=true
fi

if [ ! -n "$istore" ]; then
    istore=true
fi

if [ ! -n "$isdocker" ]; then
    isdocker=true
fi

echo "Start..."



#clone source tree
git clone https://github.com/gl-inet/gl-infra-builder.git $base/gl-infra-builder
cp -r custom/ $base/gl-infra-builder/feeds/custom/
cp -r *.yml $base/gl-infra-builder/profiles
cd $base/gl-infra-builder

# Modify default IP 没用?
# sed -i 's/192.168.8.1/192.168.31.2/g' patches-siflower-18.x/0103-fix-modify-the-Siflower-SDK-according-to-the-feature.patch

function build_firmware() {
    cd ~/openwrt
    need_gl_ui=$1
    ui_path=$2
    # fix helloword build error
    rm -rf feeds/packages/lang/golang
    svn co https://github.com/openwrt/packages/branches/openwrt-22.03/lang/golang feeds/packages/lang/golang
    #install feed
    ./scripts/feeds update -a && ./scripts/feeds install -a && make defconfig
    #build
    if [[ $need_gl_ui == true ]]; then
        make -j$(expr $(nproc) + 1) GL_PKGDIR=~/glinet/$ui_path/ V=s
    else
        make -j$(expr $(nproc) + 1) V=s
    fi
    return
}

function copy_file() {
    path=$1
    mkdir ~/firmware
    mkdir ~/packages
    cd $path
    rm -rf packages
    cp -rf ./* ~/firmware
    cp -rf ~/openwrt/bin/packages/* ~/packages
    return
}

case $profile in
target_wlan_ap-gl-ax1800 | \
    target_wlan_ap-gl-axt1800 | \
    target_wlan_ap-gl-ax1800-5-4 | \
    target_wlan_ap-gl-axt1800-5-4)
    if [[ $profile == *5-4* ]]; then
        python3 setup.py -c configs/config-wlan-ap-5.4.yml
    else
        python3 setup.py -c configs/config-wlan-ap.yml
    fi
    ln -s $base/gl-infra-builder/wlan-ap/openwrt ~/openwrt && cd ~/openwrt
    if [[ $ui == true ]]; then
        ./scripts/gen_config.py $profile glinet_depends glinet_nas custom
        git clone https://github.com/gl-inet/glinet4.x.git ~/glinet
    else
        ./scripts/gen_config.py $profile openwrt_common glinet_nas luci custom
    fi
    build_firmware $ui ipq60xx && copy_file ~/openwrt/bin/targets/*/*
    ;;
target_ipq40xx_gl-a1300)
    python3 setup.py -c configs/config-21.02.2.yml
    ln -s $base/gl-infra-builder/openwrt-21.02/openwrt-21.02.2 ~/openwrt && cd ~/openwrt
    if [[ $ui == true ]]; then
        ./scripts/gen_config.py $profile glinet_depends glinet_nas custom
        git clone https://github.com/gl-inet/glinet4.x.git ~/glinet
    else
        ./scripts/gen_config.py $profile openwrt_common glinet_nas luci custom
    fi
    build_firmware $ui ipq40xx && copy_file ~/openwrt/bin/targets/*/*
    ;;
target_mt7981_gl-mt2500 | \
    target_mt7981_gl-mt3000)
    python3 setup.py -c configs/config-mt798x-7.6.6.1.yml
    ln -s $base/gl-infra-builder/mt7981 ~/openwrt && cd ~/openwrt

    if [[ $istore == true ]]; then
        xadd="istore"
    else
        xadd=""
        #luci-theme-argon
        git clone --depth 1 https://github.com/jerrykuku/luci-theme-argon.git package/luci-theme-argon
        git clone --depth 1 https://github.com/jerrykuku/luci-app-argon-config.git package/luci-app-argon-config
    fi

    if [[ $isdocker == true ]]; 
    then
        xadd="$xadd docker"
    fi

    #luci-app-pushbot
    # git clone https://github.com/zzsj0928/luci-app-pushbot package/luci-app-pushbot

    #自定义
    svn export https://github.com/tty228/luci-app-serverchan/trunk package/luci-app-serverchan
    svn export https://github.com/AoThen/luci-app-broadbandacc/trunk package/luci-app-broadbandacc
    
    # svn export https://github.com/zzsj0928/luci-app-pushbot/trunk package/luci-app-pushbot     CONFIG_PACKAGE_luci-app-pushbot=y

    if [[ $istore != true ]]; 
    then
        svn export https://github.com/sirpdboy/netspeedtest/trunk package/netspeedtest
    fi


    if [[ $ui == true ]]; then
        ./scripts/gen_config.py $profile glinet_depends glinet_nas custom $xadd
        git clone https://github.com/gl-inet/glinet4.x.git ~/glinet
        # cd ~/glinet
        # git reset --hard 8e665c49ca24550c53ba95bf6b705783cff90dc1
        # cd ..
        if [[ $profile == *mt3000* ]]; then
            cp -rf ~/glinet/pkg_config/gl_pkg_config_mt7981_mt3000.mk ~/glinet/mt7981/gl_pkg_config.mk
        else
            cp -rf ~/glinet/pkg_config/gl_pkg_config_mt7981_mt2500.mk ~/glinet/mt7981/gl_pkg_config.mk
        fi
    else
        ./scripts/gen_config.py $profile glinet_nas custom $xadd
    fi
    #####自定义↓↓↓

    #luci-app-alist （在 ./scripts/feeds install -a 操作之后更换 golang 版本）
    # rm -rf feeds/packages/lang/golang
    # svn export https://github.com/sbwml/packages_lang_golang/branches/19.x feeds/packages/lang/golang
    # git clone --depth 1 https://github.com/sbwml/luci-app-alist package/alist

    #版本信息
    echo $glversion1 >files/etc/glversion
    echo $glversion2 >files/etc/version.type
    #####自定义↑↑↑
    build_firmware $ui mt7981 && copy_file ~/openwrt/bin/targets/*/*
    ;;
target_siflower_gl-sf1200 | \
    target_siflower_gl-sft1200)
    python3 setup.py -c configs/config-siflower-18.x.yml
    ln -s $base/gl-infra-builder/openwrt-18.06/siflower/openwrt-18.06 ~/openwrt && cd ~/openwrt
    ./scripts/gen_config.py $profile glinet_nas custom
    build_firmware && copy_file ~/openwrt/bin/targets/*
    ;;
target_ramips_gl-mt1300)
    python3 setup.py -c configs/config-22.03.0.yml
    ln -s $base/gl-infra-builder/openwrt-22.03/openwrt-22.03.0 ~/openwrt && cd ~/openwrt
    ./scripts/gen_config.py $profile glinet_nas luci custom
    build_firmware && copy_file ~/openwrt/bin/targets/*/*
    ;;
esac
