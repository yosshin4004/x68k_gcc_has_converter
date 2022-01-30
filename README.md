# x68k_gcc_has_converter


# 解説

x68k_gcc_has_converter は、
m68k-elf-gcc（モトローラ 680x0 のクロスコンパイルに対応した gcc）が生成する gas 形式のアセンブラソースを、
X68K のデファクトスタンダードなアセンブラである
HAS.X (X68K High-speed Assembler by Y.Nakamura(YuNK) 氏)
およびその 68060 拡張版である HAS060.X (by M.Kamada 氏)
が処理可能な形式に変換するツールです。

本ツールを利用することで、gcc でクロスコンパイルしたコードを X68K のオブジェクトファイル形式に変換し、
従来の X68K 対応コンパイラ（SHARP XC および古い X68K 移植版 gcc）向けのソフトウェア資産とリンクし、
X68K の実行ファイルを生成することが可能になります。

X68K にはこれまでも複数の移植版 gcc が存在しましたが、最も新しいものでも ver 2.95.2 ベース（1997年）であり、それ以降の更新はありませんでした。
本ツールを利用することで、最新の gcc が利用可能になり、以下のようなメリットが得られます。
* 新しい言語仕様に準拠したコードが記述可能になる。
* より強化された最適化の恩恵が受けられる。


# 利用例

例として、example.c を X68K のオブジェクトファイルに変換し、実行ファイルを生成する手順を示します。

コンパイルは、POSIX 環境上（Linux / msys 等）で行います。
（クロスコンパイラである m68k-elf-gcc の生成手順は後述します。）
```bash
# example.c をコンパイルする。
# X68K と ABI を一致させるため d2 a2 を破壊可能レジスタとして指定している。
# X68K 専用の API を認識させるため、-I オプションでそれらを定義するヘッダのパスを指定している。
# この例では ./XC2102/INCLUDE に sharp XC コンパイラのヘッダが存在すると仮定している。
m68k-elf-gcc example.c -I./XC2102/INCLUDE -S -Os -m68000 -fcall-used-d2 -fcall-used-a2 -o example.m68k-gas.s

# HAS.X が処理可能なフォーマットに変換する。
# -cpu オプションで、対象とする CPU の種類が指定できる。
# -inc オプションで、ソース冒頭で include するファイルが指定できる。
perl x68k_gcc_has_converter.pl -i example.m68k-gas.s -o example.s -cpu 68000 -inc doscall.equ,iocscall.mac
```
カレントディレクトリに、HAS.X 形式の example.s が得られます。

続いて、example.s をアセンブルします。以降の手順は、X68K 上で実行します。
```bat
rem HAS.X を実行し、X68K のオブジェクトファイルに変換する。
rem -u : 未定義シンボルを外部参照にする 
rem -e : 外部参照オフセットをロングワードにする 
rem -w0 : 警告の抑制
HAS.X -e -u -w0 -o example.o example.s
```
カレントディレクトリに example.o が得られます。

これを実行ファイルに変換するには、m68k-elf-gcc 対応かつ X68K オブジェクトファイル形式の libgcc.a をリンクする必要があります。
（このような libgcc.a の生成手順は後述します。）
```bat
rem example.o は、既存の X68K のソフトウェア資産とリンク可能。
rem CLIB.L FLOATFNC.L は sharp XC コンパイラに含まれるライブラリである。
rem ここで選択した libgcc.a は、初代 MC68000 の命令セットで構成されている。
HLK.X -o example.x example.o CLIB.L FLOATFNC.L m68k_elf/m68000/libgcc.a
```

カレントディレクトリに example.x が得られます。


# HAS.X 形式変換例

HAS.X 形式に変換したアセンブラソースの例を示します。
変換後の各行には、m68k-elf-gcc が生成した gas 形式の元ソースがコメントで記載されています。

次に示すように、gas 形式（右）では movem 命令のレジスタマスクが #7952 のような数値になっていますが、
HAS.X 形式（左）では d3/d4/d5/d6/d7/a3 のような可読性のあるレジスタリスト表記になります。

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


