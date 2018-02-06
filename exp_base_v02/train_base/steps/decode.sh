#!/bin/bash

# Copyright 2012  Johns Hopkins University (Author: Daniel Povey)
# Apache 2.0

# Begin configuration section.
transform_dir=   # this option won't normally be used, but it can be used if you want to
                 # supply existing fMLLR transforms when decoding.
iter=
model= # You can specify the model to use (e.g. if you want to use the .alimdl)
stage=0
nj=4
cmd=run.pl
max_active=7000
beam=13.0
lattice_beam=6.0
acwt=0.083333 # note: only really affects pruning (scoring is on lattices).
num_threads=1 # if >1, will use gmm-latgen-faster-parallel
parallel_opts=  # ignored now.
scoring_opts=
# note: there are no more min-lmwt and max-lmwt options, instead use
# e.g. --scoring-opts "--min-lmwt 1 --max-lmwt 20"
skip_scoring=false
# End configuration section.

echo "$0 $@"  # Print the command line for logging
# $0: 실행한 명령(또는 스크립트)의 이름 (ex: decode.sh). 스크립트 파일 이름를 나타냅니다.
# $@: 모든 positional parameter들.
# $@, $* 는 positional parameters 전부를 포함합니다. array 에서 사용되는 @ , * 기호와 의미가 같다고 볼 수 있습니다. 변수를 quote 하지 않으면 단어분리에 의해 두 변수의 차이가 없지만 quote 을 하게 되면 "$@" 의 의미는 "$1" "$2" "$3" ... 와 같게되고 "$*" 의 의미는 "$1c$2c$3 ... " 와 같게됩니다. ( 여기서 c 는 IFS 변수값의 첫번째 문자 입니다. )+

[ -f ./path.sh ] && . ./path.sh; # source the path.
# [ -f <FILE> ]: 파일이 존재하고 regular 파일이면 true 입니다.
# [ TEST1 ] && CMD2: TEST1의 결과가 true이면 이후 CMD2를 실행한다.
. parse_options.sh || exit 1;

