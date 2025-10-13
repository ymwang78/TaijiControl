\connect postgres
CREATE DATABASE tsdb_template TEMPLATE template1;

\connect tsdb_template
CREATE EXTENSION IF NOT EXISTS btree_gist;
CREATE EXTENSION IF NOT EXISTS timescaledb;

DROP MATERIALIZED VIEW IF EXISTS public.tsdata_daily CASCADE;
DROP MATERIALIZED VIEW IF EXISTS public.tsdata_hourly CASCADE;
DROP MATERIALIZED VIEW IF EXISTS public.tsdata_minutely CASCADE;
DROP TABLE IF EXISTS public.units CASCADE;
DROP TABLE IF EXISTS public.sources CASCADE;
DROP TABLE IF EXISTS public.metrics CASCADE;
DROP TABLE IF EXISTS public.tags CASCADE;
DROP TABLE IF EXISTS public.tsdata CASCADE;

-------------------------------------------------------------------------------------------------

CREATE SEQUENCE IF NOT EXISTS units_unit_id_seq;
CREATE SEQUENCE IF NOT EXISTS sources_source_id_seq;
CREATE SEQUENCE IF NOT EXISTS metrics_metric_id_seq;
CREATE SEQUENCE IF NOT EXISTS tags_tag_id_seq START WITH 100000;

-------------------------------------------------------------------------------------------------

-- Table: public.units

