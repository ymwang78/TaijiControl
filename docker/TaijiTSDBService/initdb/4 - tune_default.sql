-- ==========================================================
-- PostgreSQL 4GB 内存 + 大硬盘 专用配置 (Default Tuning)
-- ==========================================================

-- 1. 内存核心 (Memory)
-- 保持 1GB (25% 内存)，这是 4GB 机器的标准安全线
ALTER SYSTEM SET shared_buffers = '1GB';

-- 保持 4GB。
-- 虽然物理内存只有 4GB，但此参数只是给优化器的"暗示"，
-- 设置为 4GB (默认值) 告诉它倾向于走索引，符合你"不小于默认值"的要求。
ALTER SYSTEM SET effective_cache_size = '4GB';

-- 设为 8MB (默认是 4MB)。
-- 4GB 内存很紧张，8MB 是兼顾排序速度和防 OOM 的平衡点。
ALTER SYSTEM SET work_mem = '8MB';

-- 设为 256MB (默认是 64MB)。
-- 用于建索引和 VACUUM，256MB 足够处理常规维护。
ALTER SYSTEM SET maintenance_work_mem = '256MB';

-- 2. 利用"大硬盘"优势优化写入 (WAL)
-- 既然硬盘很大，我们不需要吝啬日志空间。

-- WAL 缓冲区，16MB 是标准值 (默认通常是 shared_buffers 的 1/32)。
ALTER SYSTEM SET wal_buffers = '16MB';

-- [关键优化] 最小日志保留量设为 2GB (默认 80MB)。
-- 减少日志文件的反复创建和回收，降低文件系统碎片。
ALTER SYSTEM SET min_wal_size = '2GB';

-- [关键优化] 最大日志设为 8GB (默认 1GB)。
-- 利用你的大硬盘优势！这将大幅延长 Checkpoint 间隔，
-- 让数据库可以连续平滑写入更久，才会触发一次强制刷盘。
ALTER SYSTEM SET max_wal_size = '8GB';

-- 让刷盘过程平滑分布，防止 IO 卡顿 (默认 0.5 or 0.9)
ALTER SYSTEM SET checkpoint_completion_target = '0.9';

-- 3. 并发与后台 (Concurrency)
-- 必须加载 TimescaleDB
ALTER SYSTEM SET shared_preload_libraries = 'timescaledb';

-- 4GB 机器通常 CPU 核数不多，保持保守并发
ALTER SYSTEM SET "timescaledb.max_background_workers" = '4';
ALTER SYSTEM SET max_worker_processes = '8';
ALTER SYSTEM SET max_parallel_workers_per_gather = '2';
ALTER SYSTEM SET max_parallel_workers = '4';

-- 4. 磁盘与 IO 优化 (HDD假设)
-- random_page_cost:
-- SSD 设为 1.1，HDD 设为 4.0。
ALTER SYSTEM SET random_page_cost = '4.0';

-- 5. 高级选项 (修正了之前的语法错误)
-- 允许异步提交，牺牲 <1秒 数据安全换取极大写入性能
ALTER SYSTEM SET synchronous_commit = 'off';

-- 尝试开启大页内存
ALTER SYSTEM SET huge_pages = 'try';


-- 6. 网络与端口配置
-- 修改数据库监听端口为 22400
-- 注意：此设置会在数据库服务重启后生效
ALTER SYSTEM SET listen_addresses = '*';
ALTER SYSTEM SET port = '22400';