#!/bin/bash
## The file use UTF-8 encoding.
## zhouke
## 在Linux上解压安装JDK

PROGNAME=$(basename $0)
echo "`date` begin $0, LANG=$LANG, $# args: $*."
function usage () {
	echo "usage: sh $PROGNAME --jdkTarGZ ${JDK_TARGZ} --jdkInstallDir ${JDK_INSTALL_DIR}"
}

if [ $# -eq 0 ]; then
    usage >&2
    exit 31
fi

JDK_TARGZ=NULL
JDK_INSTALL_DIR=NULL
while [[ -n $1 ]]; do
	case $1 in
		--jdkTarGZ) shift
				JDK_TARGZ=$1
				;;
		--jdkInstallDir) shift
				JDK_INSTALL_DIR=$1
				;;
		*) usage >&2
				exit 63
				;;
	esac
	shift
done

if [ "${JDK_INSTALL_DIR}" == "NULL" ]; then
	echo "please use the --jdkInstallDir parameter to specify an installDir(the script will mkdir with it)." >&2
	usage >&2
	exit 31
fi
if [ -e "${JDK_INSTALL_DIR}" ]; then
	echo "the jdkInstallDir already exists, please change another path(the script will mkdir with it)." >&2
	exit 2
fi

mkdir -p ${JDK_INSTALL_DIR}
tar xfz ${JDK_TARGZ}.tar.gz -C ${JDK_INSTALL_DIR} --strip 1
unlink /usr/bin/java
ln -s ${JDK_INSTALL_DIR}/bin/java /usr/bin/java
# 校验安装，输出JDK版本信息
${JDK_INSTALL_DIR}/bin/java -version