if [ $# != 3 ]; then
  # $#: $0 을 제외한 전체 인수의 개수를 나타냅니다.
  # [ $# != 3 ]: Positional parameter가 3개가 아니면~
   echo "Usage: steps/decode.sh [options] <graph-dir> <data-dir> <decode-dir>"
   echo "... where <decode-dir> is assumed to be a sub-directory of the directory"
   echo " where the model is."
   echo "e.g.: steps/decode.sh exp/mono/graph_tgpr data/test_dev93 exp/mono/decode_dev93_tgpr"
   echo ""
   echo "This script works on CMN + (delta+delta-delta | LDA+MLLT) features; it works out"
   echo "what type of features you used (assuming it's one of these two)"
   echo ""
   echo "main options (for others, see top of script file)"
   echo "  --config <config-file>                           # config containing options"
   echo "  --nj <nj>                                        # number of parallel jobs"
   echo "  --iter <iter>                                    # Iteration of model to test."
   echo "  --model <model>                                  # which model to use (e.g. to"
   echo "                                                   # specify the final.alimdl)"
   echo "  --cmd (utils/run.pl|utils/queue.pl <queue opts>) # how to run jobs."
   echo "  --transform-dir <trans-dir>                      # dir to find fMLLR transforms "
   echo "  --acwt <float>                                   # acoustic scale used for lattice generation "
   echo "  --scoring-opts <string>                          # options to local/score.sh"
   echo "  --num-threads <n>                                # number of threads to use, default 1."
   echo "  --parallel-opts <opts>                           # ignored now, present for historical reasons."
   exit 1;
fi


graphdir=$1
data=$2
dir=$3
srcdir=`dirname $dir`; # The model directory is one level up from decoding directory.
# `CMD`: backtick 문자는 $( ) 와 함께 명령 치환에 사용됩니다.
# 명령 치환은 표현식 안의 명령 실행 결과가 변수값 형태로 치환되어 사용되는 것으로 명령의 stdout 값이 사용됩니다. 표현식은 두 가지 형태로 동일하게 동작합니다. backtick 은 괄호형보다 타입하기가 편해서 비교적 간단한 명령을 작성할때 많이 사용합니다. 그런데 표현식을 열고 닫는 문자가 같은 관계로 nesting 하여 사용하기가 어렵습니다. 그래서 복잡한 명령을 작성하거나 nesting 이 필요할 때는 $( ) 을 사용하는게 좋습니다. 명령치환은 subshell 에서 실행됩니다.

sdata=$data/split$nj;
# / 표시는 산술연산 괄호가 있어야지만 나누기 뜻이라 여기서는 그냥 텍스트임.
# 산술연산 쓰는법: $(( )) , (( ))
# $(( )) , (( )) 는 bash 에서 산술연산을 위해 특별히 제공하는 표현식입니다. sh 에서는 $(( )) 표현식만 사용할 수 있습니다.
# 산술연산을 하는 외부 명령으로는 expr, bc 도 있습니다.
# 산술연산의 특징은 참, 거짓 값과 표현식 안에서 쓸수있는 연산자들이나 식들이 프로그램밍 언어와 같다는 점입니다. shell 에서 직접 해석하고 처리하므로 연산자를 escape 해야 한다든지 하는 제약 없이 편리하게 사용할수 있습니다. 좀 더 자세한 내용은 Special Expressions 메뉴를 참조하세요.

mkdir -p $dir/log
# mkdir -p: 현재 존재하지 않은 디렉토리의 하위디렉토리까지 생성
[[ -d $sdata && $data/feats.scp -ot $sdata ]] || split_data.sh $data $nj || exit 1;
# [[ -d <FILE> ]]: 파일이 존재하고 directory 이면 true 입니다.
# [[ FILE1 -ot FILE2 ]]: FILE1 이 FILE2 보다 수정시간이 older 면 (더 오래됐으면) true 입니다. (즉, FILE2가 더 최신파일이면 참.)
# [[ TEST 1 ]] || CMD1: 
# &&: 앞의 명령어가 성공해야 다음에 이어지는 명령어를 수행. && 메타문자는 command1 의 실행이 정상 종료하면 command2 를 실행하고 command1 이 오류로 종료할 경우는 command2 를 실행하지 않습니다.
# ||: 앞의 명령어가 실패하면 다음에 이어지는 명령어를 수행. || 메타문자는 command1 이 오류로 종료할 경우 command2 를 실행합니다. command1 이 정상 종료하면 command2 는 실행되지 않습니다.
# ;: 명령어의 성공유무와 상관없이 명령어 리스트를 순차적으로 실행. 여기서 ; 메타문자는 newline 과 같은 역할을 합니다. 1, 2 번은 각 명령들이 순서대로 실행이 됩니다. command1 이 종료돼야 그다음에 command2 가 실행되고 command2 가 실행을 종료해야 다음에 command3 이 실행됩니다.

# [[ ]]: 이것은 생긴모양에서 알수있듯이 [ ] 의 기능확장 버전입니다. [ ] 와 가장 큰 차이점은 [ ] 은 명령이고 [[ ]] 은 shell keyword 라는 점입니다. 키워드이기 때문에 일반 명령들과 달리 shell 에서 자체적으로 해석을 하고 실행하기 때문에 [ 처럼 명령이라서 생기는 여러가지 제약사항 없이 편리하게 사용할 수 있습니다. (좀 더 자세한 내용은 Special Expressions 참조 ).

echo $nj > $dir/num_jobs
# echo VAR > FILE: VAR의 내용을 FILE로 쓴다. FILE이 기존에 존재하면 기존 내용을 지우고 새롭게 덮어쓰며, FILE이 없으면 새로 만든다.

if [ -z "$model" ]; then # if --model <mdl> was not specified on the command line...
  # [ -z <STRING> ]: 스트링이 null 값을 가지고 있으면 true 입니다. (변수가 존재하지 않는 경우에도 해당됩니다.)
  if [ -z $iter ]; then model=$srcdir/final.mdl;
  else model=$srcdir/$iter.mdl; fi
fi


if [ $(basename $model) != final.alimdl ] ; then
  # Do not use the $srcpath -- look at the path where the model is
  # $(<COMMANDS>): 명령 치환.
  # basename: $path 파일 경로명에서 파일명만 반환합니다. 경로 구분어는 슬래쉬(/)나 역슬래쉬(\) 입니다. $suffix 인자가 있으면 $suffix도 경로 구분어로 됩니다.
  if [ -f $(dirname $model)/final.alimdl ] && [ -z "$transform_dir" ]; then
    # [ -f <FILE> ]: 파일이 존재하고 regular 파일이면 true 입니다.
    # dirname: 입력된 경로(또는 경로+파일)로부터 디렉토리를 추출하는 리눅스 명령어. 해당위치에 실제 파일 또는 폴더가 있든없든 상관없음. 상대경로로 입력하면 상대경로가, 절대경로로 입력하면 절대경로가 나옴. 단, ~는 실제 홈폴더 경로로 변경됨. (참고: http://zetawiki.com/wiki/%EB%A6%AC%EB%88%85%EC%8A%A4_dirname)
    # [ -z <STRING> ]: 스트링이 null 값을 가지고 있으면 true 입니다. (변수가 존재하지 않는 경우에도 해당됩니다.)
    echo -e '\n\n'
    # echo -e: Enable interpretation of the following backslash-escaped characters in each STRING.
    echo $0 'WARNING: Running speaker independent system decoding using a SAT model!'
    echo $0 'WARNING: This is OK if you know what you are doing...'
    echo -e '\n\n'
  fi
fi

for f in $sdata/1/feats.scp $sdata/1/cmvn.scp $model $graphdir/HCLG.fst; do
  [ ! -f $f ] && echo "decode.sh: no such file $f" && exit 1;
  # [ -f <FILE> ]: 파일이 존재하고 regular 파일이면 true 입니다.
  # exit 1: 오류 exit code.
done

if [ -f $srcdir/final.mat ]; then feat_type=lda; else feat_type=delta; fi
  # [ -f <FILE> ]: 파일이 존재하고 regular 파일이면 true 입니다.
  # final.mat이 있으면 feat_type은 lda고, 없으면 feat_type이 delta다.
echo "decode.sh: feature type is $feat_type";

splice_opts=`cat $srcdir/splice_opts 2>/dev/null` # frame-splicing options.
cmvn_opts=`cat $srcdir/cmvn_opts 2>/dev/null`
delta_opts=`cat $srcdir/delta_opts 2>/dev/null`
# `cat VAR 2>/dev/null`: stderr가 발생하면 바로 /dev/null에 버림으로써 화면에 에러가 보이는 것을 막아줌.
# > file: redirects stdout to file
# 1> file: redirects stdout to file
# 2> file: redirects stderr to file
# &> file: redirects stdout and stderr to file

# /dev/null: the null device it takes any input you want and throws it away. It can be used to suppress any output.

thread_string=
[ $num_threads -gt 1 ] && thread_string="-parallel --num-threads=$num_threads"

case $feat_type in
  delta) feats="ark,s,cs:apply-cmvn $cmvn_opts --utt2spk=ark:$sdata/JOB/utt2spk scp:$sdata/JOB/cmvn.scp scp:$sdata/JOB/feats.scp ark:- | add-deltas $delta_opts ark:- ark:- |";;
  lda) feats="ark,s,cs:apply-cmvn $cmvn_opts --utt2spk=ark:$sdata/JOB/utt2spk scp:$sdata/JOB/cmvn.scp scp:$sdata/JOB/feats.scp ark:- | splice-feats $splice_opts ark:- ark:- | transform-feats $srcdir/final.mat ark:- ark:- |";;
  *) echo "Invalid feature type $feat_type" && exit 1;
