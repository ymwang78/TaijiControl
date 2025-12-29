\connect tsdb_template

-- 1. 创建全局保留策略配置表
CREATE TABLE public.global_retention_config (
    id bool PRIMARY KEY DEFAULT true,
    retention_months integer NOT NULL DEFAULT 0 CHECK (retention_months >= 0),
    retention_days integer NOT NULL DEFAULT 0 CHECK (retention_days >= 0),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT singleton_check CHECK (id),
    CONSTRAINT positive_duration CHECK (retention_months > 0 OR retention_days > 0)
);

-- ========================================================
-- [新增] 自动更新 updated_at 的函数和触发器
-- ========================================================
CREATE OR REPLACE FUNCTION public.update_modified_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW; -- 返回修改后的新行，包含新的时间
END;
$$ language 'plpgsql';

CREATE TRIGGER trg_set_timestamp
    BEFORE UPDATE ON public.global_retention_config
    FOR EACH ROW
    EXECUTE FUNCTION public.update_modified_column();
-- ========================================================


-- 2. 定义自动应用策略的函数 (原有逻辑不变)
CREATE OR REPLACE FUNCTION public.apply_global_retention_policy()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    _interval interval;
    _target_table text;
    _tables text[] := ARRAY['tsdata', 'tsdata_minutely', 'tsdata_hourly', 'tsdata_daily'];
BEGIN
    _interval := make_interval(months => NEW.retention_months, days => NEW.retention_days);

    FOREACH _target_table IN ARRAY _tables LOOP
        BEGIN
            IF to_regclass(_target_table) IS NOT NULL THEN
                PERFORM remove_retention_policy(_target_table, if_exists => true);
                PERFORM add_retention_policy(_target_table, drop_after => _interval);
                RAISE NOTICE 'Updated retention policy for table % to: %', _target_table, _interval;
            ELSE
                RAISE NOTICE 'Skipping table % (does not exist)', _target_table;
            END IF;
        EXCEPTION WHEN OTHERS THEN
            RAISE WARNING 'Failed to set retention policy for table %: %', _target_table, SQLERRM;
        END;
    END LOOP;

    RETURN NEW;
END;
$$;

-- 3. 创建应用策略的触发器 (原有逻辑不变)
CREATE TRIGGER trg_update_global_retention
    AFTER INSERT OR UPDATE OF retention_months, retention_days
    ON public.global_retention_config
    FOR EACH ROW
    EXECUTE FUNCTION public.apply_global_retention_policy();

-- 4. 初始化默认值
INSERT INTO public.global_retention_config (retention_months, retention_days) VALUES (1200, 0);

-- 5. 保护规则
CREATE RULE rule_prevent_deletion AS
    ON DELETE TO public.global_retention_config
    DO INSTEAD NOTHING;

UPDATE pg_database SET datistemplate = true WHERE datname = 'tsdb_template';