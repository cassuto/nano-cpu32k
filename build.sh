#!/bin/bash

VERSION="1.4"

help() {
    echo "Version v"$VERSION
    echo "Usage:"
    echo "build.sh [-e project_name] [-b] [-t top_file] [-s] [-a parameters_list] [-f] [-l] [-g] [-w] [-c] [-d] [-m]"
    echo "Description:"
    echo "-e: Specify a example project. For example: -e counter. If not specified, the default directory \"cpu\" will be used."
    echo "-b: Build project using verilator and make tools automatically. It will generate the \"build\"(difftest) or \"build_test\" subfolder under the project directory."
    echo "-t: Specify a file as verilog top file. If not specified, the default filename \"top.v\" will be used. This option is invalid when connected difftest."
    echo "-s: Run simulation program. Use the \"build_test\" or \"build\"(difftest) folder as work path."
    echo "-a: Parameters passed to the simulation program. For example: -a \"1 2 3 ......\". Multiple parameters require double quotes."
    echo "-f: C++ compiler arguments for makefile. For example: -f \"-DGLOBAL_DEFINE=1 -ggdb3\". Multiple parameters require double quotes. This option is invalid when connected difftest."
    echo "-l: C++ linker arguments for makefile. For example: -l \"-ldl -lm\". Multiple parameters require double quotes. This option is invalid when connected difftest."
    echo "-g: Debug the simulation program with GDB."
    echo "-w: Open the latest waveform file(.vcd) using gtkwave under work path. Use the \"build_test\" or \"build\"(difftest) folder as work path."
    echo "-c: Delete \"build\" and \"build_test\" folders under the project directory."
    echo "-d: Connect to XiangShan difftest framework."
    echo "-m: Parameters passed to the difftest makefile. For example: -m \"EMU_TRACE=1 EMU_THREADS=4\". Multiple parameters require double quotes."
    exit 0
}

create_soft_link() {
    mkdir ${1} 1>/dev/null 2>&1
    find -L ${1} -type l -delete
    FILES=`eval "find ${2} -name ${3}"`
    for FILE in ${FILES[@]}
    do
        eval "ln -s \"`realpath --relative-to="${1}" "$FILE"`\" \"${1}/${FILE##*/}\" 1>/dev/null 2>&1"
    done
}

build_diff_proj() {
    # Refresh the modification time of the top file, otherwise some changes to the RTL source code will not take effect in next compilation.
    touch -m `find $PROJECT_PATH/$VSRC_FOLDER/ -name $DIFFTEST_TOP_FILE`
    # create soft link ($BUILD_PATH/*.v -> $PROJECT_PATH/$VSRC_FOLDER/*.v)
    create_soft_link $BUILD_PATH $PROJECT_PATH/$VSRC_FOLDER \"*.v\"
    # create soft link ($PROJECT_PATH/difftest -> $OSCPU_PATH/difftest)
    eval "ln -s \"`realpath --relative-to="$OSCPU_PATH/$DIFFTEST_FOLDER" "$PROJECT_PATH"`/$DIFFTEST_FOLDER\" \"$PROJECT_PATH/$DIFFTEST_FOLDER\" 1>/dev/null 2>&1"

    cd $OSCPU_PATH/$DIFFTEST_FOLDER
    # compile
    make DESIGN_DIR=$PROJECT_PATH $DIFFTEST_PARAM
    if [ $? -ne 0 ]; then
        echo "Failed to run verilator!!!"
        exit 1
    fi
    cd $OSCPU_PATH
}

build_proj() {
    cd $PROJECT_PATH

    # get all .cpp files
    CPP_SRC=`find $PROJECT_PATH/$CSRC_FOLDER -name "*.cpp"`
    
    # get all rtl subfolders
    VSRC_FOLDER=`find $VSRC_FOLDER -type d`
    for SUBFOLDER in ${VSRC_FOLDER[@]}
    do
        INCLUDE_RTL_SRC_FOLDER="$INCLUDE_RTL_SRC_FOLDER -I$SUBFOLDER"
    done

    # compile
    mkdir $BUILD_FOLDER 1>/dev/null 2>&1
    eval "verilator --unused-regexp -Wall --cc --exe --trace -O3 $CFLAGS $LDFLAGS -o $PROJECT_PATH/$BUILD_FOLDER/$EMU_FILE \
        -Mdir $PROJECT_PATH/$BUILD_FOLDER/"emu-compile" $INCLUDE_RTL_SRC_FOLDER --build $V_TOP_FILE $CPP_SRC"
    if [ $? -ne 0 ]; then
        echo "Failed to run verilator!!!"
        exit 1
    fi

    cd $OSCPU_PATH
}

