#!/usr/bin/bash
#------------------------------------------------------------------------------
#
#	build_x68k-libgcc.sh
#
#	JP:
#		m68k-toolchain を利用して X68K 用の libgcc.a を作成する。
#		build_m68k-toolchain.sh を実行した後に本スクリプトを実行する。
#		X68K 上でのビルドステップで利用されるツールと入手元は以下のとおり。
#		HAS060.X (Y.Nakamura M.Kamada)
#			http://retropc.net/x68000/software/develop/as/has060/
#		AR.X (C Compiler PRO-68K ver2.1)
#			http://retropc.net/x68000/software/sharp/xc21/
#			XC2101.LZH に含まれる。
#
#	EN:
#		Create libgcc.a for X68K with m68k-toolchain.
#		Run this script After build_m68k-toolchain.sh has finished.
#		The tools used in the build step on the X68K are listed below.
#		HAS060.X (Y.Nakamura M.Kamada)
#			http://retropc.net/x68000/software/develop/as/has060/
#		AR.X (C Compiler PRO-68K ver2.1)
#			http://retropc.net/x68000/software/sharp/xc21/
#			AR.X is archived in XC2101.LZH.
#
#------------------------------------------------------------------------------
#
#	Copyright (C) 2022 Yosshin(@yosshin4004)
#
#	Licensed under the Apache License, Version 2.0 (the "License");
#	you may not use this file except in compliance with the License.
#	You may obtain a copy of the License at
#
#	    http://www.apache.org/licenses/LICENSE-2.0
#
#	Unless required by applicable law or agreed to in writing, software
#	distributed under the License is distributed on an "AS IS" BASIS,
#	WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#	See the License for the specific language governing permissions and
#	limitations under the License.
#
#------------------------------------------------------------------------------


#-----------------------------------------------------------------------------
# 設定
#
#	build_m68k-toolchain.sh 側の設定と整合性が取れていること。
#-----------------------------------------------------------------------------

# gcc の ABI
GCC_ABI="m68k-elf"

# gcc のバージョン
GCC_VERSION="10.2.0"

# gcc ビルド用ワークディレクトリ
GCC_BUILD_DIR="build_gcc"

# libgcc ビルド用ワークディレクトリ
LIBGCC_BUILD_DIR="build_libgcc"

# m68k ツールチェインのディレクトリ
M68K_TOOLCHAIN="m68k-toolchain"

# m68k gas -> X68K has 変換
GAS_TO_HAS="perl ./x68k_gcc_has_converter.pl"


#-----------------------------------------------------------------------------
# 引数の確認
#-----------------------------------------------------------------------------

# 引数無しだとヘルプメッセージを出して終了
if [ $# -eq 0 ];
then
	echo "build_x68k-libgcc.sh"
	echo ""
	echo "[usage]"
	echo "	build_x68k-libgcc.sh [options]"
	echo ""
	echo "	options:"
	echo "		-m68000"
	echo "			generate libgcc.a for m68000."
	echo ""
	echo "		-m68020"
	echo "			generate libgcc.a for m68020."
	echo ""
	echo "		-m68040"
	echo "			generate libgcc.a for m68040."
	echo ""
	echo "		-m68060"
	echo "			generate libgcc.a for m68060."
	echo ""
	echo "		--reuse-old-libgcc <filename>"
	echo "			Extract lb1sf68 objs from the specified libgcc.a file,"
	echo "			instead of assembling them from lb1sf68.S."
	echo ""
	exit 1
fi

# 引数解析
#	OPTIONS[オプション]=引数
OPTION="-"
declare -A OPTIONS
while [ $# -gt 0 ]
do
	case $1 in
		-m68000)
			OPTION=$1;
			OPTIONS[$OPTION]="1"
			;;
		-m68020)
			OPTION=$1;
			OPTIONS[$OPTION]="1"
			;;
		-m68040)
			OPTION=$1;
			OPTIONS[$OPTION]="1"
			;;
		-m68060)
			OPTION=$1;
			OPTIONS[$OPTION]="1"
			;;
		--reuse-old-libgcc)
			OPTION=$1;
			OPTIONS[$OPTION]=""
			;;
		-*)
			echo "ERROR: invalid option."
			exit 1
			;;
		*)
			if [ $OPTION = "-" ]; then
				echo "ERROR: invalid option."
				exit 1
			fi
			OPTIONS[$OPTION]=$1
			;;
	esac
	shift
done

# オプション指定一覧
#for OPTION in ${!OPTIONS[@]}
#do
#	echo "	${OPTION}=${OPTIONS[${OPTION}]}"
#done

