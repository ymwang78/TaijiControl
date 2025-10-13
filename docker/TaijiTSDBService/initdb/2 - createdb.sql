\connect postgres;

-- 创建业务数据库
CREATE DATABASE tsdb_default
    WITH OWNER = postgres
         TEMPLATE = tsdb_template;

CREATE DATABASE tsdb_simulation
    WITH OWNER = postgres
         TEMPLATE = tsdb_template;

-- 为 tsdb_default 添加 policy
\connect tsdb_default
SELECT install_policies();

-- 为 tsdb_simulation 添加 policy
\connect tsdb_simulation
SELECT install_policies();
