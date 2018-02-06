#!/bin/bash


decode_result_dir=./decode_result
current_dir=`pwd`

cd $decode_result_dir

ls -dxX1 */ > ./result_dirs.txt

mkdir tmp
mv result_dirs.txt tmp/

cat ./tmp/result_dirs.txt | sed 's/^/cat /g' | sed 's/$/scoring_kaldi\/best_wer/' > ./tmp/get_wers.txt
bash ./tmp/get_wers.txt > ./tmp/result_wers.txt

paste -d '\t' ./tmp/result_dirs.txt ./tmp/result_wers.txt

rm -r tmp

cd $current_dir

exit 0;