# 旧 libgcc.a ファイルの再利用指定
OLD_LIBGCC_FILE_NAME=${OPTIONS["--reuse-old-libgcc"]}


#-----------------------------------------------------------------------------
# 準備
#-----------------------------------------------------------------------------

# エラーが起きたらそこで終了させる。
# 未定義変数を参照したらエラーにする。
set -eu

# ターゲットとする CPU の型番
TARGETS=()
if [ -n "${OPTIONS["-m68000"]-}" ]; then
	TARGETS+=(68000)
fi
if [ -n "${OPTIONS["-m68020"]-}" ]; then
	TARGETS+=(68020)
fi
if [ -n "${OPTIONS["-m68040"]-}" ]; then
	TARGETS+=(68040)
fi
if [ -n "${OPTIONS["-m68060"]-}" ]; then
	TARGETS+=(68060)
fi

# ターゲット一覧の確認
#for TARGET in ${TARGETS[@]}
#do
#	echo "	TARGET $TARGET"
#done


# gcc の ABI 名（X68K のパス名として使える文字列で表現）
GCC_ABI_IN_X68K=`echo $GCC_ABI | sed -e "s/-/_/g"`

# ターゲットごとの分類用ディレクトリ名
TARGET_DIRS=(
	[68000]=m68000
	[68020]=m68020
	[68040]=m68040
	[68060]=m68060
)

# libgcc のビルド時に利用する include パス
INCLUDE_PATHS=(
	[68000]=${GCC_BUILD_DIR}/build/gcc-${GCC_VERSION}_stage2/${GCC_ABI}/libgcc
	[68020]=${GCC_BUILD_DIR}/build/gcc-${GCC_VERSION}_stage2/${GCC_ABI}/m68020/libgcc
	[68040]=${GCC_BUILD_DIR}/build/gcc-${GCC_VERSION}_stage2/${GCC_ABI}/m68040/libgcc
	[68060]=${GCC_BUILD_DIR}/build/gcc-${GCC_VERSION}_stage2/${GCC_ABI}/m68060/libgcc
)


# libgcc ビルド用ワークディレクトリと同名のディレクトリが存在するなら削除を促す
#（万が一ユーザーのファイルを削除しないため）
if [ -d ${LIBGCC_BUILD_DIR} ];
then
	echo "ERROR: directory '${LIBGCC_BUILD_DIR}' already exists. please remove it."
	exit 1
fi

# gcc ビルド用ワークディレクトリが存在しないならエラー
if [ ! -e ${GCC_BUILD_DIR} ];
then
	echo "ERROR: directory '${GCC_BUILD_DIR}' is not found. please run build_x68k-libgcc.sh."
	exit 0
fi

# libgcc ビルド用ワークディレクトリを作成
mkdir ${LIBGCC_BUILD_DIR}
mkdir ${LIBGCC_BUILD_DIR}/src
mkdir ${LIBGCC_BUILD_DIR}/lib

# 旧 libgcc.a ファイルの再利用が指定されている場合
if [ -n "${OPTIONS["--reuse-old-libgcc"]-}" ]; then
	# 旧 libgcc.a ファイルが存在するなら
	if [ -e ${OLD_LIBGCC_FILE_NAME} ]; then
		# 旧 libgcc.a をワークディレクトリの src 以下にコピー
		cp ${OLD_LIBGCC_FILE_NAME} ${LIBGCC_BUILD_DIR}/src/libgcc.a
	else
		# エラー
		echo "ERROR: '${OLD_LIBGCC_FILE_NAME}' is not found."
		exit 0
	fi
fi


