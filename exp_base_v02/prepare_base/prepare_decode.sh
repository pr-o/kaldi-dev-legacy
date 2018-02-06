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

test_given=./inputs/test_given

### 0. Input(given) data check ###

for x in "$test_given/wav.scp" "$test_given/text" "$test_given/lexicon.txt" "$test_given/utt2spk"
do
    if [ ! -f $x ]
    then
	echo "No file - $x"
	exit 0;
    fi
done


### 1. default paths ###
lang_dir=./outputs/lang_test
data_dir=./outputs/data/test_dir

tmp_dir=./outputs/tmp_test
logfile=./outputs/prepare_decode.log

for x in $lang_dir $data_dir $tmp_dir
do
    if [ ! -d $x ]
    then
	mkdir -p $x
    else
	rm -r $x
	mkdir $x
    fi
done


###########################

echo "Start." `date` > $logfile
# data lexicon LM preparation

cp $test_given/wav.scp $data_dir/
cp $test_given/text $data_dir/
cp $test_given/utt2spk $data_dir/

sed '/<unk>/d' $test_given/lexicon.txt > $tmp_dir/tmp.txt
cp $tmp_dir/tmp.txt $test_given/lexicon.txt    
echo "data & language part" `date` >> $logfile
cut -d ' ' -f 2- $test_given/text > $data_dir/textraw
utils/fix_data_dir.sh $test_given
utils/utt2spk_to_spk2utt.pl $test_given/utt2spk > $data_dir/spk2utt
cut -d ' ' -f 2- $test_given/lexicon.txt | tr ' ' '\n' | sed '/^$/d' | sort -u > $tmp_dir/nonsilence_phones.txt
## lexicon.txt에서 단어와 발음sequence 사이의 경계가 tab이 아닌 ' '인 점 주의.
## nonsilence_phones.txt에서 sil 삭제해야함.
sed '/sil/d' $tmp_dir/nonsilence_phones.txt > $tmp_dir/tmp.txt
mv $tmp_dir/tmp.txt $tmp_dir/nonsilence_phones.txt
##
echo "sil" > $tmp_dir/optional_silence.txt
echo -e "sil\n<unk>" > $tmp_dir/silence_phones.txt
cat $tmp_dir/silence_phones.txt| awk '{printf("%s ", $1);} END{printf "\n";}' > $tmp_dir/extra_questions.txt || exit 1;    
cat $tmp_dir/nonsilence_phones.txt | perl -e 'while(<>){ foreach $p (split(" ", $_)) {  $p =~ m:^([^\d]+)(\d*)$: || die "Bad phone $_"; $q{$2} .= "$p "; } } foreach $l (values %q) {print "$l\n";}' >> $tmp_dir/extra_questions.txt || exit 1;    
ed -s $test_given/lexicon.txt <<< $'1i\n<unk> <unk>\n.\nwq'

cp $test_given/lexicon.txt $tmp_dir

utils/prepare_lang.sh \
    $tmp_dir "<unk>" \
    $tmp_dir/tmp \
    $lang_dir

# LM train
$KALDI_ROOT/tools/srilm/bin/i686-m64/ngram-count -text $data_dir/textraw -lm $lang_dir/lm.arpa
cat $lang_dir/lm.arpa | $KALDI_ROOT/src/lmbin/arpa2fst --disambig-symbol=#0 --read-symbol-table=$lang_dir/words.txt - $lang_dir/G.fst
$KALDI_ROOT/src/fstbin/fstisstochastic $lang_dir/G.fst

########## end ##########
echo "End." `date` >> $logfile

exit 0;
