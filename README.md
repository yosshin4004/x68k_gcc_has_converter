# x68k_gcc_has_converter


# 解説

x68k_gcc_has_converter は、
m68k-elf-gcc（モトローラ 680x0 のクロスコンパイルに対応した gcc）が生成する gas 形式のアセンブラソースを、
X68K で広く利用されたアセンブラである HAS.X (X68K High-speed Assembler by Y.Nakamura(YuNK)) が処理可能な形式に変換するツールです。

本ツールを利用することで、最新の gcc でクロスコンパイルしたコードを X68K のオブジェクトファイル形式に変換し、
過去のソフトウェア資産（例えば SHARP XC コンパイラに含まれるライブラリ群など）とリンクすることが可能になります。


# 利用例

例として、example.c を X68K のオブジェクトファイルに変換する手順を示します。

以下を POSIX 環境上（Linux 等）で実行します。
（クロスコンパイラである m68k-elf-gcc の生成手順は後述します。）

```bash
# example.c をコンパイルする。
# X68K と ABI を一致させるため d2 a2 を破壊可能レジスタとして指定する。
m68k-elf-gcc example.c -S -Os -m68000 -fcall-used-d2 -fcall-used-a2 -o example.m68k_gas.s

# HAS.X が処理可能なフォーマットに変換する。
perl x68k_gcc_has_converter.pl -i example.m68k_gas.s -o example.s
```
カレントディレクトリに example.s が得られます。

続いて、以下を X68K 上で実行します。
```bat
rem HAS.X を実行し、X68K のオブジェクトファイルに変換する。
rem -u : 未定義シンボルを外部参照にする 
rem -e : 外部参照オフセットをロングワードにする 
rem -w 0 : 警告の抑制
HAS.X -e -u -w 0 -o example.o example.s
```

カレントディレクトリに example.o が得られます。
このファイルは、既存の X68K の資産とリンク可能です。



# HAS.X 形式変換例

HAS.X 形式に変換したアセンブラソースの例を示します。
変換後の各行には、コメントで m68k-elf-gcc が生成した gas 形式の元ソースが記載されています。

次に示すように、gas 形式では movem 命令のレジスタマスクが #7952 のような数値になっていますが、
HAS.X 形式では d3/d4/d5/d6/d7/a3 のような可読性のあるレジスタリスト表記になります。

```
* NO_APP
RUNS_HUMAN_VERSION      equ     3
        .cpu 68000
* X68 GCC Develop
                                                        *#NO_APP
        .file   "adler32.c"                             *       .file   "adler32.c"
        .text                                           *       .text
        .globl ___umodsi3                               *       .globl  __umodsi3
        .globl ___modsi3                                *       .globl  __modsi3
        .globl ___mulsi3                                *       .globl  __mulsi3
        .align  2                                       *       .align  2
                                                        *       .type   adler32_combine_, @function
_adler32_combine_:                                      *adler32_combine_:
        movem.l d3/d4/d5/d6/d7/a3,-(sp)                 *       movem.l #7952,-(%sp)
        move.l 28(sp),d3                                *       move.l 28(%sp),%d3
        move.l 32(sp),d6                                *       move.l 32(%sp),%d6
        move.l 36(sp),d0                                *       move.l 36(%sp),%d0
        jbmi _?L6                                       *       jmi .L6
        lea ___umodsi3,a3                               *       lea __umodsi3,%a3
        move.l #65521,-(sp)                             *       move.l #65521,-(%sp)
        move.l d0,-(sp)                                 *       move.l %d0,-(%sp)
        jbsr (a3)                                       *       jsr (%a3)
        addq.l #8,sp                                    *       addq.l #8,%sp
        move.l d0,d5                                    *       move.l %d0,%d5
        move.l d3,d7                                    *       move.l %d3,%d7
        and.l #65535,d7                                 *       and.l #65535,%d7
        move.l d7,-(sp)                                 *       move.l %d7,-(%sp)
        move.l d0,-(sp)                                 *       move.l %d0,-(%sp)
```


