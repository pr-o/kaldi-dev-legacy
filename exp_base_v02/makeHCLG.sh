#!/bin/bash

# makeHCLG.sh

######
model_dir=/home/sunghah/recipe/train_base

######
logfile=online_recipe.log
on_mono_mkgraph=0
on_tri3_mkgraph=1
on_nnet2_mkgraph=0
######

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


echo "start" `date` > $logfile

if [ $on_mono_mkgraph -eq 1 ]
then

    echo "on_mono_mkgraph - start" `date` >> $logfile

    if [ ! -d $graph_dir ]
    then
        mkdir $graph_dir
    fi

    utils/mkgraph.sh \
        $lang_train_dir \
        $train_dir/exp/mono \
        $graph_dir/mono

    echo "on_mono_mkgraph - end" `date` >> $logfile
fi


if [ $on_tri3_mkgraph -eq 1 ]
then

    echo "on_tri3_mkgraph - start" `date` >> $logfile

    if [ ! -d $graph_dir ]
    then
        mkdir $graph_dir
    fi
    
    echo $lang_train_dir $train_dir/exp/tri3 $graph_dir/tri3

    utils/mkgraph.sh \
        $lang_train_dir \
        $train_dir/exp/tri3 \
        $graph_dir/tri3

    echo "on_tri3_mkgraph - end" `date` >> $logfile

fi


if [ $on_nnet2_mkgraph -eq 1 ]
then

    echo "on_nnet2_mkgraph - start" `date` >> $logfile

    if [ ! -d $graph_dir ]
    then
        mkdir $graph_dir
    fi

    utils/mkgraph.sh \
        $lang_train_dir \
        $train_dir/exp/nnet2_online/nnet_ms_a \
        $graph_dir/nnet2

    echo "on_nnet2_mkgraph - end" `date` >> $logfile

fi
