# Add your own custom plugins in the custom/plugins directory. Plugins placed
# here will override ones with the same name in the main plugins directory.
# for MSSQL

sqlutil=$(cd `dirname $0`; pwd)
alias restore='sh $sqlutil/sqlserver.sh re '
alias re='restore'

alias backup='sh $sqlutil/sqlserver.sh bk '
alias bk='backup'