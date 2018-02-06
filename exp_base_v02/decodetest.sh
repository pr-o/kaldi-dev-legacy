#!/bin/bash

# decodetest.sh

######
model_dir=/home/sunghah/recipe/train_base
data_dir=/home/sunghah/data/
data_dir_hires=$data_dir/test_dir_hires
result_dir=/home/sunghah/decodetest

######
logfile=`pwd`/online_decoding.log

on_featext_test=0

on_mono_decode=0
on_tri1_decode=0
on_tri2_decode=0
on_tri3_decode=0

on_hires_featext_test=1
on_hires_tri2_decode=0

on_online_nnet_decode=1
#####

. ./train_base/path.sh || exit 1

if [ ! -L ./utils ]
then
    rm -rf ./utils
    ln -sf $KALDI_ROOT/egs/wsj/s5/utils ./utils
fi

if [ ! -L ./steps ]
then
    rm -rf ./steps
    ln -sf $KALDI_ROOT/egs/wsj/s5/steps ./steps
fi

# Back up existing log files
cd $model_dir
if [ ! -d ./backup/log/ ]
then
    mkdir -p ./backup/log/
fi
mv *.log ./backup/log/


# Set directories
train_dir=$model_dir/train
lang_train_dir=$model_dir/lang_train
graph_dir=$model_dir/graph

test_cmd=utils/run.pl
test_nj=24


############
if [ $on_featext_test -eq 1 ]
then

    echo "on_featext_test - start" `date` >> $logfile

    utils/fix_data_dir.sh $data_dir
    utils/utt2spk_to_spk2utt.pl $data_dir/utt2spk > $data_dir/spk2utt

    steps/make_mfcc.sh \
        --nj $test_nj \
        --mfcc-config conf/mfcc.conf \
        --cmd "$test_cmd" \
        $data_dir || exit 1;

    steps/compute_cmvn_stats.sh \
        $data_dir || exit 1;

    echo "on_featext_test - end" `date` >> $logfile
fi


if [ $on_mono_decode -eq 1 ]
then

    echo "on_mono_decode - start" `date` >> $logfile

    if [ ! -d $result_dir ]
    then
    mkdir "$result_dir"
    fi

    if [ -d $train_dir/exp/mono/decode ]
    then
    rm -rf $train_dir/exp/mono/decode*/
    fi

    steps/decode.sh \
        --nj "$test_nj" \
        --cmd "$test_cmd" \
        $graph_dir/mono \
        $data_dir \
        $train_dir/exp/mono/decode

    if [ -d $result_dir/decode_mono ]
    then
    rm -rf $result_dir/decode_mono
    fi

    cp -r $train_dir/exp/mono/decode $result_dir/decode_mono

    echo "on_mono_decode - end" `date` >> $logfile
    
fi


if [ $on_tri1_decode -eq 1 ]
then

    echo "on_tri1_decode - start" `date` >> $logfile

    if [ ! -d $result_dir ]
    then
    mkdir "$result_dir"
    fi

    if [ -d $train_dir/exp/tri1/decode ]
    then
    rm -rf $train_dir/exp/tri1/decode*/
    fi

    steps/decode.sh \
        --nj "$test_nj" \
        --cmd "$test_cmd" \
        $graph_dir/tri1 \
        $data_dir \
        $train_dir/exp/tri1/decode

    if [ -d $result_dir/decode_tri1 ]
    then
    rm -rf $result_dir/decode_tri1
    fi

    cp -r $train_dir/exp/tri1/decode $result_dir/decode_tri1

    echo "on_tri1_decode - end" `date` >> $logfile
    
fi


if [ $on_tri2_decode -eq 1 ]
then

    echo "on_tri2_decode - start" `date` >> $logfile

    if [ ! -d $result_dir ]
    then
    mkdir "$result_dir"
    fi

    if [ -d $train_dir/exp/tri2/decode ]
    then
    rm -rf $train_dir/exp/tri2/decode*/
    fi

    steps/decode.sh \
        --nj "$test_nj" \
        --cmd "$test_cmd" \
        $graph_dir/tri2 \
        $data_dir \
        $train_dir/exp/tri2/decode

    if [ -d $result_dir/decode_tri2 ]
    then
    rm -rf $result_dir/decode_tri2
    fi

    cp -r $train_dir/exp/tri2/decode $result_dir/decode_tri2

    echo "on_tri2_decode - end" `date` >> $logfile
    
