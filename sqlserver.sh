#!/bin/bash
sqlutil=$(cd `dirname $0`; pwd)
bakPath=~/Public/SqlServerBak
configfile=$sqlutil/sqlserver.conf
#备份文件后缀
bakfile=localbak.bak

# 获取sqlserver用户名
sqlserveruser(){
	cat $configfile | awk '$1=='\"$1\"' {print $2}'
}

sqlserverpass(){
	cat $configfile | awk '$1=='\"$1\"' {print $3}'
}

defaultdatapath(){
	cat $configfile | awk '$1=='\"$1\"' {print $4}'
}

defaultbakpath(){
	cat $configfile | awk '$1=='\"$1\"' {print $5}'
}

ftpuser(){
	cat $configfile | awk '$1=='\"$1\"' {print $6}'
}

ftppass(){
	cat $configfile | awk '$1=='\"$1\"' {print $7}'
}

# 列出远程符合条件的文件信息
listfile(){
	ftp -n $1<<EOF
		quote USER $(ftpuser $1)
		quote PASS $(ftppass $1)
		ls $2
		quit
EOF
}

# 远程文件大小
remotefilesize(){
	echo $(listfile $1 $2) | awk '{print $5}'
}

# 本地文件大小
localfilesize(){
	ls -l $bakPath/$2 | awk '{print $5}'
}

#上传文件 如果远程已经有了并且大小一样 则不上传
uploadFile(){
	ftp -n $1<<EOF
		quote USER $(ftpuser $1)
		quote PASS $(ftppass $1)
		binary
		put $bakPath/$2 $2
		ls $2
		quit
EOF
}

# 执行数据库语句（查询备份文件信息）
databasename(){
	pre_sql="RESTORE FILELISTONLY FROM DISK = '$(defaultbakpath $1)\\$2'"
	tsql -S $1 -U $(sqlserveruser $1) -P $(sqlserverpass $1)<<EOF
$pre_sql
go
exit
EOF
}

# 列出备份文件的真实数据库名称
realdatabasename(){
	echo `databasename $1 $2 | awk 'BEGIN{FS="\t"} $2 ~ /.mdf/ || $2 ~ /.ldf/ {print $1}'`
}

# 执行强制还原数据库
retoredb(){
	databaseinfo=$(realdatabasename $1 $2)
	dataBaseName=`echo $databaseinfo | awk '{print $1}'`
	logName=`echo $databaseinfo | awk '{print $2}'`
	tmpDataName=$dataBaseName
	tmpLogName=$logName
	if [ -n "$3" ];then
		tmpDataName=$3
		tmpLogName=$3'_log'
	fi
	sql="RESTORE DATABASE \"$tmpDataName\" FROM DISK='$(defaultbakpath $1)\\$2' WITH REPLACE,
		MOVE '$dataBaseName' TO '$(defaultdatapath $1)\\$tmpDataName.mdf',
		MOVE '$logName' TO '$(defaultdatapath $1)\\$tmpLogName.ldf'"
	tsql -S $1 -U $(sqlserveruser $1) -P $(sqlserverpass $1) 2>&1<<EOF>>/dev/null
$sql
go
exit
EOF
}

#执行参数校验 本地文件和远程文件校验 并且执行还原数据库
exeretoredb(){
	echo "Validation params......"
	validation $1 $2 $3
	if [ $?".foo" != "0.foo" ];then 
		return 1
	fi
	if [ $(remotefilesize $1 $2)".foo" != $(localfilesize $1 $2)".foo" ];then 
		echo "Start upload bak file......"
		uploadFile $1 $2 | awk '{print "The bak file is '"$2"' "$8"-"$6"-"$7}'
	fi 
	echo "Start restore database......"
	retoredb $1 $2 $3 | awk 'FS="\"" {if($2!="")print $2}' | awk '$1=="Database"||$2=="DATABASE" {print $0}'
}

# 验证参数正确性
validation(){
	if [ $1".foo" == ".foo" ];then
		return 1
	fi 
	if [ $(sqlserveruser $1)".foo" == ".foo" ];then 
		echo "Please first definde Server Info $1"
		return 1
	fi
	if [[ ! -f $bakPath/$2 ]]; then
		echo "$bakPath/$2 not exist"
		return 1
	fi
}


# 执行数据库语句（执行备份数据库）
bakdatabase(){
	pre_sql="backup database $2 to disk='$(defaultbakpath $1 )"\\"$2.$bakfile'"
	tsql -S $1 -U $(sqlserveruser $1) -P $(sqlserverpass $1) 2>&1 <<EOF>/dev/null
$pre_sql
go
exit
EOF
}

# 删除远程的备份文件
delremotefile(){
	ftp -n $1<<EOF>>/dev/null
		quote USER $(ftpuser $1)
		quote PASS $(ftppass $1)
		mdelete $2.$bakfile
		quote y
		quit
EOF
}

# 下载远程备份的文件 并且移动到备份文件目录
downbakfile(){
	ftp -n $1<<EOF>>/dev/null
		quote USER $(ftpuser $1)
		quote PASS $(ftppass $1)
		get /$2.$bakfile $2.$bakfile
		quit
EOF
	mv $2.$bakfile $bakPath/$2.$bakfile
}

#执行文件备份业务 
exebakupdb(){
	echo "First delete remote file "$2.$bakfile
	delremotefile $1 $2 $3
	echo "BackUp database......"
	bakdatabase $1 $2 $3 | awk 'FS="\"" {if($2!="") print $2}' | awk '$1=="Processed"||$2=="DATABASE" {print $0}'
	echo "Download bak file......"
	downbakfile $1 $2 $3
}

#执行sql语句
exesql(){
	if [ $1".foo" != ".foo" ];then
		tsql -S $1 -U $(sqlserveruser $1) -P $(sqlserverpass $1) 2>&1
	fi
}

# 业务控制 执行还原数据库和备份数据库
action(){
	if [ $1".foo" == "re.foo" ];then
		exeretoredb $2 $3 $4
	fi
	if [ $1".foo" == "bk.foo" ];then 
		exebakupdb $2 $3 $4
	fi
	if [ $1".foo" == "sql.foo" ];then 
		exesql $2
	fi
}

action $1 $2 $3 $4
