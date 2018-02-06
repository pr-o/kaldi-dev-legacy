#!/bin/bash
# Copyright 2010-2012 Microsoft Corporation
#           2012-2013 Johns Hopkins University (Author: Daniel Povey)
# Apache 2.0

# This script creates a fully expanded decoding graph (HCLG) that represents
# all the language-model, pronunciation dictionary (lexicon), context-dependency,
# and HMM structure in our model.  The output is a Finite State Transducer
# that has word-ids on the output, and pdf-ids on the input (these are indexes
# that resolve to Gaussian Mixture Models).
# See
#  http://kaldi-asr.org/doc/graph_recipe_test.html
# (this is compiled from this repository using Doxygen,
# the source for this part is in src/doc/graph_recipe_test.dox)

# Causes a pipeline to return the exit status of the last command
# in the pipe that returned a non-zero return value.
set -o pipefail
# set -o pipefail: 
# 파이프로 연결된 명령들이 실행될때는 마지막 명령의 종료 상태 값이 true, false 를 판단하는데 사용됩니다. 하지만 이 옵션을 설정하면 연결된 명령들 중에 하나라도 false 이면 false 가 됩니다.


tscale=1.0
loopscale=0.1

remove_oov=false

for x in `seq 6`; do
  # `seq 6` == 1 2 3 4 5 6 (equiv. to len(0,6))
  # cf. http://snoopybox.co.kr/1680
  [ "$1" == "--mono" ] && context=mono && shift;
  # [ (expression) ]: test if TRUE/FALSE
  # &&: 앞의 명령/명제가 참이면 뒤 명령을 진행
  [ "$1" == "--left-biphone" ] && context=lbiphone && shift;
  [ "$1" == "--quinphone" ] && context=quinphone && shift;
  [ "$1" == "--remove-oov" ] && remove_oov=true && shift;
  [ "$1" == "--transition-scale" ] && tscale=$2 && shift 2;
  [ "$1" == "--self-loop-scale" ] && loopscale=$2 && shift 2;
  # shift [n]: 
  # shift 명령은 현재 설정되어 있는 positional parameters 를 좌측으로 n 만큼 이동시킵니다. 결과로 n 개의 positional parameters 가 삭제 됩니다.
done