#-----------------------------------------------------------------------------
# 全てのターゲット環境に対して
#-----------------------------------------------------------------------------
for TARGET in ${TARGETS[@]}
do
	echo "generating asm sources for ${TARGET}."
	TARGET_DIR=${TARGET_DIRS[$TARGET]}

	# ターゲットのソースディレクトリ名
	LIBGCC_TARGET_SRC_DIR=${LIBGCC_BUILD_DIR}/src/${GCC_ABI_IN_X68K}/${TARGET_DIR}

	# ターゲットのライブラリディレクトリ名
	LIBGCC_TARGET_LIB_DIR=${LIBGCC_BUILD_DIR}/lib/${GCC_ABI_IN_X68K}/${TARGET_DIR}

	# ディレクトリ生成
	mkdir -p ${LIBGCC_TARGET_SRC_DIR}
	mkdir -p ${LIBGCC_TARGET_LIB_DIR}
	mkdir -p ${LIBGCC_TARGET_SRC_DIR}/dep


	#-----------------------------------------------------------------------------
	# lb1sf68.S から HAS 形式のソースファイル群を生成する
	#-----------------------------------------------------------------------------

	# lb1sf68.S から生成するオブジェクトファイル名
	#	[オブジェクトファイル名]=ソースファイル名
	#	X68K のファイル名規則に違反する場合はここでリネームする。
	declare -A SRC_FILES_EMIT_FROM_LB1SF68
	# 旧 libgcc.a ファイルの再利用が指定されていない場合のみ有効
	if [ ! -n "${OPTIONS["--reuse-old-libgcc"]-}" ]; then
		SRC_FILES_EMIT_FROM_LB1SF68=(
			[_mulsi3]=_mulsi3
			[_udivsi3]=_udivsi3
			[_divsi3]=_divsi3
			[_umodsi3]=_umodsi3
			[_modsi3]=_modsi3
			[_double]=_double
			[_float]=_float
			[_floatex]=_floatex
			[_eqdf2]=_eqdf2
			[_nedf2]=_nedf2
			[_gtdf2]=_gtdf2
			[_gedf2]=_gedf2
			[_ltdf2]=_ltdf2
			[_ledf2]=_ledf2
			[_eqsf2]=_eqsf2
			[_nesf2]=_nesf2
			[_gtsf2]=_gtsf2
			[_gesf2]=_gesf2
			[_ltsf2]=_ltsf2
			[_lesf2]=_lesf2
		)
	fi

	# lb1sf68.S をプリプロセスして得られたソースファイルを HAS 形式に変換
	for OBJ in ${!SRC_FILES_EMIT_FROM_LB1SF68[@]}
	do
		SRC=${SRC_FILES_EMIT_FROM_LB1SF68[$OBJ]}
		echo "	generating ${OBJ}.s from lb1sf68.S."
		${M68K_TOOLCHAIN}/bin/${GCC_ABI}-cpp -E -DL${OBJ} -o ${LIBGCC_TARGET_SRC_DIR}/${OBJ}_.s ${GCC_BUILD_DIR}/src/gcc-${GCC_VERSION}/libgcc/config/m68k/lb1sf68.S
		${GAS_TO_HAS} -i ${LIBGCC_TARGET_SRC_DIR}/${OBJ}_.s -o ${LIBGCC_TARGET_SRC_DIR}/${OBJ}.s -cpu ${TARGET}
		rm ${LIBGCC_TARGET_SRC_DIR}/${OBJ}_.s
	done

	# 依存ファイルを収集
	cp ${GCC_BUILD_DIR}/src/gcc-${GCC_VERSION}/libgcc/config/m68k/lb1sf68.S ${LIBGCC_TARGET_SRC_DIR}/dep


	#-----------------------------------------------------------------------------
	# libgcc2.c からソースファイル群を生成
	#-----------------------------------------------------------------------------

	# コンパイルオプション
	CFLAGS="\
		-isystem ${M68K_TOOLCHAIN}/${GCC_ABI}/include\
		-isystem ${M68K_TOOLCHAIN}/${GCC_ABI}/sys-include\
		-O2 -DIN_GCC -DCROSS_DIRECTORY_STRUCTURE\
		-W -Wall -Wwrite-strings -Wcast-qual -Wstrict-prototypes -Wold-style-definition\
		-Wno-narrowing -Wno-missing-prototypes -Wno-implicit-function-declaration\
		-DIN_LIBGCC2 -fbuilding-libgcc -fno-stack-protector\
		-Dinhibit_libc\
		-isystem ${GCC_BUILD_DIR}/src/gcc-${GCC_VERSION}/include\
		-isystem ${GCC_BUILD_DIR}/build/gcc-${GCC_VERSION}_stage2/gcc\
		-I${INCLUDE_PATHS[$TARGET]}\
		-I${GCC_BUILD_DIR}/src/gcc-${GCC_VERSION}/libgcc\
		-I${GCC_BUILD_DIR}/src/gcc-${GCC_VERSION}/libgcc/.\
		-I${GCC_BUILD_DIR}/src/gcc-${GCC_VERSION}/libgcc/../gcc\
		-I${GCC_BUILD_DIR}/src/gcc-${GCC_VERSION}/libgcc/../include\
		-DHAVE_CC_TLS\
		-fvisibility=hidden\
		-DHIDE_EXPORTS\
		-m${TARGET}\
		 -fcall-used-d2 -fcall-used-a2\
    "

	# libgcc2.c から生成するオブジェクトファイル名
	#	[オブジェクトファイル名]=ソースファイル名
	#	X68K のファイル名規則に違反する場合はここでリネームする。
	declare -A SRC_FILES_EMIT_FROM_LIBGCC2
	SRC_FILES_EMIT_FROM_LIBGCC2=(
		[_muldi3]=_muldi3
		[_negdi2]=_negdi2
		[_lshrdi3]=_lshrdi3
		[_ashldi3]=_ashldi3
		[_ashrdi3]=_ashrdi3
		[_cmpdi2]=_cmpdi2
		[_ucmpdi2]=_ucmpdi2
		[_clear_cache]=_clear_cache
		[_trampoline]=_trampoline
		[__main]=__main
		[_absvsi2]=_absvsi2
		[_absvdi2]=_absvdi2
		[_addvsi3]=_addvsi3
		[_addvdi3]=_addvdi3
		[_subvsi3]=_subvsi3
		[_subvdi3]=_subvdi3
		[_mulvsi3]=_mulvsi3
		[_mulvdi3]=_mulvdi3
		[_negvsi2]=_negvsi2
		[_negvdi2]=_negvdi2
		[_ctors]=_ctors
		[_ffssi2]=_ffssi2
		[_ffsdi2]=_ffsdi2
		[_clz]=_clz
		[_clzsi2]=_clzsi2
		[_clzdi2]=_clzdi2
		[_ctzsi2]=_ctzsi2
		[_ctzdi2]=_ctzdi2
		[_popcount_tab]=_popcount_tab
		[_popcountsi2]=_popcountsi2
		[_popcountdi2]=_popcountdi2
		[_paritysi2]=_paritysi2
		[_paritydi2]=_paritydi2
		[_powisf2]=_powisf2
		[_powidf2]=_powidf2
		[_powixf2]=_powixf2
		[_powitf2]=_powitf2
		[_mulhc3]=_mulhc3
		[_mulsc3]=_mulsc3
		[_muldc3]=_muldc3
		[_mulxc3]=_mulxc3
		[_multc3]=_multc3
		[_divhc3]=_divhc3
		[_divsc3]=_divsc3
		[_divdc3]=_divdc3
		[_divxc3]=_divxc3
		[_divtc3]=_divtc3
		[_bswapsi2]=_bswapsi2
		[_bswapdi2]=_bswapdi2
		[_clrsbsi2]=_clrsbsi2
		[_clrsbdi2]=_clrsbdi2
		[_fixunssfsi]=_fixunssfsi
		[_fixunsdfsi]=_fixunsdfsi
		[_fixunsxfsi]=_fixunsxfsi
		[_fixsfdi]=_fixsfdi
		[_fixdfdi]=_fixdfdi
		[_fixxfdi]=_fixxfdi
		[_fixtfdi]=_fixtfdi
		[_fixunssfdi]=_fixunssfdi
		[_fixunsdfdi]=_fixunsdfdi
		[_fixunsxfdi]=_fixunsxfdi
		[_fixunstfdi]=_fixunstfdi
		[_floatdisf]=_floatdisf
		[_floatdidf]=_floatdidf
		[_floatdixf]=_floatdixf
		[_floatditf]=_floatditf
		[_floatundisf]=_floatundisf
		[_floatundidf]=_floatundidf
		[_floatundixf]=_floatundixf
		[_floatunditf]=_floatunditf
		[_eprintf]=_eprintf
		[__gcc_bcmp]=__gcc_bcmp
		[_divdi3]=_divdi3
		[_moddi3]=_moddi3
		[_divmoddi4]=_divmoddi4
		[_udivdi3]=_udivdi3
		[_umoddi3]=_umoddi3
		[_udivmoddi4]=_udivmoddi4
		[_udiv_w_sdiv]=_udiv_w_sdiv
	)

	# libgcc2.c からソースファイルを生成する
	for OBJ in ${!SRC_FILES_EMIT_FROM_LIBGCC2[@]}
	do
		SRC=${SRC_FILES_EMIT_FROM_LIBGCC2[$OBJ]}
		echo "	generating ${OBJ}.s from libgcc2.c."
		${M68K_TOOLCHAIN}/bin/${GCC_ABI}-gcc ${CFLAGS} -S -o ${LIBGCC_TARGET_SRC_DIR}/${OBJ}_.s -DL${SRC} -c ${GCC_BUILD_DIR}/src/gcc-${GCC_VERSION}/libgcc/libgcc2.c
		${GAS_TO_HAS} -i ${LIBGCC_TARGET_SRC_DIR}/${OBJ}_.s -o ${LIBGCC_TARGET_SRC_DIR}/${OBJ}.s -cpu ${TARGET} -inline-asm-syntax gas
		rm ${LIBGCC_TARGET_SRC_DIR}/${OBJ}_.s

		# 依存ファイルを収集
		${M68K_TOOLCHAIN}/bin/${GCC_ABI}-gcc ${CFLAGS} -c -M ${GCC_BUILD_DIR}/src/gcc-${GCC_VERSION}/libgcc/libgcc2.c -MF ${LIBGCC_TARGET_SRC_DIR}/${OBJ}.d
		DEP_FILES=(`cat ${LIBGCC_TARGET_SRC_DIR}/${OBJ}.d`)
		for DEP_FILE in ${DEP_FILES[@]}
		do
			if [ -e ${DEP_FILE} ]; then
				cp ${DEP_FILE} ${LIBGCC_TARGET_SRC_DIR}/dep
			fi
		done
		rm ${LIBGCC_TARGET_SRC_DIR}/${OBJ}.d
	done


	#-----------------------------------------------------------------------------
	# その他のソースファイル群を生成
	#-----------------------------------------------------------------------------

	# _xfgnulib.c を生成する
	echo '#define EXTFLOAT' > ${LIBGCC_TARGET_SRC_DIR}/_xfgnulib.c
	cat ${GCC_BUILD_DIR}/src/gcc-${GCC_VERSION}/libgcc/config/m68k/fpgnulib.c >> ${LIBGCC_TARGET_SRC_DIR}/_xfgnulib.c

	# libgcc2.c 以外のファイルから生成するオブジェクトファイル名
	#	[オブジェクトファイル名]=ソースファイル名
	#	X68K のファイル名規則に違反する場合はここでリネームする。
	#	明らかに不要なもの（デバッグ情報に関連する unwind～）はコメントアウトした。
	declare -A SRC_FILES_EMIT_NOT_FROM_LIBGCC2
	SRC_FILES_EMIT_NOT_FROM_LIBGCC2=(
		[_xfgnulib]=${LIBGCC_TARGET_SRC_DIR}/_xfgnulib
		[_fpgnulib]=${GCC_BUILD_DIR}/src/gcc-${GCC_VERSION}/libgcc/config/m68k/fpgnulib
		[_en_exe_stack]=${GCC_BUILD_DIR}/src/gcc-${GCC_VERSION}/libgcc/enable-execute-stack-empty
#		[_unwind_dw2]=${GCC_BUILD_DIR}/src/gcc-${GCC_VERSION}/libgcc/unwind-dw2
#		[_unwind_dw2_fde]=${GCC_BUILD_DIR}/src/gcc-${GCC_VERSION}/libgcc/unwind-dw2-fde
#		[_unwind_sjlj]=${GCC_BUILD_DIR}/src/gcc-${GCC_VERSION}/libgcc/unwind-sjlj
#		[_unwind_c]=${GCC_BUILD_DIR}/src/gcc-${GCC_VERSION}/libgcc/unwind-c
		[_emutls]=${GCC_BUILD_DIR}/src/gcc-${GCC_VERSION}/libgcc/emutls
	)

	# libgcc2.c 以外のファイルに由来するソースファイルを生成する
	for OBJ in ${!SRC_FILES_EMIT_NOT_FROM_LIBGCC2[@]}
	do
		SRC=${SRC_FILES_EMIT_NOT_FROM_LIBGCC2[$OBJ]}
		echo "	generating ${OBJ}.s from ${SRC}.c."
		${M68K_TOOLCHAIN}/bin/${GCC_ABI}-gcc ${CFLAGS} -S -o ${LIBGCC_TARGET_SRC_DIR}/${OBJ}_.s -c ${SRC}.c
		${GAS_TO_HAS} -i ${LIBGCC_TARGET_SRC_DIR}/${OBJ}_.s -o ${LIBGCC_TARGET_SRC_DIR}/${OBJ}.s -cpu ${TARGET} -inline-asm-syntax gas
		rm ${LIBGCC_TARGET_SRC_DIR}/${OBJ}_.s

		# 依存ファイルを収集
		${M68K_TOOLCHAIN}/bin/${GCC_ABI}-gcc ${CFLAGS} -c -M ${SRC}.c -MF ${LIBGCC_TARGET_SRC_DIR}/${OBJ}.d
		DEP_FILES=(`cat ${LIBGCC_TARGET_SRC_DIR}/${OBJ}.d`)
		for DEP_FILE in ${DEP_FILES[@]}
		do
			if [ -e ${DEP_FILE} ]; then
				cp ${DEP_FILE} ${LIBGCC_TARGET_SRC_DIR}/dep
			fi
		done
		rm ${LIBGCC_TARGET_SRC_DIR}/${OBJ}.d
	done

	# _xfgnulib.c を除去する
	rm ${LIBGCC_TARGET_SRC_DIR}/_xfgnulib.c


	#-----------------------------------------------------------------------------
	# X68K 上で実行する変換バッチを生成
	#-----------------------------------------------------------------------------
	BAT_FILE=${LIBGCC_TARGET_SRC_DIR}/build.bat
	rm -f ${BAT_FILE}
	printf "echo off\r\n" >> ${BAT_FILE}

	# 旧 libgcc.a ファイル（X68K 上でのパス）
	OLD_LIBGCC_FILE_NAME_FOR_X68K=..\\\\..\\\\libgcc.a

	# 旧 libgcc.a ファイルの再利用が指定されている場合
	if [ -n "${OPTIONS["--reuse-old-libgcc"]-}" ]; then
		# 旧 libgcc.a ファイルが存在することを確認
		printf "\r\n" >> ${BAT_FILE}
		printf "if NOT EXIST ${OLD_LIBGCC_FILE_NAME_FOR_X68K} goto ERROR_NO_OLD_LIBGCC_A\r\n" >> ${BAT_FILE}
		printf "\r\n" >> ${BAT_FILE}
	fi

	# lb1sf68.S から生成されたソースファイルのアセンブル
	for OBJ in ${!SRC_FILES_EMIT_FROM_LB1SF68[@]}
	do
		printf "has060.x -e -u -w0 -m ${TARGET} ${OBJ}.s\r\n" >> ${BAT_FILE}
		printf "if EXITCODE 1 goto ERROR_HAS060_FAILED\r\n" >> ${BAT_FILE}
	done

	# libgcc2.c から生成されたソースファイルのアセンブル
	for OBJ in ${!SRC_FILES_EMIT_FROM_LIBGCC2[@]}
	do
		printf "has060.x -e -u -w0 -m ${TARGET} ${OBJ}.s\r\n" >> ${BAT_FILE}
		printf "if EXITCODE 1 goto ERROR_HAS060_FAILED\r\n" >> ${BAT_FILE}
	done

	# libgcc2.c 以外から生成されたソースファイルのアセンブル
	for OBJ in ${!SRC_FILES_EMIT_NOT_FROM_LIBGCC2[@]}
	do
		printf "has060.x -e -u -w0 -m ${TARGET} ${OBJ}.s\r\n" >> ${BAT_FILE}
		printf "if EXITCODE 1 goto ERROR_HAS060_FAILED\r\n" >> ${BAT_FILE}
	done

	# 旧 libgcc.a から再利用可能なオブジェクトファイル名
	#	[コピー先オブジェクトファイル名]=コピー元オブジェクトファイル名
	declare -A OBJ_FILES_COPY_FROM_X68K_LIBGCC
	# 旧 libgcc.a ファイルの再利用が指定されている場合のみ有効
	if [ -n "${OPTIONS["--reuse-old-libgcc"]-}" ]; then
		OBJ_FILES_COPY_FROM_X68K_LIBGCC=(
			[_adddf3]=_adddf3
			[_divsf3]=_divsf3
			[_gesf2]=_gesf2
			[_ltdf2]=_ltdf2
			[_mulsi3]=_mulsi3
			[_subdf3]=_subdf3
			[_addsf3]=_addsf3
			[_divsi3]=_divsi3
			[_gtdf2]=_gtdf2
			[_ltsf2]=_ltsf2
			[_nedf2]=_nedf2
			[_subsf3]=_subsf3
			[_cmpdf2]=_cmpdf2
			[_eqdf2]=_eqdf2
			[_gtsf2]=_gtsf2
			[_modsi3]=_modsi3
			[_negdf2]=_negdf2
			[_udivsi3]=_udivsi3
			[_cmpsf2]=_cmpsf2
			[_eqsf2]=_eqsf2
			[_ledf2]=_ledf2
			[_muldf3]=_muldf3
			[_negsf2]=_negsf2
			[_umodsi3]=_umodsi3
			[_divdf3]=_divdf3
			[_gedf2]=_gedf2
			[_lesf2]=_lesf2
			[_mulsf3]=_mulsf3
			[_nesf2]=_nesf2
		)
	fi

	# アーカイブにファイルを追記するのに先だって古いアーカイブを削除
	printf "if EXIST libgcc.a del libgcc.a\r\n" >> ${BAT_FILE}

	# 旧 libgcc.a からオブジェクトファイルを取り出し
	for SRC in ${!OBJ_FILES_COPY_FROM_X68K_LIBGCC[@]}
	do
		DST=${OBJ_FILES_COPY_FROM_X68K_LIBGCC[$SRC]}
		printf "ar.x /x ${OLD_LIBGCC_FILE_NAME_FOR_X68K} ${DST}.o\r\n" >> ${BAT_FILE}
		# ar.x は存在しないファイルの抽出を指定してもエラーにならないので自力チェックが必要。
		printf "if NOT EXIST ${DST}.o echo Can not extract ${DST}.o. || goto ERROR_AR_FAILED\r\n" >> ${BAT_FILE}
		printf "if EXITCODE 1 goto ERROR_AR_FAILED\r\n" >> ${BAT_FILE}
	done

	# lb1sf68.S から生成されたオブジェクトファイルをアーカイブ
	for OBJ in ${!SRC_FILES_EMIT_FROM_LB1SF68[@]}
	do
		printf "ar.x /u libgcc.a ${OBJ}.o\r\n" >> ${BAT_FILE}
		printf "if EXITCODE 1 goto ERROR_AR_FAILED\r\n" >> ${BAT_FILE}
	done

	# libgcc2.c から生成されたオブジェクトファイルをアーカイブ
	for OBJ in ${!SRC_FILES_EMIT_FROM_LIBGCC2[@]}
	do
		printf "ar.x /u libgcc.a ${OBJ}.o\r\n" >> ${BAT_FILE}
		printf "if EXITCODE 1 goto ERROR_AR_FAILED\r\n" >> ${BAT_FILE}
	done

	# libgcc2.c 以外から生成されたオブジェクトファイルをアーカイブ
	for OBJ in ${!SRC_FILES_EMIT_NOT_FROM_LIBGCC2[@]}
	do
		printf "ar.x /u libgcc.a ${OBJ}.o\r\n" >> ${BAT_FILE}
		printf "if EXITCODE 1 goto ERROR_AR_FAILED\r\n" >> ${BAT_FILE}
	done

	# 旧 libgcc.a から取り出したオブジェクトファイルをアーカイブ
	for DST in ${!OBJ_FILES_COPY_FROM_X68K_LIBGCC[@]}
	do
		printf "ar.x /u libgcc.a ${DST}.o\r\n" >> ${BAT_FILE}
		printf "if EXITCODE 1 goto ERROR_AR_FAILED\r\n" >> ${BAT_FILE}
	done

	# 正常終了
	printf "\r\n" >> ${BAT_FILE}
	printf "echo Successfully generated libgcc.a.\r\n" >> ${BAT_FILE}
	printf "\r\n" >> ${BAT_FILE}
	printf "goto END\r\n" >> ${BAT_FILE}
	printf "\r\n" >> ${BAT_FILE}

	# エラー処理部
	printf ":ERROR\r\n" >> ${BAT_FILE}
	printf "echo !!!ERROR!!!\r\n" >> ${BAT_FILE}
	printf "pause\r\n" >> ${BAT_FILE}
	printf "goto END\r\n" >> ${BAT_FILE}
	printf "\r\n" >> ${BAT_FILE}
	if [ -n "${OPTIONS["--reuse-old-libgcc"]-}" ]; then
		printf ":ERROR_NO_OLD_LIBGCC_A\r\n" >> ${BAT_FILE}
		printf "echo !!!ERROR!!!\r\n" >> ${BAT_FILE}
		printf "echo ${OLD_LIBGCC_FILE_NAME_FOR_X68K} is not found.\r\n" >> ${BAT_FILE}
		printf "echo Please copy old libgcc.a (extracted from G295b04D.ZIP) to ${OLD_LIBGCC_FILE_NAME_FOR_X68K}\r\n" >> ${BAT_FILE}
		printf "pause\r\n" >> ${BAT_FILE}
		printf "\r\n" >> ${BAT_FILE}
	fi
	printf ":ERROR_HAS060_FAILED\r\n" >> ${BAT_FILE}
	printf "echo !!!ERROR!!!\r\n" >> ${BAT_FILE}
	printf "echo HAS060.X failed.\r\n" >> ${BAT_FILE}
	printf "pause\r\n" >> ${BAT_FILE}
	printf "\r\n" >> ${BAT_FILE}
	printf ":ERROR_AR_FAILED\r\n" >> ${BAT_FILE}
	printf "echo !!!ERROR!!!\r\n" >> ${BAT_FILE}
	printf "echo AR.X failed.\r\n" >> ${BAT_FILE}
	printf "pause\r\n" >> ${BAT_FILE}
	printf "\r\n" >> ${BAT_FILE}

	# バッチ処理の終了
	printf ":END\r\n" >> ${BAT_FILE}
