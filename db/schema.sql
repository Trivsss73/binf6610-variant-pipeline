CREATE TABLE pipelines (
    pipeline_id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    version TEXT NOT NULL,
    implementation TEXT NOT NULL,
    UNIQUE (name, version, implementation)
);

CREATE TABLE runs (
    run_id TEXT PRIMARY KEY,
    pipeline_id INTEGER NOT NULL REFERENCES pipelines(pipeline_id),
    started_at TEXT,
    finished_at TEXT,
    exit_status TEXT,
    platform TEXT,
    executor TEXT,
    samplesheet TEXT,
    reference TEXT,
    region TEXT,
    folder TEXT
);

CREATE TABLE samples (
    sample_id TEXT PRIMARY KEY,
    sex TEXT,
    population TEXT,
    family TEXT,
    father TEXT,
    mother TEXT,
    phenotype TEXT,
    is_synthetic_phenotype TEXT
);

CREATE TABLE run_samples (
    run_id TEXT NOT NULL REFERENCES runs(run_id),
    sample_id TEXT NOT NULL REFERENCES samples(sample_id),
    condition TEXT,
    library_type TEXT,
    PRIMARY KEY (run_id, sample_id)
);

CREATE TABLE variants (
    run_id TEXT NOT NULL REFERENCES runs(run_id),
    chrom TEXT,
    pos INTEGER,
    ref TEXT,
    alt TEXT,
    qual REAL,
    filter TEXT
);

CREATE TABLE outputs (
    run_id TEXT NOT NULL REFERENCES runs(run_id),
    path TEXT,
    sha256 TEXT
);
