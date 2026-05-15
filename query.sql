SELECT
  c.CAMPAIGN_ID,
  c.MTC_NAME,
  c.MTC_SITE_ID                                                                    AS site,
  c.MTC_STATUS                                                                     AS status,
  ROUND(c.MTC_VALUE, 1)                                                            AS disc_value,
  ROUND(c.MTC_CMG_BUDGET, 0)                                                       AS budget_lc,
  ROUND(c.MTC_MIN_PAYMENT_AMOUNT, 0)                                               AS min_amount,
  FORMAT_DATETIME('%Y-%m-%d', c.MTC_START_DATE)                                    AS start_date,
  FORMAT_DATETIME('%Y-%m-%d', c.MTC_END_DATE)                                      AS end_date,
  ROUND(SUM(p.NMV_INCREMENTAL_USD), 0)                                             AS nmv_inc,
  ROUND(SUM(p.NMV_ATRIBUIDO_USD), 0)                                               AS nmv_att,
  ROUND(SUM(p.NMV_GENERADO_USD), 0)                                                AS nmv_gen,
  ROUND(SUM(p.INVESTMENT_USD), 2)                                                  AS invest_usd,
  ROUND(SUM(p.VC_INCREMENTAL_USD), 0)                                              AS vc_inc,
  SUM(p.QTY_OPTIN)                                                                 AS optins,
  SUM(p.QTY_ORDERS)                                                                AS orders,
  ROUND(SAFE_DIVIDE(SUM(p.NMV_INCREMENTAL_USD), SUM(p.INVESTMENT_USD)), 2)         AS roas,
  ROUND(SAFE_DIVIDE(SUM(p.VC_INCREMENTAL_USD),  SUM(p.INVESTMENT_USD)), 3)         AS roi,
  ROUND(SAFE_DIVIDE(SUM(p.VC_INCREMENTAL_USD),  SUM(p.NMV_INCREMENTAL_USD)), 3)   AS efficiency,
  ROUND(SAFE_DIVIDE(SUM(p.NMV_GENERADO_USD),    SUM(p.NMV_ATRIBUIDO_USD)), 3)     AS gen_att_ratio
FROM `meli-bi-data.WHOWNER.BT_MKT_TOOLS_CAMPAIGN` c
LEFT JOIN `meli-bi-data.WHOWNER.BT_MKP_BENEFITS_CAMPAIGNS_PERFORMANCE_COUPON_PREDICTION` p
  ON CAST(c.CAMPAIGN_ID AS STRING) = p.CAMPAIGN_ID
  AND p.PHOTO_DATE >= DATE_SUB(CURRENT_DATE(), INTERVAL 60 DAY)
WHERE c.MKT_CMG_ORIGIN = 'SCABE'
GROUP BY 1,2,3,4,5,6,7,8,9
ORDER BY nmv_inc DESC NULLS LAST
LIMIT 300