done


#-----------------------------------------------------------------------------
# X68K 上で全環境のビルドとデプロイを一括実行するバッチを生成
#-----------------------------------------------------------------------------
BAT_FILE=${LIBGCC_BUILD_DIR}/all.bat
rm -f ${BAT_FILE}

echo "generating ${BAT_FILE}"
printf "echo off\r\n" >> ${BAT_FILE}
printf "\r\n" >> ${BAT_FILE}

for TARGET in ${TARGETS[@]}
do
	TARGET_DIR=${GCC_ABI_IN_X68K}\\\\${TARGET_DIRS[$TARGET]}

	printf "echo run build.bat for $TARGET.\r\n" >> ${BAT_FILE}
	printf "if NOT EXIST src\\\\${TARGET_DIR}\\\\build.bat goto ERROR_NO_BUILD_BAT\r\n" >> ${BAT_FILE}
	printf "cd src\\\\${TARGET_DIR}\r\n" >> ${BAT_FILE}
	printf "command.x build.bat\r\n" >> ${BAT_FILE}
	printf "cd ..\\\\..\\\\..\\\\\r\n" >> ${BAT_FILE}
	printf "if NOT EXIST src\\\\${TARGET_DIR}\\\\libgcc.a goto ERROR_NO_LIBGCC_A\r\n" >> ${BAT_FILE}
	printf "copy src\\\\${TARGET_DIR}\\\\libgcc.a lib\\\\${TARGET_DIR}\\\\ \r\n" >> ${BAT_FILE}
	printf "\r\n" >> ${BAT_FILE}