また次に示すように、char 型配列は gas 形式では可読性の悪いエスケープシーケンスと 8 進数エンコード混在表記となりますが、
HAS.X 形式では素直な 16 進数二桁の配列表記となります。

```
        .globl __length_code                            *       .globl  _length_code
                                                        *       .type   _length_code, @object
                                                        *       .size   _length_code, 256
__length_code:                                          *_length_code:

        .dc.b $00                                       *       .string ""
        .dc.b $01,$02,$03,$04,$05,$06,$07,$08
        .dc.b $08,$09,$09,$0a,$0a,$0b,$0b,$0c
        .dc.b $0c,$0c,$0c,$0d,$0d                       *       .ascii  "\001\002\003\004\005\006\007\b\b\t\t\n\n\013\013\f\f\f\f\r\r"
        .dc.b $0d,$0d,$0e,$0e,$0e,$0e,$0f,$0f
        .dc.b $0f,$0f,$10,$10,$10,$10,$10,$10           *       .ascii  "\r\r\016\016\016\016\017\017\017\017\020\020\020\020\020\020"
        .dc.b $10,$10,$11,$11,$11,$11,$11,$11
        .dc.b $11,$11,$12,$12,$12,$12,$12               *       .ascii  "\020\020\021\021\021\021\021\021\021\021\022\022\022\022\022"
        .dc.b $12,$12,$12,$13,$13,$13,$13,$13
        .dc.b $13,$13,$13,$14,$14,$14,$14               *       .ascii  "\022\022\022\023\023\023\023\023\023\023\023\024\024\024\024"
        .dc.b $14,$14,$14,$14,$14,$14,$14,$14
        .dc.b $14,$14,$14,$14,$15,$15,$15               *       .ascii  "\024\024\024\024\024\024\024\024\024\024\024\024\025\025\025"
        .dc.b $15,$15,$15,$15,$15,$15,$15,$15
        .dc.b $15,$15,$15,$15,$15,$16,$16               *       .ascii  "\025\025\025\025\025\025\025\025\025\025\025\025\025\026\026"
        .dc.b $16,$16,$16,$16,$16,$16,$16,$16
        .dc.b $16,$16,$16,$16,$16,$16,$17               *       .ascii  "\026\026\026\026\026\026\026\026\026\026\026\026\026\026\027"
        .dc.b $17,$17,$17,$17,$17,$17,$17,$17
        .dc.b $17,$17,$17,$17,$17,$17,$17               *       .ascii  "\027\027\027\027\027\027\027\027\027\027\027\027\027\027\027"
        .dc.b $18,$18,$18,$18,$18,$18,$18,$18
        .dc.b $18,$18,$18,$18,$18,$18,$18               *       .ascii  "\030\030\030\030\030\030\030\030\030\030\030\030\030\030\030"
        .dc.b $18,$18,$18,$18,$18,$18,$18,$18
        .dc.b $18,$18,$18,$18,$18,$18,$18               *       .ascii  "\030\030\030\030\030\030\030\030\030\030\030\030\030\030\030"
        .dc.b $18,$18,$19,$19,$19,$19,$19,$19
        .dc.b $19,$19,$19,$19,$19,$19,$19               *       .ascii  "\030\030\031\031\031\031\031\031\031\031\031\031\031\031\031"
        .dc.b $19,$19,$19,$19,$19,$19,$19,$19
        .dc.b $19,$19,$19,$19,$19,$19,$19               *       .ascii  "\031\031\031\031\031\031\031\031\031\031\031\031\031\031\031"
        .dc.b $19,$19,$19,$19,$1a,$1a,$1a,$1a
        .dc.b $1a,$1a,$1a,$1a,$1a,$1a,$1a               *       .ascii  "\031\031\031\031\032\032\032\032\032\032\032\032\032\032\032"
        .dc.b $1a,$1a,$1a,$1a,$1a,$1a,$1a,$1a
        .dc.b $1a,$1a,$1a,$1a,$1a,$1a,$1a               *       .ascii  "\032\032\032\032\032\032\032\032\032\032\032\032\032\032\032"
        .dc.b $1a,$1a,$1a,$1a,$1a,$1a,$1b,$1b
        .dc.b $1b,$1b,$1b,$1b,$1b,$1b,$1b               *       .ascii  "\032\032\032\032\032\032\033\033\033\033\033\033\033\033\033"
        .dc.b $1b,$1b,$1b,$1b,$1b,$1b,$1b,$1b
        .dc.b $1b,$1b,$1b,$1b,$1b,$1b,$1b               *       .ascii  "\033\033\033\033\033\033\033\033\033\033\033\033\033\033\033"
        .dc.b $1b,$1b,$1b,$1b,$1b,$1b,$1b,$1c           *       .ascii  "\033\033\033\033\033\033\033\034"
```

