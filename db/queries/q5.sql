SELECT o.run_id, r.folder || '/' || o.path AS file, o.sha256
FROM outputs o
JOIN runs r ON o.run_id = r.run_id
WHERE o.path = 'cohort.filtered.vcf.gz';
