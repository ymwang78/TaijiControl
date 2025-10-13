# 使用说明

## 环境要求

操作系统：Linux（Debian/Ubuntu 推荐）

必须安装并配置好：

Docker

Docker Compose V2

## 启动方式

在 TaijiTSDBService/ 目录下执行：

```bash
docker-compose up -d
```

容器会自动：

- 挂载 ./initdb → /docker-entrypoint-initdb.d

- 使用命名卷 pgdata 保存数据库数据

- 读取环境变量启动 TimescaleDB

启动了 docker-compose up -d 之后，容器会常驻运行。

## 管理容器

启动了 docker-compose up -d 之后，你的容器就会常驻运行。管理容器的方法有几类常用命令：

### 🔍 查看容器状态

```bash
# 查看所有正在运行的容器
docker ps

# 查看包括已停止的容器
docker ps -a

# 如果用 docker-compose 启动，可以更方便：
docker-compose ps

# 只看已停止但未删除的容器
docker ps -a -f status=exited

```

### ⏹️ 停止容器

```bash
# 停止名为 tsdb 的容器
docker stop tsdb

# 如果是 docker-compose 管理的，可以一次性停止所有服务：
docker-compose down
```

区别：

docker stop tsdb 只会停止容器，但数据卷不会删掉，下次 docker start tsdb 可以再启动。

docker-compose down 默认会停止并删除容器（数据卷默认保留，除非加 -v）。

### 🚪 进入容器内部

```bash
# 进入 tsdb 容器的 bash 终端
docker exec -it tsdb bash

# 如果镜像里没有 bash，可以用 sh
docker exec -it tsdb sh
```

进入后，你就在容器里了，可以像在一个 Linux 里一样操作。

### 📖 查看容器日志

```bash
# 实时查看日志
docker logs -f tsdb
```

这对数据库服务很有用，可以确认是否初始化成功。

### ✅ 小结：

看容器 → docker ps 或 docker-compose ps

停容器 → docker stop tsdb 或 docker-compose down

进容器 → docker exec -it tsdb bash

看日志 → docker logs -f tsdb




