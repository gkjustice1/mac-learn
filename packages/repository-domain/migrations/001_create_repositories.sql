CREATE TABLE IF NOT EXISTS repositories (
  id text NOT NULL,
  tenant_id text NOT NULL,
  name varchar(100) NOT NULL,
  display_name varchar(160) NOT NULL,
  description varchar(2000),
  repository_type varchar(32) NOT NULL,
  status varchar(16) NOT NULL,
  visibility varchar(16) NOT NULL,
  classification varchar(16) NOT NULL,
  owner_user_id text NOT NULL,
  owner_display_name text NOT NULL,
  created_at timestamptz NOT NULL,
  updated_at timestamptz NOT NULL,
  archived_at timestamptz,
  PRIMARY KEY (tenant_id, id),
  CONSTRAINT repositories_tenant_name_unique UNIQUE (tenant_id, name),
  CONSTRAINT repositories_status_check CHECK (status IN ('ACTIVE', 'ARCHIVED')),
  CONSTRAINT repositories_type_check CHECK (repository_type IN (
    'MASTER_BLUEPRINT', 'ENGINEERING', 'CURRICULUM', 'AI',
    'RESEARCH', 'GOVERNANCE', 'OPERATIONS', 'COMMERCIAL'
  )),
  CONSTRAINT repositories_visibility_check CHECK (visibility IN ('PRIVATE', 'TENANT', 'ENTERPRISE')),
  CONSTRAINT repositories_classification_check CHECK (classification IN ('PUBLIC', 'INTERNAL', 'CONFIDENTIAL', 'RESTRICTED')),
  CONSTRAINT repositories_archive_state_check CHECK (
    (status = 'ACTIVE' AND archived_at IS NULL)
    OR (status = 'ARCHIVED' AND archived_at IS NOT NULL)
  )
);

CREATE INDEX IF NOT EXISTS repositories_tenant_status_idx
  ON repositories (tenant_id, status);

CREATE INDEX IF NOT EXISTS repositories_tenant_type_idx
  ON repositories (tenant_id, repository_type);
