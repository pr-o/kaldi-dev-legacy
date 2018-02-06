#!/bin/bash

# Input path setting
train_given=./inputs/train_given

##########################################
# Kaldi path setting
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

##########################################
### 0. Input(given) data check ###
##########################################

for x in "$train_given/wav.scp" "$train_given/text" "$train_given/textraw" "$train_given/lexicon.txt" "$train_given/utt2spk" "$train_given/segments"
    # Required data in $train_given/:
    #   1) wav.scp
    #   2) text
    #   3) textraw
    #   4) lexicon.txt
    #   5) utt2spk
    #   6) segments
do
    if [ ! -f $x ]
    then
    echo "No file - $x"
    exit 0;
    fi
done

##########################################
### 1. Set default paths and make dirs ###
##########################################

train_created=./outputs/train
lang_dir=./outputs/lang_train
data_dir=./outputs/data/train_dir
# fst_dir=./outputs/LGfst

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
### 2. Data / Lexicon / LM preparation
##########################################

echo "Start." `date` > $logfile

# Fix data before getting started
utils/fix_data_dir.sh $train_given

# Directly copy {wav.scp, text, utt2spk, segments, textraw} to $data_dir (no additional works needed)
cp $train_given/wav.scp $data_dir/
cp $train_given/text $data_dir/
cp $train_given/utt2spk $data_dir/
cp $train_given/segments $data_dir/
cp $train_given/textraw $data_dir/

# 1) lexicon.txt (temporary)
# Remove <unk> from lexicon.txt
sed '/<unk>/d' $train_given/lexicon.txt > $tmp_dir/tmp.txt
cp $tmp_dir/tmp.txt $train_given/lexicon.txt

# 2) nonsilence_phones.txt
# Create nonsilence_phones.txt from lexicon.txt
# (NB. lexicon.txt에서 단어와 발음열 간 경계는 tab이 아닌 ' '(single space).)
cut -d ' ' -f 2- $train_given/lexicon.txt | tr ' ' '\n' | sed '/^$/d' | sort -u > $train_created/nonsilence_phones.txt
# Remove 'sil' from nonsilence_phones.txt
sed '/sil/d' $train_created/nonsilence_phones.txt > $tmp_dir/tmp.txt
mv $tmp_dir/tmp.txt $train_created/nonsilence_phones.txt

# 3) spk2utt
# Create spk2utt from utt2spk
utils/utt2spk_to_spk2utt.pl $train_given/utt2spk > $data_dir/spk2utt    

# 4) optional_silence.txt
# Create optional_silence.txt ('sil')
echo "sil" > $train_created/optional_silence.txt

# 5) silence_phones.txt
# Create silence_phones.txt ('sil' and '<unk>')
echo -e "sil\n<unk>" > $train_created/silence_phones.txt

# 6) extra_questions.txt
# Create extra_questions.txt from {nonsilence,silence}_phones.txt
cat $train_created/silence_phones.txt| awk '{printf("%s ", $1);} END{printf "\n";}' > $train_created/extra_questions.txt || exit 1;    
cat $train_created/nonsilence_phones.txt | perl -e 'while(<>){ foreach $p (split(" ", $_)) {  $p =~ m:^([^\d]+)(\d*)$: || die "Bad phone $_"; $q{$2} .= "$p "; } } foreach $l (values %q) {print "$l\n";}' >> $train_created/extra_questions.txt || exit 1;    

# 7) lexicon.txt (final touch)
# Add a line of '<unk> <unk>' to lexicon.txt
ed -s $train_given/lexicon.txt <<< $'1i\n<unk> <unk>\n.\nwq'
cp $train_given/lexicon.txt $train_created

echo "data & language part" `date` >> $logfile


##########################################
### 3. L & G.fst
##########################################

# 1) L.fst and {phones,words,...}.txt
# Create L.fst and a set of relevant files by prepare_lang.sh
utils/prepare_lang.sh \
    $train_created "<unk>" \
    $train_created/tmp \
    $lang_dir

# 2) G.fst
# Create lm.arpa using ngram-count in SRILM
$KALDI_ROOT/tools/srilm/bin/i686-m64/ngram-count -text $data_dir/textraw -lm $lang_dir/lm.arpa
# ngram-count -text $data_dir/textraw -lm $lang_dir/lm.arpa

# Create G.fst using arpa2fst in Kaldi
cat $lang_dir/lm.arpa | $KALDI_ROOT/src/lmbin/arpa2fst --disambig-symbol=#0 --read-symbol-table=$lang_dir/words.txt - $lang_dir/G.fst
$KALDI_ROOT/src/fstbin/fstisstochastic $lang_dir/G.fst


########## end ##########
echo "End." `date` >> $logfile

exit 0;

