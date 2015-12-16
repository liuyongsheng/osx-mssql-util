## restore-MSSQL-for-Mac

**说明:** osx 系统 还原远程SQLServer数据库工具，安装位置随意 isql.json 为脚本配置文件 和本脚本放置在同一目录中

**思路:**使用ftp将本地bak文件上传至远端服务器 使用freetds连接远端SQLServer服务 执行脚本还原数据库 远端需要有ftp服务作为支撑

**依赖关系:**  brew install jq freetds
