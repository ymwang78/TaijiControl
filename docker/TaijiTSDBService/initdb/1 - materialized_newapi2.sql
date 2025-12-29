\connect tsdb_template

-- =========================================================
-- 1. Minutely 视图
-- =========================================================
CREATE MATERIALIZED VIEW public.tsdata_minutely
WITH (
    timescaledb.continuous,
    timescaledb.materialized_only = false
) AS
SELECT
    time_bucket('1 minute', time_stamp) AS bucket_minute,
    tag_id,
    first(value, time_stamp) AS first_value,
    avg(value) AS avg_value,
    max(value) AS max_value,
    min(value) AS min_value,
    sum(value::double precision) AS sum_value,
    count(value) AS count_value
FROM
    public.tsdata
WHERE
    value_quality is null or (value_quality >> 8) = 1
GROUP BY
    bucket_minute, tag_id
WITH NO DATA;

-- 修正：创建后单独开启压缩
ALTER MATERIALIZED VIEW public.tsdata_minutely SET (
    timescaledb.compress = true,
    timescaledb.compress_orderby = 'bucket_minute',
    timescaledb.compress_segmentby = 'tag_id'
);

-- =========================================================
-- 2. Hourly 视图 (基于 Minutely)
-- =========================================================
CREATE MATERIALIZED VIEW public.tsdata_hourly
WITH (
    timescaledb.continuous,
    timescaledb.materialized_only = false
) AS
SELECT
    time_bucket('1 hour', bucket_minute) AS bucket_hour,
    tag_id,
    first(first_value, bucket_minute) AS first_value,
    sum(sum_value) / NULLIF(sum(count_value), 0) AS avg_value,
    max(max_value) AS max_value,
    min(min_value) AS min_value,
    sum(sum_value) AS sum_value,
    sum(count_value) AS count_value
FROM
    public.tsdata_minutely
GROUP BY
    bucket_hour, tag_id
WITH NO DATA;

-- 修正：创建后单独开启压缩
ALTER MATERIALIZED VIEW public.tsdata_hourly SET (
    timescaledb.compress = true,
    timescaledb.compress_orderby = 'bucket_hour',
    timescaledb.compress_segmentby = 'tag_id'
);

-- =========================================================
-- 3. Daily 视图 (基于 Hourly)
-- =========================================================
CREATE MATERIALIZED VIEW public.tsdata_daily
WITH (
    timescaledb.continuous,
    timescaledb.materialized_only = false
) AS
SELECT
    time_bucket('1 day', bucket_hour) AS bucket_day,
    tag_id,
    first(first_value, bucket_hour) AS first_value,
    sum(sum_value) / NULLIF(sum(count_value), 0) AS avg_value,
    max(max_value) AS max_value,
    min(min_value) AS min_value
FROM
    public.tsdata_hourly
GROUP BY
    bucket_day, tag_id
WITH NO DATA;

-- 修正：创建后单独开启压缩
ALTER MATERIALIZED VIEW public.tsdata_daily SET (
    timescaledb.compress = true,
    timescaledb.compress_orderby = 'bucket_day',
    timescaledb.compress_segmentby = 'tag_id'
);

-- =========================================================
-- 4. 激进的策略安装函数
-- =========================================================
CREATE OR REPLACE FUNCTION public.install_policies()
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    -- [Minutely 刷新策略]
    PERFORM add_continuous_aggregate_policy('tsdata_minutely',
        start_offset => INTERVAL '1 hour',
        end_offset => INTERVAL '1 minute',
        schedule_interval => INTERVAL '1 minute');

    -- [Hourly 刷新策略]
    PERFORM add_continuous_aggregate_policy('tsdata_hourly',
        start_offset => INTERVAL '6 hours',
        end_offset => INTERVAL '1 hour',
        schedule_interval => INTERVAL '1 hour');

    -- [Daily 刷新策略]
    PERFORM add_continuous_aggregate_policy('tsdata_daily',
        start_offset => INTERVAL '3 days',
        end_offset => INTERVAL '1 day',
        schedule_interval => INTERVAL '1 day');

    -- =========================================================
    -- [压缩策略配置]
    -- =========================================================

    -- 1. 原始表 tsdata:
    PERFORM add_compression_policy('tsdata', compress_after => INTERVAL '2 hours');

    -- 2. Minutely 视图:
    PERFORM add_compression_policy('tsdata_minutely', compress_after => INTERVAL '1 day');

    -- 3. Hourly 视图:
    PERFORM add_compression_policy('tsdata_hourly', compress_after => INTERVAL '4 days');

    -- 4. Daily 视图:
    PERFORM add_compression_policy('tsdata_daily', compress_after => INTERVAL '10 days');

END;
$$;