# Initialize variables
OSCPU_PATH=$(dirname $(readlink -f "$0"))
MYINFO_FILE=$OSCPU_PATH"/myinfo.txt"
EMU_FILE="emu"
PROJECT_FOLDER="cpu"
BUILD_FOLDER="build_test"
DIFF_BUILD_FOLDER="build"
VSRC_FOLDER="vsrc"
CSRC_FOLDER="csrc"
BIN_FOLDER="bin"
BUILD="false"
V_TOP_FILE="top.v"
SIMULATE="false"
CHECK_WAVE="false"
CLEAN="false"
PARAMETERS=
CFLAGS=
LDFLAGS=
GBD="false"
DIFFTEST="false"
DIFFTEST_FOLDER="difftest"
DIFFTEST_TOP_FILE="SimTop.v"
NEMU_FOLDER="NEMU"
DIFFTEST_HELPER_PATH="src/test/vsrc/common"
DIFFTEST_PARAM=

# Check parameters
while getopts 'he:bt:sa:f:l:gwcdm:' OPT; do
    case $OPT in
        h) help;;
        e) PROJECT_FOLDER="$OPTARG";;
        b) BUILD="true";;
        t) V_TOP_FILE="$OPTARG";;
        s) SIMULATE="true";;
        a) PARAMETERS="$OPTARG";;
        f) CFLAGS="$OPTARG";;
        l) LDFLAGS="$OPTARG";;
        g) GBD="true";;
        w) CHECK_WAVE="true";;
        c) CLEAN="true";;
        d) DIFFTEST="true";;
        m) DIFFTEST_PARAM="$OPTARG";;
        ?) help;;
    esac
done

if [[ $LDFLAGS ]]; then
    CFLAGS="-CFLAGS "\"$CFLAGS\"
fi
if [[ $CFLAGS ]]; then
    LDFLAGS="-LDFLAGS "\"$LDFLAGS\"
fi

PROJECT_PATH=$OSCPU_PATH/projects/$PROJECT_FOLDER
[[ "$DIFFTEST" == "true" ]] && BUILD_PATH=$PROJECT_PATH/$DIFF_BUILD_FOLDER || BUILD_PATH=$PROJECT_PATH/$BUILD_FOLDER
if [[ "$DIFFTEST" == "true" ]]; then
    V_TOP_FILE=$DIFFTEST_TOP_FILE
    export NEMU_HOME=$OSCPU_PATH/$NEMU_FOLDER
    export NOOP_HOME=$PROJECT_PATH
fi

# Get id and name
ID=`sed '/^ID=/!d;s/.*=//' $MYINFO_FILE`
NAME=`sed '/^Name=/!d;s/.*=//' $MYINFO_FILE`
if [[ ${#ID} -le 7 ]] || [[ ${#NAME} -le 1 ]]; then
    echo "Please fill your information in myinfo.txt!!!"
    exit 1
fi
ID="${ID##*\r}"
NAME="${NAME##*\r}"

# Clean
if [[ "$CLEAN" == "true" ]]; then
    rm -rf $BUILD_PATH
    if [[ "$DIFFTEST" == "true" ]]; then
        unlink $PROJECT_PATH/$DIFFTEST_FOLDER 1>/dev/null 2>&1
    fi
    exit 0
fi

# Build project
if [[ "$BUILD" == "true" ]]; then
    [[ "$DIFFTEST" == "true" ]] && build_diff_proj || build_proj

    #git commit
    git add . -A --ignore-errors
    (echo $NAME && echo $ID && hostnamectl && uptime) | git commit -F - -q --author='tracer-oscpu2021 <tracer@oscpu.org>' --no-verify --allow-empty 1>/dev/null 2>&1
    sync
fi

# Simulate
if [[ "$SIMULATE" == "true" ]]; then
    cd $BUILD_PATH

    # create soft link ($BUILD_PATH/*.bin -> $OSCPU_PATH/$BIN_FOLDER/*.bin). Why? Because of laziness!
    create_soft_link $BUILD_PATH $OSCPU_PATH/$BIN_FOLDER \"*.bin\"

    # run simulation program
    echo "Simulating..."
    if [[ "$GBD" == "true" ]]; then
        gdb -s $EMU_FILE --args ./$EMU_FILE $PARAMETERS
    else
        ./$EMU_FILE $PARAMETERS
    fi

    if [ $? -ne 0 ]; then
        echo "Failed to simulate!!!"
        exit 1
    fi

    cd $OSCPU_PATH
fi

# Check waveform
if [[ "$CHECK_WAVE" == "true" ]]; then
    cd $BUILD_PATH
    gtkwave `ls -t | grep .vcd | head -n 1`
    if [ $? -ne 0 ]; then
        echo "Failed to run gtkwave!!!"
        exit 1
    fi
    cd $OSCPU_PATH
fi
