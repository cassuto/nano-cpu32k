#!/bin/bash

PRJ_ROOT=$(dirname $(readlink -f "$0"))
BUILD_PATH=$PRJ_ROOT/build
BIN_FOLDER=$PRJ_ROOT/bsp/prebuilt/cpu-tests
EMU_FILE=$BUILD_PATH/emu

TRAMPOLINE_FILE=$PRJ_ROOT/bsp/prebuilt/program/flash/trampoline-flash.bin

# Run all
mkdir $BUILD_PATH/log 1>/dev/null 2>&1
BIN_FILES=`ls $BIN_FOLDER/*.bin`

for BIN_FILE in $BIN_FILES; do
    BIN_FILE_BASE=`basename "$BIN_FILE"`
    FILE_NAME=${BIN_FILE_BASE%.*}
    printf "[%30s] " $FILE_NAME
    LOG_FILE=$BUILD_PATH/log/$FILE_NAME-log.txt
    $EMU_FILE --mode=difftest --flash-image=$TRAMPOLINE_FILE --reset-pc=0x30000000 -b $BIN_FILE &> $LOG_FILE
    if (grep 'HIT GOOD TRAP' $LOG_FILE > /dev/null) then
        echo -e "\033[1;32mPASS!\033[0m"
        rm $LOG_FILE
    else
        echo -e "\033[1;31mFAIL!\033[0m see $LOG_FILE for more information"
    fi
done
