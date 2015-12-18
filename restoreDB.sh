#!/bin/bash
#####################################################################################
# 一键还原远程SQLServer数据库工具，安装位置随意 isql.json 为脚本配置文件 和本脚本放置在同一目录中
# 思路：使用ftp将本地bak文件上传至远端服务器 使用freetds连接远端SQLServer服务 执行脚本还原数据库
# 依赖关系 brew install jq freetds
# 配置解释
# bakPath			: 本地存放bak文件的路径
# sqladminname		: 数据库账户名
# sqladminpass		: 数据库密码
# sqldatapath		: SQLServer默认数据库文件存储路径
# databakpath		: ftp根目录路径
# ftpuser			: ftp用户
# ftppass			: ftp密码
####################################################################################
# 参数解释
# $1 机器域名 或者IP地址 
# $2 备份文件名称，统一放在配置文件指定的路径中 暂不支持绝对路径 一个文件中多个备份使用第一个
# $3 指定的数据库名称 不指定的情况下使用备份文件中的名称
####################################################################################

# 参数准备
repath=$(cd `dirname $0`; pwd)
file=$repath/isql.json
bakPath=`cat $file | jq -r '.bakPath'`
sqladminname=`cat $file | jq -r .$1'.sqladminname'`
sqladminpass=`cat $file | jq -r .$1'.sqladminpass'`
sqldatapath=`cat $file | jq -r .$1'.sqldatapath'`
databakpath=`cat $file | jq -r .$1'.databakpath'`
ftpuser=`cat $file | jq -r .$1'.ftpuser'`
ftppass=`cat $file | jq -r .$1'.ftppass'`
bakPath=$bakPath/$2
# 第二步中初始化该参数
dataBaseName=
logName=

# 上传数据库备份文件
uploadFile(){
	ftp -n $1<<EOF
		quote USER $ftpuser
		quote PASS $ftppass
		binary
		put $bakPath $2
		ls
		quit
EOF
}

# 根据输出结果 判定是否上传成功，并返回相关参数
exUploadFile(){
	echo "Start upload bak file......"
	ftpinfo=`uploadFile $1 $2 | awk '$9 ~ /'"$2"'/ {print $9,"(" $8 ")"}'`
	echo "The bak file is: "$ftpinfo
	if [ -z "$ftpinfo" ]
	then
		echo "error:upload file error"
		return 1
	fi
}

# 执行数据库语句（查询备份文件信息）
databaseNameFn(){
	pre_sql="RESTORE FILELISTONLY FROM DISK = '$databakpath\\$2'"
	tsql -S $1 -U $sqladminname -P $sqladminpass<<EOF
$pre_sql
go
exit
EOF
}

# 扫描执行结果 获取数据库名称
exDatabaseName(){
	tmpout=`databaseNameFn $1 $2 | awk 'BEGIN{FS="\t"} $2 ~ /.mdf/ || $2 ~ /.ldf/ {print $1}'`
	dataBaseName=`echo $tmpout | awk '{print $1}'`
	logName=`echo $tmpout | awk '{print $2}'`
	echo "The dataBase name is: "$dataBaseName
	echo "The logFile name is: "$logName
	if [ -z "$dataBaseName" ]
	then
		echo "error:exe sql error"
		return 1
	fi
}

# 执行强制还原数据库
retoreDB(){
	tmpDataName=$dataBaseName
	tmpLogName=$dataBaseName'_log'
	if [ -n "$3" ]
	then 
		tmpDataName=$3
		tmpLogName=$3'_log'
	fi
	echo "Start restore database......"
	sql="RESTORE DATABASE \"$tmpDataName\" FROM DISK='$databakpath\\$2' WITH REPLACE,
		MOVE '$dataBaseName' TO '$sqldatapath\\$tmpDataName.mdf',
		MOVE '$logName' TO '$sqldatapath\\$tmpLogName.ldf'"
	tsql -S $1 -U $sqladminname -P $sqladminpass<<EOF >> /dev/null
$sql
go
exit
EOF
}

# 执行还原数据库 首先上传文件致远程；连接数据库并获取数据库名称；执行还原数据库；
exeRestore(){
	if [[ ! -f $bakPath ]]; then
		echo "File $bakPath does not exist"
		return 1
	fi
	exUploadFile $1 $2
	exresult=$?
	if [ 0 -eq $exresult ];then 
		exDatabaseName $1 $2 $3
		exresult=$?
	fi

	if [ 0 -eq $exresult ];then 
		retoreDB $1 $2 $3
	fi
}

exeRestore $1 $2 $3
