## restore-MSSQL-for-Mac

**说明:** osx 系统 还原远程SQLServer数据库工具，安装位置随意

**思路:**使用ftp将本地bak文件上传至远端服务器 使用freetds连接远端SQLServer服务 执行脚本还原数据库 远端需要有ftp服务作为支撑

**依赖关系:**  brew install freetds

示例1：</br>

```bash
restore localwin test.bak
```
将本地文件test.bak上传到localxp所指向的服务器上，然后进行还原操作

示例2：</br>

```bash
re localwin test.bak test1
```

将本地文件test.bak上传到localxp所指向的服务器上，然后进行还原操作，并将数据库名称指定为test1

示例3：</br>

```bash
bk localwin test
```

将远程数据库备份到本地指定好的文件夹

