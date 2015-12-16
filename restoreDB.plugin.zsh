# for MSSQL
repath=$(cd `dirname $0`; pwd)
alias restore='sh $repath/restoreDB.sh'
alias re='restore'