また次に示すように、char 型配列は gas 形式（右）では可読性の悪いエスケープシーケンスと 8 進数エンコード混在表記となりますが、
HAS.X 形式（左）では素直な 16 進数二桁の配列表記となります。

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


# libgcc.a の種類と用途

libgcc.a は、用途に応じて複数の種類から選択して利用可能です。

* m68k_elf/m68000/libgcc.a  
	MC68000 の命令セットで構成されています。
	全世代の X680x0 で動作可能な実行ファイルを作成する場合にリンクします。
	FPU 非搭載 X68030 環境も、こちらをリンクしてください。

* m68k_elf/m68020/libgcc.a  
	MC68020 の命令セット + FPU の MC68881 命令セットで構成されています。
	FPU 搭載 X68030 で動作可能な実行ファイルを作成する場合にリンクします。
	FPU 非搭載 X68030 では動作しないのでご注意ください。
	また、MC68040 以降の内蔵 FPU には存在しない浮動小数演算命令（FMOVECR 等々）が生成されるので、
	040Turbo/060Turbo 等の環境で動作しない場合がある点もご注意ください。

* m68k_elf/m68040/libgcc.a  
	MC68040 の命令セットで構成されています。
	040Turbo 等のアクセラレータを搭載した X680x0 で動作可能な実行ファイルを作成する場合にリンクします。

* m68k_elf/m68040/libgcc.a  
	MC68060 の命令セットで構成されています。
	060Turbo 等のアクセラレータを搭載した X680x0 で動作可能な実行ファイルを作成する場合にリンクします。


# 互換性問題

従来の X68K 対応コンパイラと、m68k-elf-gcc の間には、互換性問題があります。

## 1. ABI が一致しない（回避策あり）  

* 破壊レジスタ  
	従来の X68K 対応コンパイラ : d0-d2/a0-a2/fp0-fp1  
	m68k-elf-gcc : d0-d2/a0-a2/fp0-fp1  
	この問題は、m68k-elf-gcc 側にコンパイルオプション -fcall-used-d2 -fcall-used-a2 を指定することで解消されます。

* 戻り値を格納するレジスタ  
	X68K の ABI は、MC680x0 の慣例に従い、関数の戻り値は d0 レジスタに格納するルールになっていました。
	一方、最新の gcc では、configure によっては戻り値を a0 レジスタにも格納します。
	これは、malloc() のようにポインタを返すことが明らかな関数の場合、
	アドレスレジスタに戻り値を返せばオーバーヘッドを回避できる、という考え方が根底にあります。
	しかし実際には、安全性と互換性のため a0 d0 双方に同一の値を返すという運用になっており、
	逆にオーバーヘッド発生源になっています。
	そして、結果を a0 レジスタから読むコードが生成されることにより、過去のソフトウェア資産が再利用できなくなっています。
	
	この問題を避けるには、
	関数の戻り値を d0 レジスタのみに格納する configure でビルドされた gcc を利用する必要があります。
	最も確実な方法は、後述する方法で m68k-elf-gcc を自力でビルドし利用することです。

	>:warning:
	>Linux のディストリビューターが提供している m68k-linux-gnu-gcc などのビルド済み gcc は、
	>戻り値を a0 d0 双方に同一の値を返す動作になっており、X68K の ABI と互換性がありません。

## 2. 一部の数値型のバイナリ表現が異なる（回避策は無いが影響を受ける可能性は低い）
従来の X68K 対応コンパイラと m68k-elf-gcc との間で、一部の数値型のバイナリ表現が異なります。

* long double 型（拡張倍精度浮動小数型）  
	従来の X68K 対応コンパイラ : long double ＝ 8 bytes 型（double 型互換）  
	m68k-elf-gcc : long double ＝ 12 bytes 型  

* long long 型（64bit 整数型）  
	従来の X68K 対応コンパイラ : 下位 32bit、上位 32bit の順に格納（つまりビッグエンディアン配置でない）  
	m68k-elf-gcc : 上位 32bit、下位 32bit の順に格納（厳密にビッグエンディアン配置）  

