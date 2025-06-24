#!/bin/bash

if [[ "$1" == "clean" ]] 
then

    [[ -d "localbuild" ]] && cd localbuild || exit 0
    OIFS="$IFS"
    IFS=$'\n'
    for mp in $(mount | grep "$(pwd)" |cut -d' ' -f3-|sed -E 's|(.*) type .*|\1|')
    do
        echo unbind ${mp}
        sudo umount "${mp}" || exit 1
    done
    IFS="$OIFS"
    cd ..

    sudo rm -rf localbuild/
    exit 0
fi

[[ ! -d "localbuild" ]] && mkdir localbuild

cd localbuild
OIFS="$IFS"
IFS=$'\n'
for mp in $(mount | grep "$(pwd)" |cut -d' ' -f3-|sed -E 's|(.*) type .*|\1|')
do
    echo unbind ${mp}
    sudo umount "${mp}" || exit 1
done
IFS="$OIFS"

prep() {
    echo prep
    export LatestArmbianVer=$(gh release list -R armbian/build |grep -v trunk | head -n1 |cut -f1)
    export LatestArmbianURL=https://github.com/armbian/build/archive/refs/tags/${LatestArmbianVer}.tar.gz
    echo LatestArmbianURL=$LatestArmbianURL
    wget -q -nv "$LatestArmbianURL" -O${LatestArmbianVer}.tar.gz
    tar --strip-components=1 --exclude=.gitignore --exclude=.git --exclude=README.md -xf ${LatestArmbianVer}.tar.gz
    rm -f ${LatestArmbianVer}.tar.gz
    #mkdir release
    [[ "$1" == "prep" ]] && exit 
}

#rebind
OIFS="$IFS"
IFS=$'\n'
for File2Bind in $(find .. -type f 2>/dev/null | grep -v -e "localbuild" -e "\.git" -e "\.github")
do
    File2Bind=$(echo ${File2Bind//\"/})
    File2Bind=$(echo ${File2Bind//..\//})
    #echo $File2Bind
    #echo 
    #echo mount --bind \"$(dirname $(pwd))/$File2Bind\" \"$(pwd)/$File2Bind\"
    [[ ! -d "$(dirname $(pwd)/$File2Bind)" ]] && mkdir -p "$(dirname $(pwd)/$File2Bind)"
    touch "$(pwd)/$File2Bind"
    sudo mount --bind "$(dirname $(pwd))/$File2Bind" "$(pwd)/$File2Bind"
done
IFS="$OIFS"

[[ "$1" == "prep" ]] && prep 

[[ ! -f "compile.sh" ]] && prep

now=$(date +%Y%m%d%H%M%S)
if [[ "$1" != "prep" && -n "$1" ]] 
then
    echo "making image(s): $@"
    for i in $@
    do
        rm -rf output/logs
        ./compile.sh $i
        img=$(find output -name "Armbian-*_R36s_*.img")
        log=$(find output -name log-build-*.log)
        id=$(echo $log| sed -E 's|.*log-build-(.*)\.log|\1|')
        
        #armbian-r36s-noble-minimal
        device=$(echo $i|cut -d- -f2)
        base=$(echo $i|cut -d- -f3)
        type=$(echo $i|cut -d- -f4)
        outdir=../localoutput/$now/$device/$base/$type

        [[ ! -d "$outdir" ]] && mkdir -p $outdir

        mv "$img" $outdir/armbian-${i}.img
        mv "$img.sha" $outdir/armbian-${i}.img.sha
        mv "$img.txt" $outdir/armbian-${i}.img.txt
        mv "output/logs/log-build-$id.log" $outdir/armbian-${i}-build.log
        mv "output/logs/log-docker-$id.log" $outdir/armbian-${i}-docker.log
        mv "output/logs/summary-build-$id.md" $outdir/armbian-${i}-build.summary
        mv "output/logs/summary-docker-$id.md" $outdir/armbian-${i}-docker.summary
    done
else 
    ls userpatches/config-r36s-* | cut -d'-' -f2-4| cut -d'.' -f1
fi


OIFS="$IFS"
IFS=$'\n'
for mp in $(mount | grep "$(pwd)" |cut -d' ' -f3-|sed -E 's|(.*) type .*|\1|')
do
    #echo unbind2 ${mp}
    sudo umount "${mp}" && rm ${mp} || exit 1
done
IFS="$OIFS"