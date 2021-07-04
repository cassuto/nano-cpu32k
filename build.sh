#!/bin/bash

help() {
    echo "Usage:"
    echo "build.sh [-b] [-s] [-w filename] [-c]"
    echo "Description:"
    echo "-b: Build project."
    echo "-s: Run simulation program."
    echo "-w: Open the waveform file using gtkwave."
    echo "-c: Clean project."
    exit -1
}

CLEAN="false"
BUILD="false"
DEMO="false"
SUMULATE="false"
CHECK_WAVE="false"

while getopts 'hbsw:d:c' OPT; do
    case $OPT in
        s) SUMULATE="true";;
        b) BUILD="true";;
        w) CHECK_WAVE="true"; WAVE_FILE="$OPTARG";;
        d) DEMO="true"; DEMO_PATH="$OPTARG";;
        c) CLEAN="true";;
        h) help;;
        ?) help;;
    esac
done

SHELL_PATH=$(dirname $(readlink -f "$0"))
MYINFO_FILE=$SHELL_PATH/myinfo.txt
V_TOP_FILE=top.v
EMU_FILE=emu
BUILD_FOLDER=build

if [ "$DEMO" == "true" ]; then
    SRC_PATH=$SHELL_PATH/examples/$DEMO_PATH
else
    SRC_PATH=$SHELL_PATH/cpu
fi
BUILD_PATH=$SRC_PATH/build

# get id and name
MYINFO_ERR="Please fill your information in myinfo.txt!!!"
ID=`sed '/^ID=/!d;s/.*=//' $MYINFO_FILE`
NAME=`sed '/^Name=/!d;s/.*=//' $MYINFO_FILE`
if [[ ! $ID ]] || [[ ! $NAME ]]; then  
  echo $MYINFO_ERR
  exit 1
fi
ID="${ID##*\r}"
NAME="${NAME##*\r}"

# clean
if [ "$CLEAN" == "true" ]; then
    rm -rf $BUILD_PATH
    exit 0
fi

echo $BUILD_PATH
# build
if [ "$BUILD" == "true" ]; then
    cd $SRC_PATH
    CPP_SRC=`find . -maxdepth 1 -name "*.cpp"`
    echo $CPP_SRC
    verilator -Wall --cc --exe -o $EMU_FILE --trace -Mdir ./$BUILD_FOLDER --build $V_TOP_FILE $CPP_SRC
    if [ $? -ne 0 ]; then
        echo "Failed to run verilator!!!"
        exit 1
    fi
    cd $SHELL_PATH

    # git commit
    git add . -A --ignore-errors
    (echo $NAME && echo $ID && hostnamectl && uptime) | git commit -F - -q --author='tracer-oscpu2021 <tracer@oscpu.org>' --no-verify --allow-empty 1>/dev/null 2>&1
    sync
fi

# simulate
if [ "$SUMULATE" == "true" ]; then
    echo "Simulating..."
    cd $BUILD_PATH
    ./$EMU_FILE
    if [ $? -ne 0 ]; then
        echo "Failed to simulate!!!"
        exit 1
    fi
    cd $SHELL_PATH
fi

# check waveform
if [ "$CHECK_WAVE" == "true" ]; then
    cd $BUILD_PATH
    gtkwave $WAVE_FILE
    if [ $? -ne 0 ]; then
        echo "Failed to run gtkwave!!!"
        exit 1
    fi
    cd $SHELL_PATH
fi