esac
# [ case 문 ]
# case 문에서 사용된 pattern 들은 위에서 아래로 쓰여진 순서에 따라 매칭을 하며 처음 매칭된 패턴이 실행이 되고 이후에 중복되는 매칭에 대해서는 실행이 되지 않습니다.
# case 문은 case, in, esac 키워드와 각 case 를 나타내는 pattern) 을 사용합니다.
# pattern) 의 종료 문자는 ;; 를 사용합니다.
# pattern) 에서는 | 을 구분자로 하여 여러개의 패턴을 사용할 수 있습니다.
# word, pattern 에 공백을 포함하려면 foo\ bar 와같이 escape 합니다.
# word, pattern 에서 사용되는 변수 에서는 globbing, 단어분리가 발생하지 않으므로 quote 하지 않아도 됩니다.
# * ) 는 모든 매칭을 뜻하므로 default 값으로 사용할 수 있습니다.
# case 문의 종료 상태 값은 매칭되는 경우가 없을때는 0 을, 그외는 해당 case 의 마지막 명령의 종료 상태 값이 됩니다.
# shopt -s nocasematch 옵션을 사용하면 대, 소문자 구분없이 매칭할 수 있습니다. (cf. shopt는 '쉘 옵션'의 준말.)


if [ ! -z "$transform_dir" ]; then # add transforms to features...
  # [ -z <STRING> ]: 스트링이 null 값을 가지고 있으면 true 입니다. (변수가 존재하지 않는 경우에도 해당됩니다.)
  echo "Using fMLLR transforms from $transform_dir"
  # transform_dir: this won't normally be used, but it can be used if you want to supply existing fMLLR transforms when decoding.
  [ ! -f $transform_dir/trans.1 ] && echo "Expected $transform_dir/trans.1 to exist."
  [ ! -s $transform_dir/num_jobs ] && \
    echo "$0: expected $transform_dir/num_jobs to contain the number of jobs." && exit 1;
  # [ -s <FILE> ]: 파일이 존재하고 사이즈가 0 보다 크면 (not empty) true 입니다.
  # [ ! -s <FILE> ]: 파일이 존재하지 않거나 사이즈가 0 보다 크지 않으면 (empty) true 입니다.
  
  nj_orig=$(cat $transform_dir/num_jobs)
  # $(CMD): 명령 치환. 괄호 안 명령의 결과값을 nj_orig에 할당함.
  if [ $nj -ne $nj_orig ]; then
    # Copy the transforms into an archive with an index.
    echo "$0: num-jobs for transforms mismatches, so copying them."
    for n in $(seq $nj_orig); do cat $transform_dir/trans.$n; done | \

      # [ for 문 ]
      # for 문은 for, in, do, done 키워드를 사용합니다.
      # words 는 IFS 값에따라 분리되며, words 개수만큼 반복하게 됩니다. 매 반복때 마다 name 값이 설정됩니다.
      # in words 부분을 생략하면 in "$@" 와 같게됩니다.
      # $@: 모든 포지셔널 파라미터 (위치 매개변수들).

      # 예시1:
      # for (( i=10; i<20; i++ )); do
      #     read line
      #     echo "$line"
      # done < infile > outfile

      # 예시2:
      # $ set -f; IFS=$'\n'
      #
      # $ for file in $(find -type f)
      # do
      #         echo "$file"
      # done
      # .
      # ./WriteObject.java
      # ./WriteObject.class
      # ./ReadObject.java
      # ./2013-03-19 154412.csv
      # ./ReadObject.class
      # ./쉘 스크립트 테스팅.txt
      #
      # $ set +f; IFS=$' \t\n'

      # seq: 시퀀스(sequence) 출력. 숫자열 출력 리눅스 명령어. 음수, 소수점 사용가능.
      # 예시>
      # seq 4: 1부터 4까지의 정수 숫자열 출력 (1 2 3 4)
      # seq 8 10: 8부터 10까지의 정수 숫자열 출력 (8 9 10)
      # seq 3 -3 -6: 3부터 -3 간격으로 -6까지의 정수 숫자열 출력 (3 0 -3 -6)
      # seq 10 .05 10.1: (10.00 10.05 10.10)
       copy-feats ark:- ark,scp:$dir/trans.ark,$dir/trans.scp || exit 1;
    feats="$feats transform-feats --utt2spk=ark:$sdata/JOB/utt2spk scp:$dir/trans.scp ark:- ark:- |"
  else
    # number of jobs matches with alignment dir.
    feats="$feats transform-feats --utt2spk=ark:$sdata/JOB/utt2spk ark:$transform_dir/trans.JOB ark:- ark:- |"
  fi
