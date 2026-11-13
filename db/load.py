#!/usr/bin/env python3
"""Load pipeline runs into the SQLite database."""
import json
import os
import sqlite3
import sys


def load_metadata(con, tsv_path):
    with open(tsv_path) as f:
        header = None
        for line in f:
            if line.startswith('#'):
                continue
            parts = line.rstrip('\n').split('\t')
            if header is None:
                header = parts
                continue
            row = dict(zip(header, parts))
            con.execute(
                "INSERT OR IGNORE INTO samples"
                " (sample_id, sex, population, family, father, mother, phenotype, is_synthetic_phenotype)"
                " VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                (row['sample_id'], row.get('sex'), row.get('population'),
                 row.get('family'), row.get('father'), row.get('mother'),
                 row.get('phenotype'), row.get('is_synthetic_phenotype')))


def load_run(con, folder):
    folder = os.path.abspath(folder)
    with open(os.path.join(folder, 'manifest.json')) as f:
        m = json.load(f)

    pipe = m['pipeline']
    run_id = pipe['run_id']

    if con.execute("SELECT 1 FROM runs WHERE run_id = ?", (run_id,)).fetchone():
        print(f"  skipping {os.path.basename(folder)}: {run_id} already loaded")
        return

    # pipeline (insert if new)
    name, version, impl = pipe['name'], pipe['version'], pipe['implementation']
    con.execute("INSERT OR IGNORE INTO pipelines (name, version, implementation) VALUES (?, ?, ?)",
                (name, version, impl))
    pid = con.execute("SELECT pipeline_id FROM pipelines WHERE name=? AND version=? AND implementation=?",
                      (name, version, impl)).fetchone()[0]

    # run
    plat = m.get('platform', {})
    params = m.get('params', {})
    con.execute(
        "INSERT INTO runs (run_id, pipeline_id, started_at, finished_at, exit_status,"
        " platform, executor, samplesheet, reference, region, folder)"
        " VALUES (?,?,?,?,?,?,?,?,?,?,?)",
        (run_id, pid, pipe.get('started_at'), pipe.get('finished_at'),
         pipe.get('exit_status'), plat.get('kind', ''), plat.get('executor', ''),
         params.get('samplesheet', ''), params.get('ref', ''),
         params.get('region', ''), folder))

    # samples not yet in the table (smoke samples)
    for s in m.get('samples', []):
        con.execute("INSERT OR IGNORE INTO samples"
                    " (sample_id, sex, population, family, father, mother, phenotype, is_synthetic_phenotype)"
                    " VALUES (?,NULL,NULL,NULL,NULL,NULL,NULL,NULL)", (s['sample_id'],))

    # run_samples
    for s in m.get('samples', []):
        con.execute("INSERT INTO run_samples (run_id, sample_id, condition, library_type)"
                    " VALUES (?,?,?,?)",
                    (run_id, s['sample_id'], s.get('condition'), s.get('library_type')))

    # variants
    with open(os.path.join(folder, 'variants.tsv')) as f:
        hdr = None
        for line in f:
            parts = line.rstrip('\n').split('\t')
            if hdr is None:
                hdr = parts
                continue
            row = dict(zip(hdr, parts))
            con.execute("INSERT INTO variants (run_id, chrom, pos, ref, alt, qual, filter)"
                        " VALUES (?,?,?,?,?,?,?)",
                        (run_id, row['chrom'], int(row['pos']), row['ref'],
                         row['alt'], float(row['qual']), row['filter']))

    # outputs
    for o in m.get('outputs', []):
        cksum = o.get('checksum', '')
        if cksum.startswith('sha256:'):
            cksum = cksum[7:]
        con.execute("INSERT INTO outputs (run_id, path, sha256) VALUES (?,?,?)",
                    (run_id, o['path'], cksum))

    print(f"  loaded {os.path.basename(folder)}: {run_id}")


def main():
    if len(sys.argv) < 4:
        print("Usage: load.py <db> <metadata.tsv> <run-folder> [run-folder ...]", file=sys.stderr)
        sys.exit(1)

    db, meta = sys.argv[1], sys.argv[2]
    folders = sys.argv[3:]

    con = sqlite3.connect(db)
    con.execute("PRAGMA foreign_keys = ON")

    with con:
        load_metadata(con, meta)

    for folder in folders:
        with con:
            load_run(con, folder)

    con.close()


if __name__ == "__main__":
    main()
