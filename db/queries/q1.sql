SELECT r.run_id,
       p.implementation,
       r.platform,
       (SELECT COUNT(*) FROM run_samples rs WHERE rs.run_id = r.run_id) AS n_samples,
       ROUND((julianday(r.finished_at) - julianday(r.started_at)) * 24 * 60, 1) AS minutes
FROM runs r
JOIN pipelines p ON r.pipeline_id = p.pipeline_id
ORDER BY r.started_at;
