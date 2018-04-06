#!/bin/bash
## centOS7编译MariaDB10.2.7
## zhouke
## The file use UTF-8 encoding.
## 在Linux上编译安装MariaDB的脚本 ；需要Linux先装有gcc-c++、ncurses-devel,gnutls-devel
## MariaDB的cmake阶段在脚本中执行还是会报tokuDB的错误，但是这一句拿出来单独执行却没问题，如果报错，删除CMakeCache.txt，然后单独执行cmake命令

PROGNAME=$0
SRCTARGZ=mariadb-10.2.7
INSTALL_DIR=NULL
DATA_DIR=NULL

echo "====== `date` begin $0, LANG=$LANG, $# args: $*."
function usage () {
	echo "usage: sh $PROGNAME --installDir ${INSTALL_DIR} --dataDir ${DATA_DIR} [--srcTarGZ mariadb-10.2.7]"
}

function installCmake () {
	tar xfz cmake-3.8.2.tar.gz
	cd cmake-3.8.2
	./bootstrap
	make
	make install
	cmake --version
	# 回到之前的目录
	cd -
}

if [ $# -eq 0 ]; then
    usage >&2
    exit 31
fi


while [[ -n $1 ]]; do
	case $1 in
		--installDir) shift
				INSTALL_DIR=$1
				;;
		--dataDir) shift
				DATA_DIR=$1
				;;
		--srcTarGZ) shift
				SRCTARGZ=$1
				;;
		*) usage >&2
				exit 63
				;;
	esac
	shift
done

if [ "${INSTALL_DIR}" == "NULL" ]; then
	echo "please use the --installDir parameter to specify an installDir(the script will mkdir with it)." >&2
	usage >&2
	exit 31
fi
if [ -e "${INSTALL_DIR}" ]; then
	echo "the installDir already exists, please change another path(the script will mkdir with it)." >&2
	exit 2
fi

if [ "${DATA_DIR}" == "NULL" ]; then
	echo "please use the --dataDir parameter to specify dataDir(the script will mkdir with it)." >&2
	usage >&2
	exit 31
fi
if [ -e "${DATA_DIR}" ]; then
	echo "the dataDir already exists, please change another path(the script will mkdir with it)." >&2
	exit 2
fi

# 依赖库检查
cmake --version
LAST_EXITVALUE=$?
if [ "$LAST_EXITVALUE" -ne 0 ]; then
	echo "===`date`=== cmake not found(exit=$LAST_EXITVALUE), so now first install cmake..."
	installCmake
fi

# 准备工作：创建用户和组、数据目录
groupadd mysql
useradd -r -g mysql -s /sbin/nologin mysql
mkdir -p ${DATA_DIR}
chown -R mysql:mysql ${DATA_DIR}

# 解压
tar xfz ${SRCTARGZ}.tar.gz
cd ${SRCTARGZ}

## 是否还需要装其他东西呢？下面检查依赖关系：
cmake -graphviz .
LAST_EXITVALUE=$?
if [ "$LAST_EXITVALUE" -ne 0 ]; then
	echo "===`date`=== some depend library not found by cmake graphviz, please resolve it."
	exit ${LAST_EXITVALUE}
fi
## TODO 有些机器缺ncurses-devel，暂未找到脚本化判断的方法
#yum -y install ncurses-devel、可能需要先配可用的yum源（比如CentOS6-Base-163.repo）

# 编译安装
# -DWITHOUT_TOKUDB=1 不安装tokuDB引擎
cmake . -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR} -DMYSQL_DATADIR=${DATA_DIR}  -DDEFAULT_CHARSET=utf8 -DDEFAULT_COLLATION=utf8_general_ci -DWITHOUT_TOKUDB=1
LAST_EXITVALUE=$?
if [ "$LAST_EXITVALUE" -ne 0 ]; then
	echo "===`date`=== fail on cmake(exit=$LAST_EXITVALUE)! please find more detail info."
	exit 1
fi
make
make install

# 安装系统库、配置my.cnf文件
# innodb_additional_mem_pool_size变量在10.2弃用了
cp -pv ${INSTALL_DIR}/support-files/my-innodb-heavy-4G.cnf ${INSTALL_DIR}/my.cnf
sed -i 's/innodb_additional_mem_pool_size=16M/ /g' ${INSTALL_DIR}/my.cnf
scripts/mysql_install_db --defaults-file=${INSTALL_DIR}/my.cnf --user=mysql --basedir=${INSTALL_DIR} --datadir=${DATA_DIR}
#sed -i 's/innodb_flush_log_at_trx_commit = 1/innodb_flush_log_at_trx_commit=2/g' ${INSTALL_DIR}/my.cnf
sed -i 's/log-bin=mysql-bin/#log-bin=mysql-bin/g' ${INSTALL_DIR}/my.cnf

# 检查mysql全局配置文件（Linux有时预装有，会有干扰，导致一些莫名问题，因此将其改个名字）
if [ -f "/etc/my.cnf" ]; then
	mv /etc/my.cnf /etc/my.cnfBundled_NotUse
	echo "the /etc/my.cnf exists, so move it to /etc/my.cnfBundled_NotUse." >&2
fi

# 配成Linux服务
cp -pv ${INSTALL_DIR}/support-files/mysql.server /etc/init.d/mariadb
sed -i 's/service_startup_timeout=900/service_startup_timeout=180/g' /etc/init.d/mariadb
chkconfig --add /etc/init.d/mariadb
chkconfig --list mariadb

# 校验安装，输出版本、支持的引擎等信息
${INSTALL_DIR}/bin/mysql --version
service mariadb start
${INSTALL_DIR}/bin/mysql -uroot -e "show engines"