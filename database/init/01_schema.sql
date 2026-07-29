CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  username varchar(80) NOT NULL UNIQUE,
  full_name varchar(160) NOT NULL,
  email varchar(160) UNIQUE,
  password_hash varchar(255) NOT NULL,
  role varchar(16) NOT NULL DEFAULT 'viewer',
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ck_users_role CHECK (role IN ('admin', 'analyst', 'viewer'))
);

CREATE INDEX IF NOT EXISTS ix_users_username ON users (username);
CREATE INDEX IF NOT EXISTS ix_users_role ON users (role);

CREATE TABLE IF NOT EXISTS process_counters (
  year integer PRIMARY KEY,
  last_value integer NOT NULL
);

CREATE TABLE IF NOT EXISTS media_rules (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  media_type varchar(32) NOT NULL UNIQUE,
  name varchar(120) NOT NULL,
  base_radius_meters integer NOT NULL,
  area_threshold_m2 double precision,
  radius_above_threshold_meters integer,
  description text,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ck_media_rules_media_type CHECK (
    media_type IN ('outdoor', 'front light', 'triface', 'painel de led', 'painel eletronico modular', 'empena', 'empena de led')
  ),
  CONSTRAINT ck_media_rules_base_radius CHECK (base_radius_meters > 0),
  CONSTRAINT ck_media_rules_area_threshold CHECK (area_threshold_m2 IS NULL OR area_threshold_m2 > 0),
  CONSTRAINT ck_media_rules_threshold_radius CHECK (
    radius_above_threshold_meters IS NULL OR radius_above_threshold_meters > 0
  ),
  CONSTRAINT ck_media_rules_threshold_pair CHECK (
    (area_threshold_m2 IS NULL) = (radius_above_threshold_meters IS NULL)
  )
);

CREATE INDEX IF NOT EXISTS ix_media_rules_media_type ON media_rules (media_type);

CREATE TABLE IF NOT EXISTS media_assets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  process_code varchar(32) NOT NULL UNIQUE,
  media_type varchar(32) NOT NULL,
  address varchar(255) NOT NULL,
  district varchar(120) NOT NULL,
  latitude double precision NOT NULL,
  longitude double precision NOT NULL,
  geom geometry(Point, 4326)
    GENERATED ALWAYS AS (ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)) STORED,
  area_m2 double precision NOT NULL,
  width_m double precision,
  bottom_height_m double precision NOT NULL,
  top_height_m double precision,
  radius_meters integer NOT NULL,
  status varchar(16) NOT NULL DEFAULT 'análise',
  justification text,
  attachment_links text,
  contact_name varchar(120),
  contact_email varchar(160),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ck_media_assets_media_type CHECK (
    media_type IN ('outdoor', 'front light', 'triface', 'painel de led', 'painel eletronico modular', 'empena', 'empena de led')
  ),
  CONSTRAINT ck_media_assets_status CHECK (
    status IN ('aprovado', 'irregular', 'análise', 'exigência', 'vencido', 'cartografia', 'jurídico', 'vistoria')
  ),
  CONSTRAINT ck_media_assets_latitude CHECK (latitude BETWEEN -90 AND 90),
  CONSTRAINT ck_media_assets_longitude CHECK (longitude BETWEEN -180 AND 180),
  CONSTRAINT ck_media_assets_area CHECK (area_m2 > 0),
  CONSTRAINT ck_media_assets_width CHECK (width_m IS NULL OR width_m > 0),
  CONSTRAINT ck_media_assets_bottom_height CHECK (bottom_height_m >= 0),
  CONSTRAINT ck_media_assets_height_order CHECK (top_height_m IS NULL OR top_height_m >= bottom_height_m)
);

CREATE INDEX IF NOT EXISTS ix_media_assets_process_code ON media_assets (process_code);
CREATE INDEX IF NOT EXISTS ix_media_assets_media_type ON media_assets (media_type);
CREATE INDEX IF NOT EXISTS ix_media_assets_status ON media_assets (status);
CREATE INDEX IF NOT EXISTS ix_media_assets_district ON media_assets (district);
CREATE INDEX IF NOT EXISTS ix_media_assets_geom ON media_assets USING gist (geom);

CREATE TABLE IF NOT EXISTS application_forms (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  asset_id uuid NOT NULL UNIQUE REFERENCES media_assets(id) ON DELETE CASCADE,
  company_responsible varchar(120) NOT NULL,
  municipal_registration varchar(60) NOT NULL,
  property_registration varchar(60) NOT NULL,
  street varchar(180) NOT NULL,
  number varchar(30) NOT NULL,
  district varchar(120) NOT NULL,
  postal_code varchar(9) NOT NULL,
  latitude double precision NOT NULL,
  longitude double precision NOT NULL,
  media_type varchar(32) NOT NULL,
  area_m2 double precision NOT NULL,
  bottom_height_m double precision NOT NULL,
  requester_email varchar(160) NOT NULL,
  attachment_links text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ck_application_forms_media_type CHECK (
    media_type IN ('outdoor', 'front light', 'triface', 'painel de led', 'painel eletronico modular', 'empena', 'empena de led')
  ),
  CONSTRAINT ck_application_forms_latitude CHECK (latitude BETWEEN -90 AND 90),
  CONSTRAINT ck_application_forms_longitude CHECK (longitude BETWEEN -180 AND 180),
  CONSTRAINT ck_application_forms_area CHECK (area_m2 > 0),
  CONSTRAINT ck_application_forms_bottom_height CHECK (bottom_height_m >= 0)
);

CREATE INDEX IF NOT EXISTS ix_application_forms_asset_id ON application_forms (asset_id);
CREATE INDEX IF NOT EXISTS ix_application_forms_company ON application_forms (company_responsible);
CREATE INDEX IF NOT EXISTS ix_application_forms_municipal_registration ON application_forms (municipal_registration);

CREATE TABLE IF NOT EXISTS activity_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  asset_id uuid REFERENCES media_assets(id) ON DELETE SET NULL,
  actor_user_id uuid REFERENCES users(id) ON DELETE SET NULL,
  process_code varchar(32) NOT NULL,
  activity_type varchar(16) NOT NULL,
  message text NOT NULL,
  changes jsonb,
  request_id varchar(36),
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ck_activity_logs_type CHECK (
    activity_type IN ('cadastro', 'aprovacao', 'reprovacao', 'edicao', 'remocao')
  )
);

CREATE INDEX IF NOT EXISTS ix_activity_logs_asset_id ON activity_logs (asset_id);
CREATE INDEX IF NOT EXISTS ix_activity_logs_actor_user_id ON activity_logs (actor_user_id);
CREATE INDEX IF NOT EXISTS ix_activity_logs_process_code ON activity_logs (process_code);
CREATE INDEX IF NOT EXISTS ix_activity_logs_activity_type ON activity_logs (activity_type);
CREATE INDEX IF NOT EXISTS ix_activity_logs_request_id ON activity_logs (request_id);

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS trigger AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_media_assets_updated_at ON media_assets;
CREATE TRIGGER trg_media_assets_updated_at
BEFORE UPDATE ON media_assets
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_users_updated_at ON users;
CREATE TRIGGER trg_users_updated_at
BEFORE UPDATE ON users
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_media_rules_updated_at ON media_rules;
CREATE TRIGGER trg_media_rules_updated_at
BEFORE UPDATE ON media_rules
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_application_forms_updated_at ON application_forms;
CREATE TRIGGER trg_application_forms_updated_at
BEFORE UPDATE ON application_forms
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();
