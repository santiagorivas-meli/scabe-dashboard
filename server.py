"""
Smart Coupons SCABE Dashboard — servidor local con datos en vivo de BigQuery.
Uso: python server.py
     Abrir: http://localhost:5050
"""
import subprocess, json, threading, time, re
from datetime import datetime, date
from flask import Flask, jsonify, send_from_directory
import os

app = Flask(__name__, static_folder='.')

BQ = r"C:\Users\sarivas\AppData\Local\Google\Cloud SDK\google-cloud-sdk\bin\bq.cmd"

QUERY = """
SELECT
  c.CAMPAIGN_ID,
  c.MTC_NAME,
  c.MTC_SITE_ID                                                                    AS site,
  c.MTC_STATUS                                                                     AS status,
  ROUND(c.MTC_VALUE, 1)                                                            AS disc_value,
  ROUND(c.MTC_CMG_BUDGET, 0)                                                       AS budget_lc,
  ROUND(c.MTC_CMG_CAP, 0)                                                          AS cap_lc,
  ROUND(c.MTC_MIN_PAYMENT_AMOUNT, 0)                                               AS min_amount,
  FORMAT_DATETIME('%Y-%m-%d', c.MTC_START_DATE)                                    AS start_date,
  FORMAT_DATETIME('%Y-%m-%d', c.MTC_END_DATE)                                      AS end_date,
  c.MKT_CMG_BENEFIT_TYPE                                                           AS benefit_type,
  c.MTC_CMG_MODE                                                                   AS mode,
  -- Performance from coupon prediction table
  ROUND(SUM(p.NMV_INCREMENTAL_USD), 0)                                             AS nmv_inc,
  ROUND(SUM(p.NMV_ATRIBUIDO_USD), 0)                                               AS nmv_att,
  ROUND(SUM(p.NMV_GENERADO_USD), 0)                                                AS nmv_gen,
  ROUND(SUM(p.INVESTMENT_USD), 2)                                                  AS invest_usd,
  ROUND(SUM(p.VC_INCREMENTAL_USD), 0)                                              AS vc_inc,
  SUM(p.QTY_OPTIN)                                                                 AS optins,
  SUM(p.QTY_ORDERS)                                                                AS orders,
  -- KPIs calculados
  ROUND(SAFE_DIVIDE(SUM(p.NMV_INCREMENTAL_USD), SUM(p.INVESTMENT_USD)), 2)         AS roas,
  ROUND(SAFE_DIVIDE(SUM(p.VC_INCREMENTAL_USD),  SUM(p.INVESTMENT_USD)), 3)         AS roi,
  ROUND(SAFE_DIVIDE(SUM(p.VC_INCREMENTAL_USD),  SUM(p.NMV_INCREMENTAL_USD)), 3)   AS efficiency,
  ROUND(SAFE_DIVIDE(SUM(p.NMV_GENERADO_USD),    SUM(p.NMV_ATRIBUIDO_USD)), 3)     AS gen_att_ratio,
  ROUND(SAFE_DIVIDE(SUM(p.NMV_INCREMENTAL_USD), SUM(p.NMV_ATRIBUIDO_USD)), 3)     AS inc_att_ratio
FROM `meli-bi-data.WHOWNER.BT_MKT_TOOLS_CAMPAIGN` c
LEFT JOIN `meli-bi-data.WHOWNER.BT_MKP_BENEFITS_CAMPAIGNS_PERFORMANCE_COUPON_PREDICTION` p
  ON CAST(c.CAMPAIGN_ID AS STRING) = p.CAMPAIGN_ID
  AND p.PHOTO_DATE >= DATE_SUB(CURRENT_DATE(), INTERVAL 60 DAY)
WHERE c.MKT_CMG_ORIGIN = 'SCABE'
GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12
ORDER BY nmv_inc DESC NULLS LAST
LIMIT 300
"""

# Cache
_cache = {"data": [], "updated_at": None, "loading": False, "error": None}
_lock = threading.Lock()

def run_bq():
    env = os.environ.copy()
    env["PATH"] = r"C:\Users\sarivas\AppData\Local\Google\Cloud SDK\google-cloud-sdk\bin;" + env.get("PATH", "")
    result = subprocess.run(
        [BQ, "query", "--use_legacy_sql=false", "--format=json", "--max_rows=300", QUERY],
        capture_output=True, text=True, encoding="utf-8", timeout=120, env=env
    )
    raw = result.stdout + result.stderr
    start = raw.find("[")
    end   = raw.rfind("]") + 1
    if start < 0:
        raise ValueError(f"No JSON in BQ output: {raw[:300]}")
    return json.loads(raw[start:end])

def refresh():
    with _lock:
        if _cache["loading"]:
            return
        _cache["loading"] = True
    try:
        rows = run_bq()
        with _lock:
            _cache["data"]       = rows
            _cache["updated_at"] = datetime.now().strftime("%d/%m/%Y %H:%M:%S")
            _cache["error"]      = None
    except Exception as e:
        with _lock:
            _cache["error"] = str(e)
    finally:
        with _lock:
            _cache["loading"] = False

def auto_refresh_loop(interval_sec=300):
    while True:
        refresh()
        time.sleep(interval_sec)

@app.route("/api/data")
def api_data():
    with _lock:
        return jsonify({
            "rows":       _cache["data"],
            "updated_at": _cache["updated_at"],
            "loading":    _cache["loading"],
            "error":      _cache["error"],
            "count":      len(_cache["data"])
        })

@app.route("/api/refresh", methods=["POST"])
def api_refresh():
    t = threading.Thread(target=refresh, daemon=True)
    t.start()
    return jsonify({"status": "refreshing"})

@app.route("/")
def index():
    return send_from_directory(".", "index.html")

if __name__ == "__main__":
    print("Cargando datos iniciales de BigQuery...")
    t = threading.Thread(target=auto_refresh_loop, args=(300,), daemon=True)
    t.start()
    print("Servidor corriendo en http://localhost:5050")
    app.run(host="0.0.0.0", port=5050, debug=False)