done

printf "echo ----------------------------------------------------------------------------------------\r\n" >> ${BAT_FILE}
printf "echo Please copy lib/${GCC_ABI_IN_X68K}/ under the directory specified by the LIB environment variable.\r\n" >> ${BAT_FILE}
printf "echo ----------------------------------------------------------------------------------------\r\n" >> ${BAT_FILE}
printf "\r\n" >> ${BAT_FILE}

printf "goto END\r\n" >> ${BAT_FILE}
printf "\r\n" >> ${BAT_FILE}

printf ":ERROR\r\n" >> ${BAT_FILE}
printf "echo !!!ERROR!!!\r\n" >> ${BAT_FILE}
printf "pause\r\n" >> ${BAT_FILE}
printf "goto END\r\n" >> ${BAT_FILE}
printf "\r\n" >> ${BAT_FILE}

printf ":ERROR_NO_BUILD_BAT\r\n" >> ${BAT_FILE}
printf "echo !!!ERROR!!!\r\n" >> ${BAT_FILE}
printf "echo Make sure that the current directory path is correct.\r\n" >> ${BAT_FILE}
printf "pause\r\n" >> ${BAT_FILE}
printf "goto END\r\n" >> ${BAT_FILE}
printf "\r\n" >> ${BAT_FILE}

