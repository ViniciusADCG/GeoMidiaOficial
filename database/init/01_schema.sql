CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

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
  status varchar(16) NOT NULL DEFAULT 'Pendente',
  justification text,
  contact_name varchar(120),
  contact_email varchar(160),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ck_media_assets_media_type CHECK (
    media_type IN ('outdoor', 'front light', 'triface', 'painel de led', 'empena', 'empena de led')
  ),
  CONSTRAINT ck_media_assets_status CHECK (status IN ('Aprovado', 'Reprovado', 'Pendente')),
  CONSTRAINT ck_media_assets_latitude CHECK (latitude BETWEEN -90 AND 90),
  CONSTRAINT ck_media_assets_longitude CHECK (longitude BETWEEN -180 AND 180),
  CONSTRAINT ck_media_assets_area CHECK (area_m2 > 0),
  CONSTRAINT ck_media_assets_bottom_height CHECK (bottom_height_m >= 0)
);

CREATE INDEX IF NOT EXISTS ix_media_assets_process_code ON media_assets (process_code);
CREATE INDEX IF NOT EXISTS ix_media_assets_media_type ON media_assets (media_type);
CREATE INDEX IF NOT EXISTS ix_media_assets_status ON media_assets (status);
CREATE INDEX IF NOT EXISTS ix_media_assets_district ON media_assets (district);
CREATE INDEX IF NOT EXISTS ix_media_assets_geom ON media_assets USING gist (geom);

CREATE TABLE IF NOT EXISTS activity_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  asset_id uuid REFERENCES media_assets(id) ON DELETE SET NULL,
  process_code varchar(32) NOT NULL,
  activity_type varchar(16) NOT NULL,
  message text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ck_activity_logs_type CHECK (
    activity_type IN ('cadastro', 'aprovacao', 'reprovacao', 'edicao', 'remocao')
  )
);

CREATE INDEX IF NOT EXISTS ix_activity_logs_asset_id ON activity_logs (asset_id);
CREATE INDEX IF NOT EXISTS ix_activity_logs_process_code ON activity_logs (process_code);
CREATE INDEX IF NOT EXISTS ix_activity_logs_activity_type ON activity_logs (activity_type);

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
