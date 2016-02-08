#!/bin/bash
sqlutil=$(cd `dirname $0`; pwd)
bakPath=~/Public/SqlServerBak
configfile=$sqlutil/sqlserver.conf
#�����ļ���׺
bakfile=localbak.bak

# ��ȡsqlserver�û���
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

# �г�Զ�̷����������ļ���Ϣ
listfile(){
	ftp -n $1<<EOF
		quote USER $(ftpuser $1)
		quote PASS $(ftppass $1)
		ls $2
		quit
EOF
}

# Զ���ļ���С
remotefilesize(){
	echo $(listfile $1 $2) | awk '{print $5}'
}

# �����ļ���С
localfilesize(){
	ls -l $bakPath/$2 | awk '{print $5}'
}

#�ϴ��ļ� ���Զ���Ѿ����˲��Ҵ�Сһ�� ���ϴ�
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

# ִ�����ݿ���䣨��ѯ�����ļ���Ϣ��
databasename(){
	pre_sql="RESTORE FILELISTONLY FROM DISK = '$(defaultbakpath $1)\\$2'"
	tsql -S $1 -U $(sqlserveruser $1) -P $(sqlserverpass $1)<<EOF
$pre_sql
go
exit
EOF
}

# �г������ļ�����ʵ���ݿ�����
realdatabasename(){
	echo `databasename $1 $2 | awk 'BEGIN{FS="\t"} $2 ~ /.mdf/ || $2 ~ /.ldf/ {print $1}'`
}

# ִ��ǿ�ƻ�ԭ���ݿ�
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

#ִ�в���У�� �����ļ���Զ���ļ�У�� ����ִ�л�ԭ���ݿ�
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

# ��֤������ȷ��
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


# ִ�����ݿ���䣨ִ�б������ݿ⣩
bakdatabase(){
	pre_sql="backup database $2 to disk='$(defaultbakpath $1 )"\\"$2.$bakfile'"
	tsql -S $1 -U $(sqlserveruser $1) -P $(sqlserverpass $1) 2>&1 <<EOF>/dev/null
$pre_sql
go
exit
EOF
}

# ɾ��Զ�̵ı����ļ�
delremotefile(){
	ftp -n $1<<EOF>>/dev/null
		quote USER $(ftpuser $1)
		quote PASS $(ftppass $1)
		mdelete $2.$bakfile
		quote y
		quit
EOF
}

# ����Զ�̱��ݵ��ļ� �����ƶ��������ļ�Ŀ¼
downbakfile(){
	ftp -n $1<<EOF>>/dev/null
		quote USER $(ftpuser $1)
		quote PASS $(ftppass $1)
		get /$2.$bakfile $2.$bakfile
		quit
EOF
	mv $sqlutil/$2.$bakfile $bakPath/$2.$bakfile
}

#ִ���ļ�����ҵ�� 
exebakupdb(){
	echo "First delete remote file "$2.$bakfile
	delremotefile $1 $2 $3
	echo "BackUp database......"
	bakdatabase $1 $2 $3 | awk 'FS="\"" {if($2!="") print $2}' | awk '$1=="Processed"||$2=="DATABASE" {print $0}'
	echo "Download bak file......"
	downbakfile $1 $2 $3
}

#ִ��sql���
exesql(){
	if [ $1".foo" != ".foo" ];then
		tsql -S $1 -U $(sqlserveruser $1) -P $(sqlserverpass $1) 2>&1
	fi
}

# ҵ����� ִ�л�ԭ���ݿ�ͱ������ݿ�
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