fi

# [TIP] Detect if variable is an array:
# $ declare -p variable-name 2> /dev/null | grep -q 'declare \-a'


if [ $stage -le 0 ]; then
  if [ -f "$graphdir/num_pdfs" ]; then
  # [ -f <FILE> ]: 파일이 존재하고 regular 파일이면 true 입니다.
    [ "`cat $graphdir/num_pdfs`" -eq `am-info --print-args=false $model | grep pdfs | awk '{print $NF}'` ] || \
    # awk '{print $NF}': 각 줄(row)의 마지막 필드(column) 출력.
      { echo "Mismatch in number of pdfs with $model"; exit 1; }
  fi
      # [ { } 는 shell keyword ]
      # { } 는 메타문자가 아니고 키워드로, 매개변수 확장, 명령 그룹, 함수 정의, brace 확장에 사용됩니다.
      # 예시>
      # # 매개변수 확장
      # $AA, ${AA}, ${AA:-0}, ${AA//Linux/Unix} 
      #
      # # 명령 그룹
      # { echo 1; echo 2; echo 3 ;}    # 명령 위치에서 사용되므로 shell keyword 
      #
      # # 함수 정의
      # f1() { echo 1 ;}
      #
      # # brace 확장
      # echo file{1..5}
      #
      # # 다음과 같은 경우는 find 명령의 인수에 해당하는 문자
      # $ find . -name '*.o' -exec rm -f {} \;
      #
      # Q: '-f {} \;'??
      #
      # 다음은 모든 종류의 공백 문자를 포함하는 파일들을 처리하겠습니다.
      # $find . -name "* *" -exec rm -f {} \;
      # "find"가 찾은 파일이름이 "{}"로 바뀝니다.
      # '\'를 써서 ';'가 명령어 끝을 나타낸다는 원래의 의미로 해석되게 합니다.
      #
      # $ find PATTERN -exec COMMAND \;
      # find가 찾아낸 각각의 파일에 대해 COMMAND를 실행합니다. COMMAND는 \;으로 끝나야 합니다(find로 넘어가는 명령어의 끝을 나타내는 ;를 쉘이 해석하지 않도록 이스케이프 시켜야 합니다).
      # COMMAND에 {}이 포함되어 있으면 선택된 파일을 완전한 경로명으로 바꿔 줍니다.
      # cf. https://wiki.kldp.org/HOWTO/html/Adv-Bash-Scr-HOWTO/moreadv.html

  $cmd --num-threads $num_threads JOB=1:$nj $dir/log/decode.JOB.log \
    # cf. cmd=run.pl
    gmm-latgen-faster$thread_string --max-active=$max_active --beam=$beam --lattice-beam=$lattice_beam \
    --acoustic-scale=$acwt --allow-partial=true --word-symbol-table=$graphdir/words.txt \
    $model $graphdir/HCLG.fst "$feats" "ark:|gzip -c > $dir/lat.JOB.gz" || exit 1;
fi

if [ $stage -le 1 ]; then
  [ ! -z $iter ] && iter_opt="--iter $iter"
  # [ -z <STRING> ]: 스트링이 null 값을 가지고 있으면 true 입니다. (변수가 존재하지 않는 경우에도 해당됩니다.)
  steps/diagnostic/analyze_lats.sh --cmd "$cmd" $iter_opt $graphdir $dir
fi

if ! $skip_scoring ; then
  # cf. skip_scoring=false
  [ ! -x local/score.sh ] && \
    echo "Not scoring because local/score.sh does not exist or not executable." && exit 1;
  local/score.sh --cmd "$cmd" $scoring_opts $data $graphdir $dir ||
    { echo "$0: Scoring failed. (ignore by '--skip-scoring true')"; exit 1; }
fi

exit 0;