CREATE TABLE IF NOT EXISTS public.units
(
    unit_id integer NOT NULL DEFAULT nextval('units_unit_id_seq'::regclass),
    unit_name text COLLATE pg_catalog."default" NOT NULL,
    unit_name_zh text COLLATE pg_catalog."default" NOT NULL,
    description jsonb,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT units_pkey PRIMARY KEY (unit_id),
    CONSTRAINT units_unit_name_key UNIQUE (unit_name),
    CONSTRAINT units_unit_name_zh_key UNIQUE (unit_name_zh)
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS public.units
    OWNER to postgres;
-- Index: idx_unit_name

-- DROP INDEX IF EXISTS public.idx_unit_name;

CREATE INDEX IF NOT EXISTS idx_unit_name
    ON public.units USING btree
    (unit_name COLLATE pg_catalog."default" ASC NULLS LAST)
    TABLESPACE pg_default;
-- Index: idx_unit_name_zh

-- DROP INDEX IF EXISTS public.idx_unit_name_zh;

CREATE INDEX IF NOT EXISTS idx_unit_name_zh
    ON public.units USING btree
    (unit_name_zh COLLATE pg_catalog."default" ASC NULLS LAST)
    TABLESPACE pg_default;

-- Trigger function: update_timestamp
CREATE OR REPLACE FUNCTION public.update_timestamp()
RETURNS trigger AS $$
BEGIN
    IF row(NEW.*) IS DISTINCT FROM row(OLD.*) THEN
        NEW.updated_at = CURRENT_TIMESTAMP;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- DROP TRIGGER IF EXISTS update_units_timestamp ON public.units;

CREATE OR REPLACE TRIGGER update_units_timestamp
    BEFORE UPDATE 
    ON public.units
    FOR EACH ROW
    EXECUTE FUNCTION public.update_timestamp();

-------------------------------------------------------------------------------------------------

-- Table: public.sources

-- DROP TABLE IF EXISTS public.sources;

CREATE TYPE protocol_enum AS ENUM (
    'OPC-UA',
    'OPC-DA',
    'MODBUS'
);

CREATE TYPE status_enum AS ENUM (
    'ACTIVE',
    'INACTIVE',
    'DISABLED'
);

CREATE TABLE IF NOT EXISTS public.sources
(
    source_id integer NOT NULL DEFAULT nextval('sources_source_id_seq'::regclass),
    source_name text COLLATE pg_catalog."default" NOT NULL,
    source_type text COLLATE pg_catalog."default" NOT NULL,
    interval_msec integer NOT NULL,
    status status_enum NOT NULL DEFAULT 'ACTIVE'::status_enum,
    protocol protocol_enum NOT NULL,
    endpoint text COLLATE pg_catalog."default",
    auth_config jsonb,
    conn_policy jsonb,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    description jsonb,
    CONSTRAINT sources_pkey PRIMARY KEY (source_id)
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS public.sources
    OWNER to postgres;
-- Index: idx_sources_name

-- DROP INDEX IF EXISTS public.idx_sources_name;

CREATE INDEX IF NOT EXISTS idx_sources_name
    ON public.sources USING btree
    (source_name COLLATE pg_catalog."default" ASC NULLS LAST)
    TABLESPACE pg_default;
-- Index: idx_sources_protocol

-- DROP INDEX IF EXISTS public.idx_sources_protocol;

CREATE INDEX IF NOT EXISTS idx_sources_protocol
    ON public.sources USING btree
    (protocol ASC NULLS LAST)
    TABLESPACE pg_default;
-- Index: idx_sources_status

-- DROP INDEX IF EXISTS public.idx_sources_status;

CREATE INDEX IF NOT EXISTS idx_sources_status
    ON public.sources USING btree
    (status ASC NULLS LAST)
    TABLESPACE pg_default;

-- Trigger: update_sources_timestamp

-- DROP TRIGGER IF EXISTS update_sources_timestamp ON public.sources;

CREATE OR REPLACE TRIGGER update_sources_timestamp
    BEFORE UPDATE 
    ON public.sources
    FOR EACH ROW
    EXECUTE FUNCTION public.update_timestamp();

-------------------------------------------------------------------------------------------------

-- Table: public.metrics

-- DROP TABLE IF EXISTS public.metrics;

CREATE TABLE IF NOT EXISTS public.metrics
(
    metric_id integer NOT NULL DEFAULT nextval('metrics_metric_id_seq'::regclass),
    metric_name text COLLATE pg_catalog."default" NOT NULL,
    metric_name_zh text COLLATE pg_catalog."default" NOT NULL,
    unit_id integer,
    description jsonb,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT metrics_pkey PRIMARY KEY (metric_id),
    CONSTRAINT metrics_metric_name_key UNIQUE (metric_name),
    CONSTRAINT metrics_metric_name_zh_key UNIQUE (metric_name_zh),
    CONSTRAINT metrics_unit_id_fkey FOREIGN KEY (unit_id)
        REFERENCES public.units (unit_id) MATCH SIMPLE
        ON UPDATE NO ACTION
        ON DELETE NO ACTION
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS public.metrics
    OWNER to postgres;
-- Index: idx_metric_name

-- DROP INDEX IF EXISTS public.idx_metric_name;

CREATE INDEX IF NOT EXISTS idx_metric_name
    ON public.metrics USING btree
    (metric_name COLLATE pg_catalog."default" ASC NULLS LAST)
    TABLESPACE pg_default;
-- Index: idx_metric_name_zh

-- DROP INDEX IF EXISTS public.idx_metric_name_zh;

CREATE INDEX IF NOT EXISTS idx_metric_name_zh
    ON public.metrics USING btree
    (metric_name_zh COLLATE pg_catalog."default" ASC NULLS LAST)
    TABLESPACE pg_default;

-- Trigger: update_metrics_timestamp

-- DROP TRIGGER IF EXISTS update_metrics_timestamp ON public.metrics;

CREATE OR REPLACE TRIGGER update_metrics_timestamp
    BEFORE UPDATE 
    ON public.metrics
    FOR EACH ROW
    EXECUTE FUNCTION public.update_timestamp();

-------------------------------------------------------------------------------------------------

-- Table: public.tags

-- DROP TABLE IF EXISTS public.tags;

CREATE TABLE IF NOT EXISTS public.tags
(
    tag_id integer NOT NULL DEFAULT nextval('tags_tag_id_seq'::regclass),
    tag_name text NOT NULL,
    metric_id integer,
    positive_error double precision,
    negative_error double precision,
    source_id integer,
    source_tagname text COLLATE pg_catalog."default",
    description jsonb,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    is_deleted boolean NOT NULL DEFAULT false,
    CONSTRAINT tags_pkey PRIMARY KEY (tag_id),
    CONSTRAINT unique_source_tagname_per_source UNIQUE (source_id, source_tagname),
    CONSTRAINT unique_tag_name UNIQUE (tag_name),
    CONSTRAINT tags_metric_id_fkey FOREIGN KEY (metric_id)
        REFERENCES public.metrics (metric_id) MATCH SIMPLE
        ON UPDATE NO ACTION
        ON DELETE NO ACTION,
    CONSTRAINT tags_source_id_fkey FOREIGN KEY (source_id)
        REFERENCES public.sources (source_id) MATCH SIMPLE
        ON UPDATE NO ACTION
        ON DELETE NO ACTION,
    CONSTRAINT check_error_range CHECK (positive_error >= 0::double precision AND negative_error <= 0::double precision)
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS public.tags
    OWNER to postgres;
-- Index: idx_tags_path

-- DROP INDEX IF EXISTS public.idx_tags_path;

CREATE INDEX IF NOT EXISTS idx_tags_tag_name
    ON public.tags USING btree (tag_name);

CREATE INDEX IF NOT EXISTS idx_tags_tag_name_is_deleted
    ON public.tags USING btree (tag_name, is_deleted);

-- DROP INDEX IF EXISTS public.idx_tags_source_id;

CREATE INDEX IF NOT EXISTS idx_tags_source_id
    ON public.tags USING btree
    (source_id ASC NULLS LAST)
    TABLESPACE pg_default;
-- Index: idx_tags_source_tagname

-- DROP INDEX IF EXISTS public.idx_tags_source_tagname;

CREATE INDEX IF NOT EXISTS idx_tags_source_tagname
    ON public.tags USING btree
    (source_tagname COLLATE pg_catalog."default" ASC NULLS LAST)
    TABLESPACE pg_default;

-- Trigger: update_tags_timestamp

-- DROP TRIGGER IF EXISTS update_tags_timestamp ON public.tags;

CREATE OR REPLACE TRIGGER update_tags_timestamp
    BEFORE UPDATE 
    ON public.tags
    FOR EACH ROW
    EXECUTE FUNCTION public.update_timestamp();

-------------------------------------------------------------------------------------------------

-- Table: public.tsdata

-- DROP TABLE IF EXISTS public.tsdata;

CREATE TABLE IF NOT EXISTS public.tsdata
(
    time_stamp timestamp with time zone NOT NULL,
    tag_id integer NOT NULL,
    value real NOT NULL,
    value_quality smallint DEFAULT 100,
    CONSTRAINT tsdata_pkey PRIMARY KEY (tag_id, time_stamp)
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS public.tsdata
    OWNER to postgres;
-- Index: idx_tsdata_latest

-- DROP INDEX IF EXISTS public.idx_tsdata_latest;

CREATE INDEX IF NOT EXISTS idx_tsdata_latest
    ON public.tsdata USING btree
    (tag_id ASC NULLS LAST, time_stamp DESC NULLS FIRST)
    TABLESPACE pg_default;
-- Index: tsdata_time_stamp_idx

-- DROP INDEX IF EXISTS public.tsdata_time_stamp_idx;

CREATE EXTENSION IF NOT EXISTS timescaledb;

SELECT create_hypertable('tsdata', 'time_stamp', chunk_time_interval => INTERVAL '4 hour');
ALTER TABLE tsdata SET (
    timescaledb.compress,
    timescaledb.compress_orderby = 'time_stamp',
    timescaledb.compress_segmentby = 'tag_id'
);
SELECT add_compression_policy('tsdata', INTERVAL '6 hours');
-------------------------------------------------------------------------------------------------

