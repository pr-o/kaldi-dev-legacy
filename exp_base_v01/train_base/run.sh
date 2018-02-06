#!/bin/bash

. ./path.sh || exit 1

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

train_cmd=run.pl
train_nj=50


train_dir=./train
lang_test_dir=./lang_test
lang_train_dir=./lang_train
data_dir=./data
conf_dir=./conf
graph_dir=./graph
result_dir=./decode_result

test_cmd=run.pl
test_nj=24




######
logfile=online_recipe.log

on_featext_train=0
on_mono=0
on_align_mono=0
on_tri1=0
on_align_tri1=0
on_tri2=0
on_align_tri2=0
on_tri3=0
on_align_tri3=0

on_hires_featext_train=0
on_hires_tri2=0
on_ubm=0
on_ivector=0
on_train_nnet_online=1
######
on_featext_test=1 # for tri1_decode
on_tri1_decode=1
on_tri2_decode=1
on_tri3_decode=1

on_hires_featext_test=1
on_hires_tri2_decode=1

on_online_nnet_decode=1

# on_approach1=0  # offline decoding
# on_approach2=0  # online decoding (maintain user speaker info continuously)
# on_approach3=1  # online decoding (seperately use speaker info)
######
gen_output_am_dir=0
#####

#####

# tuning parameters #
# mono
mono_scale_opts="--transition-scale=1.0 --acoustic-scale=0.1 --self-loop-scale=0.1"
mono_num_iters=40    # Number of iterations of training
mono_max_iter_inc=30 # Last iter to increase #Gauss on.
mono_totgauss=1000 # Target #Gaussians.
mono_boost_silence=1.0 # Factor by which to boost silence likelihoods in alignment
mono_power=0.25 # exponent to determine number of gaussians from occurrence counts
mono_cmvn_opts="--norm-means=true --norm-vars=false"  # can be used to add extra options to cmvn.
# tri1
tri1_scale_opts="--transition-scale=1.0 --acoustic-scale=0.1 --self-loop-scale=0.1"
tri1_realign_iters="10 20 30";
tri1_num_iters=35
tri1_max_iter_inc=25
tri1_beam=10
tri1_retry_beam=40
tri1_boost_silence=1.0
tri1_power=0.25
tri1_delta_opts="--delta-order=2"
tri1_cmvn_opts="--norm-vars=true --norm-means=false"
tri1_context_opts="--context-width=3 --central-position=1"
# tri2
tri2_scale_opts="--transition-scale=1.0 --acoustic-scale=0.1 --self-loop-scale=0.1"
tri2_realign_iters="10 20 30";
tri2_mllt_iters="2 4 6 12";
tri2_num_iters=35
tri2_max_iter_inc=25
tri2_dim=40
tri2_beam=10
tri2_retry_beam=40
tri2_careful=false
tri2_boost_silence=1.0
tri2_power=0.25
tri2_randprune=4.0
tri2_splice_opts="--left-context=4 --right-context=4"
tri2_cmvn_opts="--norm-means=true --norm-vars=false"
tri2_context_opts="--context-width=3 --central-position=1"
# tri3
tri3_scale_opts="--transition-scale=1.0 --acoustic-scale=0.1 --self-loop-scale=0.1"
tri3_beam=10
tri3_retry_beam=40
tri3_boost_silence=1.0
tri3_context_opts="--context-width=3 --central-position=1"
tri3_realign_iters="10 20 30";
tri3_fmllr_iters="2 4 6 12";
tri3_silence_weight=0.0
tri3_num_iters=35
tri3_max_iter_inc=25
tri3_power=0.2
#

tri1_num_leaves=2000
tri1_tot_gauss=10000

tri2_num_leaves=2500
tri2_tot_gauss=15000

tri3_num_leaves=2500
tri3_tot_gauss=15000


#####

echo "start" `date` > $logfile

if [ $on_featext_train -eq 1 ]
then

    echo "on_featext_train - start" `date` >> $logfile
    
    steps/make_mfcc.sh \
	--nj $train_nj \
	--mfcc-config $conf_dir/mfcc.conf \
	--cmd "$train_cmd" \
	$data_dir/train_dir || exit 1;

    steps/compute_cmvn_stats.sh \
	$data_dir/train_dir || exit 1;
    
    echo "on_featext_train - end" `date` >> $logfile
fi