上記の型を扱うバイナリコードには互換性がなく、古いコードをリンクするには再ビルドが必要です。
もし、ソースコードが入手できず再ビルド不能なコードの場合は、厄介な問題となります。
古いバイナリ上の long double 型は、double 型として扱えば回避可能ですが、
long long 型の場合は根本的に異なるため回避困難です。
幸い、X68K 上のプログラミングでは long double 型や long long 型を利用することは少なく、
過去のソフトウェア資産上に出現することは極めて稀であるため、
問題となる状況はほとんど発生しないと考えられます。


# 推奨される利用スタイル

以上を踏まえて、
gcc の互換性問題を回避しつつ、
m68k-elf-gcc を活用したコードを記述する、現状の最善の方法をまとめます。

1. ビルド構成が不明な gcc を利用せず、自力ビルドした gcc を利用する
2. m68k-elf-gcc 側に -fcall-used-d2 -fcall-used-a2 を指定する
3. m68k-elf-gcc 対応かつ X68K オブジェクトファイル形式の libgcc.a を利用する
4. 過去のバイナリ資産を再利用する場合は、long long 型、long double 型 を含まないものに限る


# m68k-elf-gcc の作成手順

m68k-elf-gcc を作成するには、
200 GB 程度のディスク容量があることを確認した上で、
build_m68k-toolchain.sh
を実行します。
（POSIX 環境必須。Linux か msys を推奨。他環境は未テスト。）

全処理完了には、最大数時間程度の時間がかかります。
正常終了すると、カレントディレクトリに m68k-toolchain/ というディレクトリが生成されるので、お好みのパスに移動して利用してください。

ディレクトリ build_gcc/ は中間ファイルです。
後述の libgcc.a 作成を自力で行う場合に再利用されますが、
その必要がない場合は削除しても問題ありません。


# libgcc.a の作成手順

m68k-elf-gcc 対応かつ X68K オブジェクトファイル形式の libgcc.a を作成するには、
先述の build_m68k-toolchain.sh が実行完了し、
bulid_gcc/ 以下に中間ファイルが存在する状態で、
以下の手順を実行します。

1. 旧 libgcc.a の入手  
X68K 移植版 GCC 2.95.2 (by KQ 氏) の G295b04D.ZIP を入手し、
アーカイブに含まれている旧 libgcc.a を取り出します。

2. build_x68k-libgcc.sh の実行  
build_x68k-libgcc.sh の置かれているディレクトリ上に 旧 libgcc.a をコピーし、
build_x68k-libgcc.sh -old-libgcc ./libgcc.a
を実行します。
（一部の関数は旧 libgcc.a から流用し、それら以外は新しい libgcc のソースから再コンパイルして生成されます。）

3. X68K 上でアセンブル＆リンク  
ディレクトリ build_libgcc/ を X68K 上にコピーし、
X68K 上で build_libgcc/src/m68k_elf を実行します。

4. 必要なファイルのインストール  
build_libgcc/lib/m68k_elf 以下に、ビルド結果が生成されます。お好みのパスに移動して利用してください。

ディレクトリ build_libgcc/ は中間ファイルです。
ここまでの手順が完了したら削除しても問題ありません。


# その他の制限事項

現状多くの制限があります。

* GAS 形式アセンブラコードは gcc が出力する形式のみに対応  
	本コンバート・ツールが認識できるのは、GAS 形式アセンブラコードの記述方法のうち、gcc が出力する可能性のあるもののみです。

* inline asm 内に記述可能なアセンブラコードの制限  
	マクロ制御命令（HAS の macro local endm exitm rept irp irpc など）は利用できません。
	特殊記号（HAS の '&' '!' , '<'～'>' , '%' など）が出現するとパースエラーになります。


# 絶賛テスト中

現在、様々な条件での動作テストを行っています。
修正が頻繁に行われています。
当面の間、修正に伴い予告なく互換ブレイクが発生することも予想されますがご了承ください。

環境構築時のエラーや、
アセンブラソース変換中のエラーなど、
何かしらの問題に遭遇した場合は、
エラーを起こした該当行の情報等を添えてご報告いただけるとありがたいです。


# ライセンス

build_m68k-toolchain.sh
build_x68k-libgcc.sh
x68k_gcc_has_converter.pl
には、Apache License Version 2.0 が適用されます。