printf ":ERROR_NO_LIBGCC_A\r\n" >> ${BAT_FILE}
printf "echo !!!ERROR!!!\r\n" >> ${BAT_FILE}
printf "echo failed to build for $TARGET.\r\n" >> ${BAT_FILE}
printf "pause\r\n" >> ${BAT_FILE}
printf "goto END\r\n" >> ${BAT_FILE}
printf "\r\n" >> ${BAT_FILE}

printf ":END\r\n" >> ${BAT_FILE}


#-----------------------------------------------------------------------------
# ソースコードパッケージの作成
#-----------------------------------------------------------------------------
ROOT_DIR="${PWD}"
cd ${LIBGCC_BUILD_DIR}
tar -zcvf src.tar.gz src/ all.bat
cd ${ROOT_DIR}


#-----------------------------------------------------------------------------
# 次の操作を促す
#-----------------------------------------------------------------------------
echo "done."
echo ""
echo "-----------------------------------------------------------------------------"
echo "To generate libgcc.a files, please perform the following steps:"
echo "    1) Copy ${LIBGCC_BUILD_DIR}/ to X68K."
echo "    2) Move current directory to ${LIBGCC_BUILD_DIR}/ and run all.bat on X68K."
echo "-----------------------------------------------------------------------------"
echo ""