if [ $on_mono -eq 1 ]
then
    echo "on_mono - start" `date` >> $logfile
    
    steps/train_mono.sh \
	--cmd "$train_cmd" \
	--nj $train_nj \
	--scale_opts "${mono_scale_opts}" \
	--num_iters $mono_num_iters \
	--max_iter_inc $mono_max_iter_inc \
	--totgauss $mono_totgauss \
	--boost-silence $mono_boost_silence \
	--power $mono_power \
	$data_dir/train_dir \
	$lang_train_dir \
	$train_dir/exp/mono

    echo "on_mono - end" `date` >> $logfile    
fi


if [ $on_align_mono -eq 1 ]
then
    echo "on_align_mono - start" `date` >> $logfile
    
    steps/align_si.sh \
	--cmd "$train_cmd" \
	--nj $train_nj \
	--boost-silence 1.25 \
	$data_dir/train_dir \
	$lang_train_dir \
	$train_dir/exp/mono \
	$train_dir/exp/mono_ali

    echo "on_align_mono - end" `date` >> $logfile        
fi

if [ $on_tri1 -eq 1 ]
then
    echo "on_tri1 - start" `date` >> $logfile    
    
    steps/train_deltas.sh \
	--cmd "$train_cmd" \
	--scale_opts "${tri1_scale_opts}" \
	--realign_iters "${tri1_realign_iters}" \
	--num_iters $tri1_num_iters \
	--max_iter_inc $tri1_max_iter_inc \
	--beam $tri1_beam \
	--retry_beam $tri1_retry_beam \
	--boost-silence $tri1_boost_silence \
	--power $tri1_power \
	--delta_opts "${tri1_delta_opts}" \
	--context_opts "${tri1_context_opts}" \
	$tri1_num_leaves \
	$tri1_tot_gauss \
	$data_dir/train_dir \
	$lang_train_dir \
	$train_dir/exp/mono_ali \
	$train_dir/exp/tri1

    echo "on_tri1 - end" `date` >> $logfile        
fi


if [ $on_align_tri1 -eq 1 ]
then

    echo "on_align_tri1 - start" `date` >> $logfile
    
    steps/align_si.sh \
	--cmd "$train_cmd" \
	--nj $train_nj \
	$data_dir/train_dir \
	$lang_train_dir \
	$train_dir/exp/tri1 \
	$train_dir/exp/tri1_ali

    echo "on_align_tri1 - end" `date` >> $logfile    
fi

if [ $on_tri2 -eq 1 ]
then
    echo "on_tri2 - start" `date` >> $logfile
    
    steps/train_lda_mllt.sh \
	--cmd "$train_cmd" \
	--scale_opts "${tri2_scale_opts}" \
	--realign_iters "${tri2_realign_iters}" \
	--mllt_iters "${tri2_mllt_iters}" \
	--num_iters $tri2_num_iters \
	--max_iter_inc $tri2_max_iter_inc \
	--dim $tri2_dim \
	--beam $tri2_beam \
	--retry_beam $tri2_retry_beam \
	--careful $tri2_careful \
	--boost_silence $tri2_boost_silence \
	--power $tri2_power \
	--randprune $tri2_randprune \
	--splice_opts "${tri2_splice_opts}" \
	--context_opts "${tri2_context_opts}" \
	$tri2_num_leaves \
	$tri2_tot_gauss \
	$data_dir/train_dir \
	$lang_train_dir \
	$train_dir/exp/tri1_ali \
	$train_dir/exp/tri2

    echo "on_tri2 - end" `date` >> $logfile    
fi


if [ $on_align_tri2 -eq 1 ]
then

    echo "on_align_tri2 - start" `date` >> $logfile
    
    steps/align_si.sh \
	--cmd "$train_cmd" \
	--nj $train_nj \
	$data_dir/train_dir \
	$lang_train_dir \
	$train_dir/exp/tri2 \
	$train_dir/exp/tri2_ali

    echo "on_align_tri2 - end" `date` >> $logfile
    
fi