# 補足：m68k-elf-gcc の作成方法

m68k-elf-gcc（モトローラ 680x0 のクロスコンパイルに対応した gcc）は、以下の手順で作成可能です。
（POSIX 環境必須。Linux 推奨。msys では完走できない。他環境は未テスト）。


>:warning:
>Linux のディストリビューターが提供してる m68k-linux-gnu-gcc などのビルド済み gcc は、X68K と ABI が異なる（関数の戻り値が d0 または a0 に格納されていることを期待する）場合があり、生成されたコードを既存の X68K 資産とリンクすることは不可能です。この問題を回避するには、ここで解説しているように gcc 自体をソースコードからビルドする必要があります。


```bash
#-----------------------------------------------------------------------------
# settings
#-----------------------------------------------------------------------------

PREFIX="m68k-elf-"
CPU="m68000"

# binutils
BINUTILS_VERSION="2.35"
BINUTILS_ARCHIVE="binutils-${BINUTILS_VERSION}.tar.bz2"
BINUTILS_URL="https://ftp.gnu.org/gnu/binutils/${BINUTILS_ARCHIVE}"
BINUTILS_DIR="binutils-${BINUTILS_VERSION}"

# gcc
GCC_VERSION="10.2.0"
GCC_ARCHIVE="gcc-${GCC_VERSION}.tar.gz"
GCC_URL="https://gcc.gnu.org/pub/gcc/releases/gcc-${GCC_VERSION}/${GCC_ARCHIVE}"
GCC_DIR="gcc-${GCC_VERSION}"

# newlib
NEWLIB_VERSION="3.3.0"
NEWLIB_ARCHIVE="newlib-${NEWLIB_VERSION}.tar.gz"
NEWLIB_URL="ftp://sourceware.org/pub/newlib/${NEWLIB_ARCHIVE}"
NEWLIB_DIR="newlib-${NEWLIB_VERSION}"


#-----------------------------------------------------------------------------
# prepare
#-----------------------------------------------------------------------------

TARGET="m68k-elf"
NUM_PROC=$(nproc)
PROGRAM_PREFIX=${PREFIX}
ROOT_DIR="${PWD}"
INSTALL_DIR="${ROOT_DIR}/m68k-toolchain"
DOWNLOAD_DIR="${ROOT_DIR}/download"
BUILD_DIR="${ROOT_DIR}/build"
SRC_DIR="${ROOT_DIR}/source"
WITH_CPU=${CPU}

mkdir -p ${INSTALL_DIR}
mkdir -p ${BUILD_DIR}
mkdir -p ${SRC_DIR}
mkdir -p ${DOWNLOAD_DIR}


#-----------------------------------------------------------------------------
# binutils
#-----------------------------------------------------------------------------

mkdir -p ${BUILD_DIR}/${BINUTILS_DIR}

cd ${DOWNLOAD_DIR}
if ! [ -f "${BINUTILS_ARCHIVE}" ]; then
    wget ${BINUTILS_URL}
fi
tar jxvf ${BINUTILS_ARCHIVE} -C ${SRC_DIR}

cd ${BUILD_DIR}/${BINUTILS_DIR}
${SRC_DIR}/${BINUTILS_DIR}/configure \
    --prefix=${INSTALL_DIR} \
    --program-prefix=${PROGRAM_PREFIX} \
    --target=${TARGET} \
    --enable-lto \
    --enable-interwork \
    --enable-multilib \

make -j${NUM_PROC} 2<&1 | tee build.log
make install -j${NUM_PROC} 2<&1 | tee build.log

export PATH=${INSTALL_DIR}/bin:${PATH}

cd ${ROOT_DIR}


#-----------------------------------------------------------------------------
# gcc stage1
#-----------------------------------------------------------------------------

mkdir -p ${BUILD_DIR}/${GCC_DIR}_stage1

cd ${DOWNLOAD_DIR}
if ! [ -f "${GCC_ARCHIVE}" ]; then
    wget ${GCC_URL}
fi
tar xvf ${GCC_ARCHIVE} -C ${SRC_DIR}

cd ${SRC_DIR}/${GCC_DIR}
./contrib/download_prerequisites

cd ${BUILD_DIR}/${GCC_DIR}_stage1
${SRC_DIR}/${GCC_DIR}/configure \
    --prefix=${INSTALL_DIR} \
    --program-prefix=${PROGRAM_PREFIX} \
    --target=${TARGET} \
    --enable-lto \
    --enable-languages=c \
    --without-headers \
    --with-cpu=${WITH_CPU} \
    --with-newlib \
    --enable-interwork \
    --enable-multilib \
    --disable-shared \
    --disable-threads \

make -j${NUM_PROC} 2<&1 | tee build.log
make install 2<&1 | tee build.log
make -j${NUM_PROC} all-target-libgcc 2<&1 | tee build.log
make install-target-libgcc 2<&1 | tee build.log

cd ${ROOT_DIR}


#-----------------------------------------------------------------------------
# newlib
#-----------------------------------------------------------------------------

mkdir ${BUILD_DIR}/${NEWLIB_DIR}

if ! [ -f "${NEWLIB_ARCHIVE}" ]; then
    wget ${NEWLIB_URL}
fi
tar zxvf ${NEWLIB_ARCHIVE} -C ${SRC_DIR}

export CC_FOR_TARGET=${PROGRAM_PREFIX}gcc
export LD_FOR_TARGET=${PROGRAM_PREFIX}ld
export AS_FOR_TARGET=${PROGRAM_PREFIX}as
export AR_FOR_TARGET=${PROGRAM_PREFIX}ar
export RANLIB_FOR_TARGET=${PROGRAM_PREFIX}ranlib
export newlib_cflags="${newlib_cflags} -DPREFER_SIZE_OVER_SPEED -D__OPTIMIZE_SIZE__"

cd ${BUILD_DIR}/${NEWLIB_DIR}
${SRC_DIR}/${NEWLIB_DIR}/configure \
    --prefix=${INSTALL_DIR} \
    --target=${TARGET} \

make -j${NUM_PROC} 2<&1 | tee build.log
make install | tee build.log

cd ${ROOT_DIR}


#-----------------------------------------------------------------------------
# gcc stage2
#-----------------------------------------------------------------------------

mkdir -p ${BUILD_DIR}/${GCC_DIR}_stage2

cd ${BUILD_DIR}/${GCC_DIR}_stage2
${SRC_DIR}/${GCC_DIR}/configure \
    --prefix=${INSTALL_DIR} \
    --program-prefix=${PROGRAM_PREFIX} \
    --target=${TARGET} \
    --enable-lto \
    --enable-languages=c,c++ \
    --with-cpu=${WITH_CPU} \
    --with-newlib \
    --enable-interwork \
    --enable-multilib \
    --disable-shared \
    --disable-threads \

make -j${NUM_PROC} 2<&1 | tee build.log
make install 2<&1 | tee build.log
make -j${NUM_PROC} all-target-libgcc 2<&1 | tee build.log
make install-target-libgcc 2<&1 | tee build.log

cd ${ROOT_DIR}
```

# ライセンス

Apache License Version 2.0 が適用されます。