fi


if [ $on_tri3_decode -eq 1 ]
then

    echo "on_tri3_decode - start" `date` >> $logfile

    if [ ! -d $result_dir ]
    then
    mkdir "$result_dir"
    fi

    if [ -d $train_dir/exp/tri3/decode ]
    then
    rm -rf $train_dir/exp/tri3/decode*/
    fi

    steps/decode_fmllr.sh \
        --nj "$test_nj" \
        --cmd "$test_cmd" \
        $graph_dir/tri3 \
        $data_dir \
        $train_dir/exp/tri3/decode

    if [ -d $result_dir/decode_tri3 ]
    then
    rm -rf $result_dir/decode_tri3
    fi

    cp -r $train_dir/exp/tri3/decode $result_dir/decode_tri3

    echo "on_tri3_decode - end" `date` >> $logfile
    
fi


if [ $on_hires_featext_test -eq 1 ]
then

    echo "on_hires_featext_test - start" `date` >> $logfile

    utils/copy_data_dir.sh $data_dir $data_dir_hires
    
    steps/make_mfcc.sh \
        --nj $test_nj \
        --mfcc-config conf/mfcc_hires.conf \
        --cmd "$test_cmd" \
        $data_dir_hires || exit 1;

    steps/compute_cmvn_stats.sh \
        $data_dir_hires || exit 1;

    echo "on_hires_featext_test - end" `date` >> $logfile
fi


if [ $on_hires_tri2_decode -eq 1 ]
then

    echo "on_hires_tri2_decode - start" `date` >> $logfile

    if [ ! -d $result_dir ]
    then
    mkdir "$result_dir"
    fi

    if [ -d $train_dir/exp/hires_tri2/decode ]
    then
    rm -rf $train_dir/exp/hires_tri2/decode*/
    fi

    steps/decode.sh \
        --nj "$test_nj" \
        --cmd "$test_cmd" \
        $graph_dir/hires_tri2 \
        $data_dir_hires \
        $train_dir/exp/hires_tri2/decode

    if [ -d $result_dir/decode_hires_tri2 ]
    then
    rm -rf $result_dir/decode_hires_tri2
    fi

    cp -r $train_dir/exp/hires_tri2/decode $result_dir/decode_hires_tri2


    echo "on_hires_tri2_decode - end" `date` >> $logfile
    
fi


if [ $on_online_nnet_decode -eq 1 ]
then

    echo "on_online_nnet_decode - start" `date` >> $logfile

    if [ ! -d "$train_dir/exp/nnet2_online/nnet_ms_a_online" ]
    then
    mkdir "$train_dir/exp/nnet2_online/nnet_ms_a_online"
    fi

    if [ ! -d $result_dir ]
    then
    mkdir "$result_dir"
    fi

    if [ ! -d $graph_dir/tri3 ]
    then
    echo "No graph - $graph_dir/tri3"
    exit 0;
    fi

    if [ -d $train_dir/exp/nnet2_online/nnet_ms_a_online/decode ]
    then
    rm -rf $train_dir/exp/nnet2_online/nnet_ms_a_online/decode
    fi
    
    steps/online/nnet2/prepare_online_decoding.sh \
        --mfcc-config conf/mfcc_hires.conf \
        $lang_train_dir \
        $train_dir/exp/nnet2_online/extractor \
        $train_dir/exp/nnet2_online/nnet_ms_a \
        $train_dir/exp/nnet2_online/nnet_ms_a_online || exit 1;

    # seperately use speaker information --> --per-utt true
    # forwarding speaker info --> "--per-utt false" or (default option)
    steps/online/nnet2/decode.sh \
        --config conf/decode.config \
        --cmd "$test_cmd" --nj $test_nj \
        $graph_dir/tri3 \
        $data_dir \
        $train_dir/exp/nnet2_online/nnet_ms_a_online/decode || exit 1;    

    if [ -d $result_dir/decode_online_nnet ]
    then
    rm -rf $result_dir/decode_online_nnet
    fi

    cp -r $train_dir/exp/nnet2_online/nnet_ms_a_online/decode $result_dir/decode_online_nnet

    echo "on_online_nnet_decode - end" `date` >> $logfile
    
fi


######################################
echo "end" `date` >> $logfile

exit 0;