# steps/align_fmllr.sh --nj 40 --cmd "$train_cmd" \
#     data/train_960_30k data/lang exp/tri6b exp/nnet2_online/tri6b_ali_30k
if [ $on_tri3 -eq 1 ]
then
    
    echo "on_tri3 - start" `date` >> $logfile    
    
    steps/train_sat.sh \
	--cmd "$train_cmd" \
	--scale_opts "${tri3_scale_opts}" \
	--beam $tri3_beam \
	--retry_beam $tri3_retry_beam \
	--boost-silence $tri3_boost_silence \
	--context_opts "${tri3_context_opts}" \
	--realign_iters "${tri3_realign_iters}" \
	--fmllr_iters "${tri3_fmllr_iters}" \
	--silence_weight $tri3_silence_weight \
	--num_iters $tri3_num_iters \
	--max_iter_inc $tri3_max_iter_inc \
	--power $tri3_power \
	$tri3_num_leaves \
	$tri3_tot_gauss \
	$data_dir/train_dir \
	$lang_train_dir \
	$train_dir/exp/tri2_ali \
	$train_dir/exp/tri3

    echo "on_tri3 - start" `date` >> $logfile    
    
fi

if [ $on_align_tri3 -eq 1 ]
then
    echo "on_align_tri3 - start" `date` >> $logfile
    
    steps/align_fmllr.sh \
	--cmd "$train_cmd" \
	--nj $train_nj \
	$data_dir/train_dir \
	$lang_train_dir \
	$train_dir/exp/tri3 \
	$train_dir/exp/tri3_ali

    echo "on_align_tri3 - end" `date` >> $logfile
    
fi


################################## modifying ########


if [ $on_hires_featext_train -eq 1 ]
then

    echo "on_featext_train - start" `date` >> $logfile

    utils/copy_data_dir.sh $data_dir/train_dir $data_dir/train_dir_hires
    
    steps/make_mfcc.sh \
	--nj $train_nj \
	--mfcc-config conf/mfcc_hires.conf \
	--cmd "$train_cmd" \
	$data_dir/train_dir_hires || exit 1;

    steps/compute_cmvn_stats.sh \
	$data_dir/train_dir_hires || exit 1;
    
    echo "on_hires_featext_train - end" `date` >> $logfile
fi

if [ $on_hires_tri2 -eq 1 ]
then
    echo "on_hires_tri2 - start" `date` >> $logfile
    
    steps/train_lda_mllt.sh \
	--cmd "$train_cmd" \
	--scale_opts "${tri2_scale_opts}" \
	--realign_iters "${tri2_realign_iters}" \
	--mllt_iters "${tri2_mllt_iters}" \
	--num_iters $tri2_num_iters \
	--max_iter_inc $tri2_max_iter_inc \
	--dim $tri2_dim \
	--beam $tri2_beam \
	--retry_beam $tri2_retry_beam \
	--careful $tri2_careful \
	--boost_silence $tri2_boost_silence \
	--power $tri2_power \
	--randprune $tri2_randprune \
	--splice_opts "${tri2_splice_opts}" \
	--context_opts "${tri2_context_opts}" \
	$tri2_num_leaves \
	$tri2_tot_gauss \
	$data_dir/train_dir_hires \
	$lang_train_dir \
	$train_dir/exp/tri3_ali \
	$train_dir/exp/hires_tri2

    echo "on_hires_tri2 - end" `date` >> $logfile    

fi



if [ $on_ubm -eq 1 ]
then

    echo "on_ubm - start" `date` >> $logfile
    
    mkdir -p $train_dir/exp/nnet2_online
    # To train a diagonal UBM we don't need very much data, so use a small subset
    # (actually, it's not that small: still around 100 hours).
    steps/online/nnet2/train_diag_ubm.sh \
	--cmd "$train_cmd" \
	--nj $train_nj \
	--num-frames 700000 \
	$data_dir/train_dir_hires \
	512 \
	$train_dir/exp/hires_tri2 \
	$train_dir/exp/nnet2_online/diag_ubm

    echo "on_ubm - end" `date` >> $logfile
    
fi

if [ $on_ivector -eq 1 ]
then

    echo "on_ivector - start" `date` >> $logfile
    
    # iVector extractors can in general be sensitive to the amount of data, but
    # this one has a fairly small dim (defaults to 100) so we don't use all of it,
    # we use just the 60k subset (about one fifth of the data, or 200 hours).
    steps/online/nnet2/train_ivector_extractor.sh \
	--cmd "$train_cmd" --nj $train_nj \
	$data_dir/train_dir_hires \
	$train_dir/exp/nnet2_online/diag_ubm \
	$train_dir/exp/nnet2_online/extractor || exit 1;

    # steps/online/nnet2/copy_data_dir.sh \
    # 	--utts-per-spk-max 2 \
    # 	$train_created \
    # 	./train_created2

    steps/online/nnet2/extract_ivectors_online.sh \
	--cmd "$train_cmd" \
	--nj $train_nj \
        $data_dir/train_dir_hires \
	$train_dir/exp/nnet2_online/extractor \
	$train_dir/exp/nnet2_online/ivector_train_hires || exit 1;

    echo "on_ivector - end" `date` >> $logfile
    

