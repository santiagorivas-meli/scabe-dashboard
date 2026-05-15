$env:PATH = "C:\Users\sarivas\AppData\Local\Google\Cloud SDK\google-cloud-sdk\bin;" + $env:PATH
$bq  = "C:\Users\sarivas\AppData\Local\Google\Cloud SDK\google-cloud-sdk\bin\bq.cmd"
$tmp = "C:\Users\sarivas\Downloads\scabe_server\data_tmp.json"
$out = "C:\Users\sarivas\Downloads\scabe_server\data.js"

$query = "SELECT c.CAMPAIGN_ID, c.MTC_NAME, c.MTC_SITE_ID AS site, c.MTC_STATUS AS status, ROUND(c.MTC_VALUE,1) AS disc_value, ROUND(c.MTC_CMG_BUDGET,0) AS budget_lc, ROUND(c.MTC_MIN_PAYMENT_AMOUNT,0) AS min_amount, FORMAT_DATETIME('%Y-%m-%d', c.MTC_START_DATE) AS start_date, FORMAT_DATETIME('%Y-%m-%d', c.MTC_END_DATE) AS end_date, ROUND(SUM(p.NMV_INCREMENTAL_USD),0) AS nmv_inc, ROUND(SUM(p.NMV_ATRIBUIDO_USD),0) AS nmv_att, ROUND(SUM(p.NMV_GENERADO_USD),0) AS nmv_gen, ROUND(SUM(p.INVESTMENT_USD),2) AS invest_usd, ROUND(SUM(p.VC_INCREMENTAL_USD),0) AS vc_inc, SUM(p.QTY_OPTIN) AS optins, SUM(p.QTY_ORDERS) AS orders, ROUND(SAFE_DIVIDE(SUM(p.NMV_INCREMENTAL_USD),SUM(p.INVESTMENT_USD)),2) AS roas, ROUND(SAFE_DIVIDE(SUM(p.VC_INCREMENTAL_USD),SUM(p.INVESTMENT_USD)),3) AS roi, ROUND(SAFE_DIVIDE(SUM(p.VC_INCREMENTAL_USD),SUM(p.NMV_INCREMENTAL_USD)),3) AS efficiency, ROUND(SAFE_DIVIDE(SUM(p.NMV_GENERADO_USD),SUM(p.NMV_ATRIBUIDO_USD)),3) AS gen_att_ratio FROM ``meli-bi-data.WHOWNER.BT_MKT_TOOLS_CAMPAIGN`` c LEFT JOIN ``meli-bi-data.WHOWNER.BT_MKP_BENEFITS_CAMPAIGNS_PERFORMANCE_COUPON_PREDICTION`` p ON CAST(c.CAMPAIGN_ID AS STRING) = p.CAMPAIGN_ID AND p.PHOTO_DATE >= DATE_SUB(CURRENT_DATE(), INTERVAL 60 DAY) WHERE c.MKT_CMG_ORIGIN = 'SCABE' GROUP BY 1,2,3,4,5,6,7,8,9 ORDER BY nmv_inc DESC NULLS LAST LIMIT 300"

Write-Host "$(Get-Date -Format 'HH:mm:ss') Querying BigQuery..."

# Write BQ output directly to file
& $bq query --use_legacy_sql=false --format=json --max_rows=300 $query 2>$null | Out-File -FilePath $tmp -Encoding utf8 -NoNewline

# Validate and wrap in JS variable using Python
$py = @"
import json, sys, re

with open(r'$tmp', encoding='utf-8') as f:
    raw = f.read()

# Extract JSON array
start = raw.find('[')
end   = raw.rfind(']') + 1
if start < 0:
    print('ERROR: no JSON array found')
    print(raw[:300])
    sys.exit(1)

data = json.loads(raw[start:end])
print(f'OK: {len(data)} rows')

from datetime import datetime
ts = datetime.now().strftime('%d/%m/%Y %H:%M:%S')

js = f'window.SCABE_DATA = ' + json.dumps({'rows': data, 'updated_at': ts}, ensure_ascii=False) + ';'

with open(r'$out', 'w', encoding='utf-8') as f:
    f.write(js)

print(f'data.js written ({len(js)} bytes)')
"@

python -c $py
