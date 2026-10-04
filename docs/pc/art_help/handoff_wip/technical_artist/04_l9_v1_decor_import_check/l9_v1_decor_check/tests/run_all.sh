#!/bin/bash
S=/workspace/scratch/l9_v1_decor_check; G=/tmp/godot/Godot_v4.7-stable_linux.x86_64
t() { cd $S/$1 && timeout 900 $G --headless --path . -s res://tests/$2.gd > $S/tests/$1__$2.log 2>&1; echo "$1 $2 exit $?" >> $S/tests/summary.txt; }
: > $S/tests/summary.txt
t proj_base run_jungle_backdrop_tests
t proj_base run_crosshaven_board_tests
t proj_wired run_jungle_backdrop_tests
t proj_wired run_crosshaven_board_tests
t proj_patch run_jungle_backdrop_tests
t proj_patch run_crosshaven_board_tests
t proj_props run_crosshaven_board_tests
t proj_props run_jungle_backdrop_tests
echo DONE >> $S/tests/summary.txt