fi



##########################################


if [ $on_train_nnet_online -eq 1 ]
then

    echo "on_train_nnet_online - start" `date` >> $logfile
    
    num_threads=1
    minibatch_size=512
    train_stage=-10

    ###  KOR readspeech database ###
    
    # steps/nnet2/train_multisplice_accel2.sh \
    # 	--stage $train_stage \
    # 	--num-epochs 8 --num-jobs-initial 3 --num-jobs-final 3 \
    #     --num-hidden-layers 6 --splice-indexes "layer0/-2:-1:0:1:2 layer1/-1:2 layer3/-3:3 layer4/-7:2" \
    # 	--feat-type raw \
    # 	--online-ivector-dir $train_created/exp/nnet2_online/ivector_train_hires \
    # 	--cmvn-opts "--norm-means=false --norm-vars=false" \
    # 	--num-threads "$num_threads" \
    # 	--minibatch-size "$minibatch_size" \
    # 	--io-opts "--max-jobs-run 6" \
    # 	--initial-effective-lrate 0.0015 --final-effective-lrate 0.00015 \
    # 	--cmd run.pl \
    # 	--pnorm-input-dim 3500 \
    # 	--pnorm-output-dim 350 \
    # 	--mix-up 12000 \
    # 	$train_created \
    # 	$train_created \
    # 	$train_created/exp/tri3_ali \
    # 	$train_created/exp/nnet2_online/nnet_ms_a  || exit 1;

    ###  ENG TIMIT database ###
    
    steps/nnet2/train_multisplice_accel2.sh \
    	--stage $train_stage \
    	--num-epochs 15 --num-jobs-initial 3 --num-jobs-final 3 \
        --num-hidden-layers 3 --splice-indexes "layer0/-4:-3:-2:-1:0:1:2:3:4 layer2/-5:-1:3" \
	--feat-type raw \
    	--online-ivector-dir $train_dir/exp/nnet2_online/ivector_train_hires \
    	--cmvn-opts "--norm-means=false --norm-vars=false" \
    	--num-threads "$num_threads" \
    	--minibatch-size "$minibatch_size" \
    	--io-opts "--max-jobs-run 8" \
    	--initial-effective-lrate 0.0015 --final-effective-lrate 0.00015 \
    	--cmd run.pl \
    	--pnorm-input-dim 3500 \
    	--pnorm-output-dim 350 \
    	--mix-up 12000 \
    	$data_dir/train_dir_hires \
	$lang_train_dir \
    	$train_dir/exp/tri3_ali \
    	$train_dir/exp/nnet2_online/nnet_ms_a  || exit 1;

    echo "on_train_nnet_online - end" `date` >> $logfile    
    
fi

############

if [ $on_featext_test -eq 1 ]
then

    echo "on_featext_test - start" `date` >> $logfile
    
    steps/make_mfcc.sh \
	--nj $test_nj \
	--mfcc-config conf/mfcc.conf \
	--cmd "$test_cmd" \
	$data_dir/test_dir || exit 1;

    steps/compute_cmvn_stats.sh \
	$data_dir/test_dir || exit 1;

    echo "on_featext_test - end" `date` >> $logfile
fi