if [ $# != 3 ]; then
  # $#: $0 을 제외한 전체 인수의 개수를 나타냅니다.
  # $0: 스크립트 파일 이름를 나타냅니다. bash -c 형식으로 실행했을 경우는 첫번째 인수를 가리킵니다.
   echo "Usage: utils/mkgraph.sh [options] <lang-dir> <model-dir> <graphdir>"
   echo "e.g.: utils/mkgraph.sh data/lang_test exp/tri1/ exp/tri1/graph"
   echo " Options:"
   echo " --mono          #  For monophone models."
   echo " --quinphone     #  For models with 5-phone context (3 is default)"
   echo " --left-biphone  #  For left biphone models"
   echo "For other accepted options, see top of script."
   exit 1;
   # [ Exit status ]
   # 0: 정상종료 (success)
   # 1: 일반적인 에러
   # 2: 신택스 에러
   # 126: 명령 실행불가. 명령은 존재하지만 excutable 이 아니거나 퍼미션 문제.
   # 127: 명령 (파일) 이 존재하지 않음. typo 또는 $PATH 문제
   # 128 + N: Signal N에 의한 종료.
fi

if [ -f path.sh ]; then . ./path.sh; fi
  # -f <FILE>: 파일이 존재하고 regular 파일이면 true 입니다.

lang=$1
tree=$2/tree
model=$2/final.mdl
dir=$3

mkdir -p $dir

# If $lang/tmp/LG.fst does not exist or is older than its sources, make it...
# (note: the [[ ]] brackets make the || type operators work (inside [ ], we
# would have to use -o instead),  -f means file exists, and -ot means older than).

required="$lang/L.fst $lang/G.fst $lang/phones.txt $lang/words.txt $lang/phones/silence.csl $lang/phones/disambig.int $model $tree"
for f in $required; do
  [ ! -f $f ] && echo "mkgraph.sh: expected $f to exist" && exit 1;
  # exit[n]:
  # shell 을 exit 합니다. n 은 종료 상태 값이 되며 $? 를 통해 구할수 있습니다. n 값을 설정하지 않으면 이전 명령의 종료 상태 값이 사용됩니다.+
done

if [ -f $dir/HCLG.fst ]; then
  # detect when the result already exists, and avoid overwriting it.
  must_rebuild=false
  for f in $required; do
    [ $f -nt $dir/HCLG.fst ] && must_rebuild=true
    # <FILE1> -nt <FILE2>:
    # FILE1 이 FILE2 보다 수정시간이 newer 면 true 입니다.
  done
  if ! $must_rebuild; then
    echo "$0: $dir/HCLG.fst is up to date."
    exit 0
  fi
fi


N=$(tree-info $tree | grep "context-width" | cut -d' ' -f2) || { echo "Error when getting context-width"; exit 1; }
# $( <COMMANDS> ) 또는 `<COMMANDS>`: 명령 치환.
# command1 || command2:
# || 메타문자는 command1 이 오류로 종료할 경우 command2 를 실행합니다. command1 이 정상 종료하면 command2 는 실행되지 않습니다.
# { command1; command2; command3; . . . commandN; }: 
# A code block between curly brackets does not launch a subshell.
# 코드 블럭. [중괄호]  "인라인 그룹"이라고도 부르는 중괄호 한 쌍은 실제로 익명의 함수를 만들어 냅니다만 보통의 함수와는 달리 코드 블럭 안의 변수들을 스크립트의 다른 곳에서 볼 수가 있습니다.
P=$(tree-info $tree | grep "central-position" | cut -d' ' -f2) || { echo "Error when getting central-position"; exit 1; }
# cut -d' ' -f2: 구분자는 공백, 두번째 문자열 가져오기

if [[ $context == mono && ($N != 1 || $P != 0) || \
      $context == lbiphone && ($N != 2 || $P != 1) || \
      $context == quinphone && ($N != 5 || $P != 2) ]]; then
  echo "mkgraph.sh: mismatch between the specified context (--$context) and the one in the tree: N=$N, P=$P"
  exit 1
fi
# [[ ]]:
# 이것은 생긴모양에서 알수있듯이 [ ] 의 기능확장 버전입니다. [ ] 와 가장 큰 차이점은 [ ] 은 명령이고 [[ ]] 은 shell keyword 라는 점입니다. 키워드이기 때문에 일반 명령들과 달리 shell 에서 자체적으로 해석을 하고 실행하기 때문에 [ 처럼 명령이라서 생기는 여러가지 제약사항 없이 편리하게 사용할 수 있습니다.

[[ -f $2/frame_subsampling_factor && $loopscale != 1.0 ]] && \
  echo "$0: WARNING: chain models need '--self-loop-scale 1.0'";

mkdir -p $lang/tmp
# mkdir -p:
# 참고로 mkdir –p는 상위 부모 디렉토리까지 (없다면) 모두 생성할 것입니다.
# Note: [[ ]] is like [ ] but enables certain extra constructs, e.g. || in
# place of -o
if [[ ! -s $lang/tmp/LG.fst || $lang/tmp/LG.fst -ot $lang/G.fst || \
      $lang/tmp/LG.fst -ot $lang/L_disambig.fst ]]; then
      # -s <FILE>: 파일이 존재하고 사이즈가 0 보다 크면 (not empty) true 입니다.
      # <FILE1> -ot <FILE2>: FILE1 이 FILE2 보다 수정시간이 older 면 true 입니다.
  fsttablecompose $lang/L_disambig.fst $lang/G.fst | fstdeterminizestar --use-log=true | \
    fstminimizeencoded | fstpushspecial | \
    fstarcsort --sort_type=ilabel > $lang/tmp/LG.fst || exit 1;
  fstisstochastic $lang/tmp/LG.fst || echo "[info]: LG not stochastic."
  # fsttablecompose like fstcompose but faster (uses heuristics that OpenFst authors would find ugly)
  # fstminimizeencoded is a convenience mechanism (would require several native OpenFst commands)
  # fstdeterminizestar is like fstdeterminize but does epsilon-removal as part of determinization.
fi


# yogikkaji

clg=$lang/tmp/CLG_${N}_${P}.fst
# ${N}: 

if [[ ! -s $clg || $clg -ot $lang/tmp/LG.fst ]]; then
  fstcomposecontext --context-size=$N --central-position=$P \
   --read-disambig-syms=$lang/phones/disambig.int \
   --write-disambig-syms=$lang/tmp/disambig_ilabels_${N}_${P}.int \
    $lang/tmp/ilabels_${N}_${P} < $lang/tmp/LG.fst |\
    fstarcsort --sort_type=ilabel > $clg
  fstisstochastic $clg  || echo "[info]: CLG not stochastic."
fi

if [[ ! -s $dir/Ha.fst || $dir/Ha.fst -ot $model  \
    || $dir/Ha.fst -ot $lang/tmp/ilabels_${N}_${P} ]]; then
  make-h-transducer --disambig-syms-out=$dir/disambig_tid.int \
    --transition-scale=$tscale $lang/tmp/ilabels_${N}_${P} $tree $model \
     > $dir/Ha.fst  || exit 1;
fi

if [[ ! -s $dir/HCLGa.fst || $dir/HCLGa.fst -ot $dir/Ha.fst || \
      $dir/HCLGa.fst -ot $clg ]]; then
  if $remove_oov; then
    [ ! -f $lang/oov.int ] && \
      echo "$0: --remove-oov option: no file $lang/oov.int" && exit 1;
    clg="fstrmsymbols --remove-arcs=true --apply-to-output=true $lang/oov.int $clg|"
  fi
  fsttablecompose $dir/Ha.fst "$clg" | fstdeterminizestar --use-log=true \
    | fstrmsymbols $dir/disambig_tid.int | fstrmepslocal | \
     fstminimizeencoded > $dir/HCLGa.fst || exit 1;
  fstisstochastic $dir/HCLGa.fst || echo "HCLGa is not stochastic"
fi

if [[ ! -s $dir/HCLG.fst || $dir/HCLG.fst -ot $dir/HCLGa.fst ]]; then
  add-self-loops --self-loop-scale=$loopscale --reorder=true \
    $model < $dir/HCLGa.fst > $dir/HCLG.fst || exit 1;

  if [ $tscale == 1.0 -a $loopscale == 1.0 ]; then
    # No point doing this test if transition-scale not 1, as it is bound to fail.
    fstisstochastic $dir/HCLG.fst || echo "[info]: final HCLG is not stochastic."
  fi
fi

# note: the empty FST has 66 bytes.  this check is for whether the final FST
# is the empty file or is the empty FST.
if ! [ $(head -c 67 $dir/HCLG.fst | wc -c) -eq 67 ]; then
  echo "$0: it looks like the result in $dir/HCLG.fst is empty"
  exit 1
fi

# save space.
rm $dir/HCLGa.fst $dir/Ha.fst 2>/dev/null || true

# keep a copy of the lexicon and a list of silence phones with HCLG...
# this means we can decode without reference to the $lang directory.


cp $lang/words.txt $dir/ || exit 1;
mkdir -p $dir/phones
cp $lang/phones/word_boundary.* $dir/phones/ 2>/dev/null # might be needed for ctm scoring,
cp $lang/phones/align_lexicon.* $dir/phones/ 2>/dev/null # might be needed for ctm scoring,
cp $lang/phones/optional_silence.* $dir/phones/ 2>/dev/null # might be needed for analyzing alignments.
  # but ignore the error if it's not there.

cp $lang/phones/disambig.{txt,int} $dir/phones/ 2> /dev/null
cp $lang/phones/silence.csl $dir/phones/ || exit 1;
cp $lang/phones.txt $dir/ 2> /dev/null # ignore the error if it's not there.

# to make const fst:
# fstconvert --fst_type=const $dir/HCLG.fst $dir/HCLG_c.fst
am-info --print-args=false $model | grep pdfs | awk '{print $NF}' > $dir/num_pdfs
