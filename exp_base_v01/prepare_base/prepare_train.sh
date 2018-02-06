#!/bin/bash


#Kaldi path setting
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

###########

train_given=./inputs/train_given

### 0. Input(given) data check ###

for x in "$train_given/wav.scp" "$train_given/text" "$train_given/lexicon.txt" "$train_given/utt2spk"
do
    if [ ! -f $x ]
    then
	echo "No file - $x"
	exit 0;
    fi
done

### 1. set default paths and make dirs ###

train_created=./outputs/train
lang_dir=./outputs/lang_train
data_dir=./outputs/data/train_dir

tmp_dir=./outputs/tmp_train
logfile=./prepare_train.log

for x in $train_created $lang_dir $data_dir $tmp_dir
do
    if [ ! -d $x ]
    then
	mkdir -p $x
    else
	rm -r $x
	mkdir $x
    fi
done

##########################################

echo "Start." `date` > $logfile
# data lexicon LM preparation

cp $train_given/wav.scp $data_dir/
cp $train_given/text $data_dir/
cp $train_given/utt2spk $data_dir/    

sed '/<unk>/d' $train_given/lexicon.txt > $tmp_dir/tmp.txt
cp $tmp_dir/tmp.txt $train_given/lexicon.txt    
echo "data & language part" `date` >> $logfile
cut -d ' ' -f 2- $train_given/text > $data_dir/textraw
utils/fix_data_dir.sh $train_given
utils/utt2spk_to_spk2utt.pl $train_given/utt2spk > $data_dir/spk2utt    
cut -d ' ' -f 2- $train_given/lexicon.txt | tr ' ' '\n' | sed '/^$/d' | sort -u > $train_created/nonsilence_phones.txt
## lexicon.txt에서 단어와 발음sequence 사이의 경계가 tab이 아닌 ' '인 점 주의.
## nonsilence_phones.txt에서 sil 삭제해야함.
sed '/sil/d' $train_created/nonsilence_phones.txt > $tmp_dir/tmp.txt
mv $tmp_dir/tmp.txt $train_created/nonsilence_phones.txt
##
echo "sil" > $train_created/optional_silence.txt
echo -e "sil\n<unk>" > $train_created/silence_phones.txt
cat $train_created/silence_phones.txt| awk '{printf("%s ", $1);} END{printf "\n";}' > $train_created/extra_questions.txt || exit 1;    
cat $train_created/nonsilence_phones.txt | perl -e 'while(<>){ foreach $p (split(" ", $_)) {  $p =~ m:^([^\d]+)(\d*)$: || die "Bad phone $_"; $q{$2} .= "$p "; } } foreach $l (values %q) {print "$l\n";}' >> $train_created/extra_questions.txt || exit 1;    
ed -s $train_given/lexicon.txt <<< $'1i\n<unk> <unk>\n.\nwq'

cp $train_given/lexicon.txt $train_created

utils/prepare_lang.sh \
    $train_created "<unk>" \
    $train_created/tmp \
    $lang_dir

########## end ##########
echo "End." `date` >> $logfile

exit 0;