if [ $on_tri1_decode -eq 1 ]
then

    echo "on_tri1_decode - start" `date` >> $logfile

    if [ ! -d $result_dir ]
    then
	mkdir "$result_dir"
    fi

    if [ ! -d $graph_dir ]
    then
	mkdir $graph_dir
    fi
    
    utils/mkgraph.sh \
	$lang_test_dir \
	$train_dir/exp/tri1 \
	$graph_dir/tri1
    steps/decode.sh \
	--nj "$test_nj" \
	--cmd "$test_cmd" \
	$graph_dir/tri1 \
	$data_dir/test_dir \
	$train_dir/exp/tri1/decode

    if [ -d $result_dir/decode_tri1 ]
    then
	rm -r $result_dir/decode_tri1
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

    if [ ! -d $graph_dir ]
    then
	mkdir $graph_dir
    fi
    
    utils/mkgraph.sh \
	$lang_test_dir \
	$train_dir/exp/tri2 \
	$graph_dir/tri2
    steps/decode.sh \
	--nj "$test_nj" \
	--cmd "$test_cmd" \
	$graph_dir/tri2 \
	$data_dir/test_dir \
	$train_dir/exp/tri2/decode

    if [ -d $result_dir/decode_tri2 ]
    then
	rm -r $result_dir/decode_tri2
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

    if [ ! -d $graph_dir ]
    then
	mkdir $graph_dir
    fi
    
    utils/mkgraph.sh \
	$lang_test_dir \
	$train_dir/exp/tri3 \
	$graph_dir/tri3
    steps/decode_fmllr.sh \
	--nj "$test_nj" \
	--cmd "$test_cmd" \
	$graph_dir/tri3 \
	$data_dir/test_dir \
	$train_dir/exp/tri3/decode

    if [ -d $result_dir/decode_tri3 ]
    then
	rm -r $result_dir/decode_tri3
    fi

    cp -r $train_dir/exp/tri3/decode $result_dir/decode_tri3

    echo "on_tri3_decode - end" `date` >> $logfile
    
fi

if [ $on_hires_featext_test -eq 1 ]
then

    echo "on_hires_featext_test - start" `date` >> $logfile

    utils/copy_data_dir.sh $data_dir/test_dir $data_dir/test_dir_hires
    
    steps/make_mfcc.sh \
	--nj $test_nj \
	--mfcc-config conf/mfcc_hires.conf \
	--cmd "$test_cmd" \
	$data_dir/test_dir_hires || exit 1;

    steps/compute_cmvn_stats.sh \
	$data_dir/test_dir_hires || exit 1;

    echo "on_hires_featext_test - end" `date` >> $logfile
fi


if [ $on_hires_tri2_decode -eq 1 ]
then

    echo "on_hires_tri2_decode - start" `date` >> $logfile

    if [ ! -d $result_dir ]
    then
	mkdir "$result_dir"
    fi

    if [ ! -d $graph_dir ]
    then
	mkdir $graph_dir
    fi
    
    utils/mkgraph.sh \
	$lang_test_dir \
	$train_dir/exp/hires_tri2 \
	$graph_dir/hires_tri2
    steps/decode.sh \
	--nj "$test_nj" \
	--cmd "$test_cmd" \
	$graph_dir/hires_tri2 \
	$data_dir/test_dir_hires \
	$train_dir/exp/hires_tri2/decode

    if [ -d $result_dir/decode_hires_tri2 ]
    then
	rm -r $result_dir/decode_hires_tri2
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
    
    steps/online/nnet2/prepare_online_decoding.sh \
	--mfcc-config conf/mfcc_hires.conf \
	$lang_test_dir \
	$train_dir/exp/nnet2_online/extractor \
	$train_dir/exp/nnet2_online/nnet_ms_a \
	$train_dir/exp/nnet2_online/nnet_ms_a_online || exit 1;

    # seperately use speaker information --> --per-utt true
    # forwarding speaker info --> "--per-utt false" or (default option)
    steps/online/nnet2/decode.sh \
	--config conf/decode.config \
	--cmd "$test_cmd" --nj $test_nj \
	$graph_dir/tri3 \
	$data_dir/test_dir \
	$train_dir/exp/nnet2_online/nnet_ms_a_online/decode || exit 1;	

    if [ -d $result_dir/decode_online_nnet ]
    then
	rm -r $result_dir/decode_online_nnet
    fi

    cp -r $train_dir/exp/nnet2_online/nnet_ms_a_online/decode $result_dir/decode_online_nnet

    echo "on_online_nnet_decode - end" `date` >> $logfile
    
fi

if [ $gen_output_am_dir -eq 1 ]
then
    if [ ! -d "_am_dir" ]
    then
	mkdir _am_dir
    fi
    
    cp -r $train_dir/exp/nnet2_online/nnet_ms_a_online/* _am_dir/

    if [ -d "./_am_dir/decode" ]
    then
	rm -rf ./_am_dir/decode
    fi   

    cp $train_dir/phones.txt _am_dir/
    cp $train_dir/phones/disambig.int _am_dir/
    cp $train_dir/phones/silence.csl _am_dir/
    
fi



######################################

echo "end" `date` >> $logfile

exit 0;

