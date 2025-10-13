\connect tsdb_template

-- 创建连续聚合视图（不加 policy）
CREATE MATERIALIZED VIEW public.tsdata_minutely
WITH (timescaledb.continuous) AS
SELECT
    time_bucket('1 minute', time_stamp) AS bucket_minute,
    tag_id,
    first(value, time_stamp) AS first_value,
    avg(value) AS avg_value,
    max(value) AS max_value,
    min(value) AS min_value
FROM
    public.tsdata
WHERE
    value_quality is null or (value_quality >> 8) = 1
GROUP BY
    bucket_minute, tag_id
WITH NO DATA;

CREATE MATERIALIZED VIEW public.tsdata_hourly
WITH (timescaledb.continuous) AS
SELECT
    time_bucket('1 hour', bucket_minute) AS bucket_hour,
    tag_id,
    first(first_value, bucket_minute) AS first_value,
    avg(avg_value) AS avg_value,
    max(max_value) AS max_value,
    min(min_value) AS min_value
FROM
    public.tsdata_minutely
GROUP BY
    bucket_hour, tag_id
WITH NO DATA;

CREATE MATERIALIZED VIEW public.tsdata_daily
WITH (timescaledb.continuous) AS
SELECT
    time_bucket('1 day', bucket_hour) AS bucket_day,
    tag_id,
    first(first_value, bucket_hour) AS first_value,
    avg(avg_value) AS avg_value,
    max(max_value) AS max_value,
    min(min_value) AS min_value
FROM
    public.tsdata_hourly
GROUP BY
    bucket_day, tag_id
WITH NO DATA;

-- 索引
CREATE INDEX idx_tsdata_minutely_tag_time ON tsdata_minutely (tag_id, bucket_minute);
CREATE INDEX idx_tsdata_hourly_tag_time ON tsdata_hourly (tag_id, bucket_hour);
CREATE INDEX idx_tsdata_daily_tag_time ON tsdata_daily (tag_id, bucket_day);

-- 压缩设置（不加 policy）
ALTER MATERIALIZED VIEW tsdata_minutely SET (
    timescaledb.compress,
    timescaledb.compress_orderby = 'bucket_minute',
    timescaledb.compress_segmentby = 'tag_id'
);

ALTER MATERIALIZED VIEW tsdata_hourly SET (
    timescaledb.compress,
    timescaledb.compress_orderby = 'bucket_hour',
    timescaledb.compress_segmentby = 'tag_id'
);

ALTER MATERIALIZED VIEW tsdata_daily SET (
    timescaledb.compress,
    timescaledb.compress_orderby = 'bucket_day',
    timescaledb.compress_segmentby = 'tag_id'
);

-- 定义一个函数，用于在业务库里添加 policy
CREATE OR REPLACE FUNCTION public.install_policies()
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    PERFORM add_continuous_aggregate_policy('tsdata_minutely',
        start_offset => INTERVAL '2 hours',
        end_offset => INTERVAL '1 minute',
        schedule_interval => INTERVAL '1 minute');

    PERFORM add_continuous_aggregate_policy('tsdata_hourly',
        start_offset => INTERVAL '2 days',
        end_offset => INTERVAL '5 minutes',
        schedule_interval => INTERVAL '1 hour');

    PERFORM add_continuous_aggregate_policy('tsdata_daily',
        start_offset => INTERVAL '30 days',
        end_offset => INTERVAL '30 minutes',
        schedule_interval => INTERVAL '1 day');

    PERFORM add_compression_policy('tsdata_minutely', INTERVAL '1 day');
    PERFORM add_compression_policy('tsdata_hourly', INTERVAL '10 days');
    PERFORM add_compression_policy('tsdata_daily', INTERVAL '60 days');
END;
$$;

-- 标记为模板
UPDATE pg_database SET datistemplate = true WHERE datname = 'tsdb_template';