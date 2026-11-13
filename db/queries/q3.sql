SELECT v.run_id,
       COUNT(*) AS n_variants,
       SUM(v.filter = 'PASS') AS n_pass
FROM variants v
GROUP BY v.run_id;
