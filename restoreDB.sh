#!/bin/bash
#####################################################################################
# һ����ԭԶ��SQLServer���ݿ⹤�ߣ���װλ������ isql.json Ϊ�ű������ļ� �ͱ��ű�������ͬһĿ¼��
# ˼·��ʹ��ftp������bak�ļ��ϴ���Զ�˷����� ʹ��freetds����Զ��SQLServer���� ִ�нű���ԭ���ݿ�
# ������ϵ brew install jq freetds
# ���ý���
# bakPath			: ���ش��bak�ļ���·��
# sqladminname		: ���ݿ��˻���
# sqladminpass		: ���ݿ�����
# sqldatapath		: SQLServerĬ�����ݿ��ļ��洢·��
# databakpath		: ftp��Ŀ¼·��
# ftpuser			: ftp�û�
# ftppass			: ftp����
####################################################################################
# ��������
# $1 �������� ����IP��ַ 
# $2 �����ļ����ƣ�ͳһ���������ļ�ָ����·���� �ݲ�֧�־���·�� һ���ļ��ж������ʹ�õ�һ��
# $3 ָ�������ݿ����� ��ָ���������ʹ�ñ����ļ��е�����
####################################################################################

# ����׼��
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
# �ڶ����г�ʼ���ò���
dataBaseName=
logName=

# �ϴ����ݿⱸ���ļ�
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

# ���������� �ж��Ƿ��ϴ��ɹ�����������ز���
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

# ִ�����ݿ���䣨��ѯ�����ļ���Ϣ��
databaseNameFn(){
	pre_sql="RESTORE FILELISTONLY FROM DISK = '$databakpath\\$2'"
	tsql -S $1 -U $sqladminname -P $sqladminpass<<EOF
$pre_sql
go
exit
EOF
}

# ɨ��ִ�н�� ��ȡ���ݿ�����
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

# ִ��ǿ�ƻ�ԭ���ݿ�
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

# ִ�л�ԭ���ݿ� �����ϴ��ļ���Զ�̣��������ݿⲢ��ȡ���ݿ����ƣ�ִ�л�ԭ���ݿ⣻
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
