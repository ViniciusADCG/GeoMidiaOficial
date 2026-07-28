INSERT INTO media_rules (
  media_type,
  name,
  base_radius_meters,
  area_threshold_m2,
  radius_above_threshold_meters,
  description
) VALUES
  ('outdoor', 'Outdoor', 80, NULL, NULL, 'Distancia minima para veiculos do tipo outdoor.'),
  ('front light', 'Front Light', 80, NULL, NULL, 'Distancia minima para veiculos front light.'),
  ('triface', 'Triface', 80, NULL, NULL, 'Distancia minima para veiculos triface.'),
  ('painel de led', 'Painel de LED', 250, 5, 1000, 'Acima de 5 m2 aplica-se o raio ampliado.'),
  ('empena', 'Empena', 80, NULL, NULL, 'Distancia minima para empenas.'),
  ('empena de led', 'Empena de LED', 1000, NULL, NULL, 'Distancia minima para empenas de LED.')
ON CONFLICT (media_type) DO NOTHING;

INSERT INTO media_assets (
  process_code,
  media_type,
  address,
  district,
  latitude,
  longitude,
  area_m2,
  width_m,
  bottom_height_m,
  top_height_m,
  radius_meters,
  status,
  justification,
  contact_name,
  contact_email,
  created_at
) VALUES
  (
    'PROC-2026-101',
    'outdoor',
    'Av. Afonso Pena, 2300',
    'Centro',
    -20.4612,
    -54.6145,
    27,
    9,
    5,
    NULL,
    80,
    'aprovado',
    'Atende as distancias regulamentares da Avenida Afonso Pena.',
    'Lucia Pereira',
    'lucia@outdoormidia.com.br',
    '2026-06-15T10:30:00Z'
  ),
  (
    'PROC-2026-102',
    'painel de led',
    'Av. Consul Assaf Trad, 1200',
    'Coronel Antonino',
    -20.395,
    -54.589,
    45,
    NULL,
    7,
    NULL,
    1000,
    'aprovado',
    'Grande porte de LED aprovado em via de trafego rapido.',
    'Fernando Silva',
    'fernando@ledtech.com.br',
    '2026-06-20T14:15:00Z'
  ),
  (
    'PROC-2026-103',
    'front light',
    'Rua Ceara, 1500',
    'Santa Fe',
    -20.448,
    -54.592,
    36,
    NULL,
    6,
    12,
    80,
    'análise',
    NULL,
    'Roberto Santos',
    'roberto@propaganda.com.br',
    '2026-06-28T09:00:00Z'
  ),
  (
    'PROC-2026-104',
    'empena de led',
    'Av. Mato Grosso, 3200',
    'Coophafe',
    -20.432,
    -54.601,
    120,
    NULL,
    15,
    NULL,
    1000,
    'exigência',
    NULL,
    'Amanda Costa',
    'amanda@empenasled.com.br',
    '2026-06-29T11:45:00Z'
  ),
  (
    'PROC-2026-105',
    'triface',
    'Av. Duque de Caxias, 800',
    'Vila Alba',
    -20.468,
    -54.642,
    32,
    NULL,
    6,
    11,
    80,
    'irregular',
    'Divergencia: raio de protecao municipal insuficiente.',
    'Marcos Oliveira',
    'marcos@signcomunicacao.com.br',
    '2026-06-25T16:20:00Z'
  )
ON CONFLICT (process_code) DO NOTHING;

INSERT INTO activity_logs (asset_id, process_code, activity_type, message, created_at)
SELECT id, process_code, 'cadastro', 'Carga inicial do processo ' || process_code || '.', created_at
FROM media_assets
WHERE process_code IN ('PROC-2026-101', 'PROC-2026-102', 'PROC-2026-103', 'PROC-2026-104', 'PROC-2026-105')
ON CONFLICT DO NOTHING;

INSERT INTO process_counters (year, last_value)
VALUES (2026, 105)
ON CONFLICT (year) DO UPDATE SET last_value = GREATEST(process_counters.last_value, EXCLUDED.last_value);
