import os
from typing import List, Optional

from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from influxdb_client import InfluxDBClient

# -----------------------
# Configurações InfluxDB
# -----------------------
INFLUX_URL = "http://13.217.153.230:8086"
INFLUX_TOKEN = "qitLpKmQYK0RGpZlW4IqCvSxqZJiM4k-NbfsE3MHliWTfphGPJ9K3Hl7RM8BJx74CqKz94z4oV3zdENZbAalZA=="
INFLUX_ORG = "GarrafaInteligente"
INFLUX_BUCKET = "GarrafaInteligente"
MEASUREMENT = "water_bottle_state"

if not all([INFLUX_URL, INFLUX_TOKEN, INFLUX_ORG]):
    raise RuntimeError(
        "Faltam variáveis de ambiente do InfluxDB "
        "(INFLUX_URL, INFLUX_TOKEN, INFLUX_ORG, INFLUX_BUCKET)"
    )

client = InfluxDBClient(url=INFLUX_URL, token=INFLUX_TOKEN, org=INFLUX_ORG)
query_api = client.query_api()

# -----------------------
# FastAPI
# -----------------------
app = FastAPI(
    title="API Garrafa Inteligente",
    version="1.0.0",
)

# CORS liberado pro app Android poder chamar direto
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # em produção, restringe pro domínio do app
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


def _record_to_state_dict(rec) -> dict:
    """
    Converte um registro pivotado do Influx em dict pro JSON.
    """
    temp = rec.values.get("temperature_c")
    volume = rec.values.get("volume_ml")
    capacity = rec.values.get("capacity_ml")

    percent_full: Optional[float] = None
    if volume is not None and capacity not in (None, 0):
        percent_full = float(volume) / float(capacity)

    return {
        "bottleId": rec.values.get("bottleId"),
        "time": rec.values.get("_time").isoformat(),
        "temperature_c": temp,
        "temp_unit": rec.values.get("temp_unit"),
        "volume_ml": volume,
        "capacity_ml": capacity,
        "percent_full": percent_full,
    }


# -----------------------
# Endpoint: status atual
# -----------------------
@app.get("/api/garrafas/{bottle_id}/status")
def get_bottle_status(bottle_id: str):
    """
    Retorna o último estado conhecido da garrafa:
    volume atual, temperatura, capacidade, etc.
    """
    flux = f'''
from(bucket: "{INFLUX_BUCKET}")
  |> range(start: -7d)
  |> filter(fn: (r) => 
    r._measurement == "{MEASUREMENT}" and
    r.bottleId == "{bottle_id}"
  )
  |> pivot(
    rowKey: ["_time"],
    columnKey: ["_field"],
    valueColumn: "_value"
  )
  |> sort(columns: ["_time"], desc: true)
  |> limit(n: 1)
'''

    tables = query_api.query(flux)
    if not tables or not tables[0].records:
        raise HTTPException(status_code=404, detail="Nenhum dado encontrado para essa garrafa")

    rec = tables[0].records[0]
    return _record_to_state_dict(rec)


# -----------------------
# Endpoint: histórico
# -----------------------
@app.get("/api/garrafas/{bottle_id}/historico")
def get_bottle_history(
    bottle_id: str,
    horas: int = Query(24, ge=1, le=168, description="Quantas horas atrás buscar (1-168)")
) -> List[dict]:
    """
    Retorna o histórico de estado da garrafa nas últimas 'horas' horas.
    Cada ponto contém temperatura, volume e capacidade no instante.
    """
    flux = f'''
from(bucket: "{INFLUX_BUCKET}")
  |> range(start: -{horas}h)
  |> filter(fn: (r) => 
    r._measurement == "{MEASUREMENT}" and
    r.bottleId == "{bottle_id}"
  )
  |> pivot(
    rowKey: ["_time"],
    columnKey: ["_field"],
    valueColumn: "_value"
  )
  |> sort(columns: ["_time"])
'''

    tables = query_api.query(flux)
    pontos: List[dict] = []

    for table in tables:
        for rec in table.records:
            pontos.append(_record_to_state_dict(rec))

    if not pontos:
        raise HTTPException(status_code=404, detail="Nenhum dado encontrado no período solicitado")

    return pontos

@app.get("/api/garrafas/{bottle_id}/resumo-dia")
def get_bottle_daily_summary(
    bottle_id: str,
    horas: int = Query(24, ge=1, le=72, description="Janela de tempo em horas para o resumo"),
    meta_ml: Optional[float] = Query(
        None,
        description="Meta diária em ml (por ex.: 2000). Se informado, calcula progresso da meta."
    ),
):
    """
    Retorna um resumo do consumo no período (por padrão, últimas 24h):

    - volume inicial e final
    - total ingerido (ml)
    - número de refis
    - temperatura média
    - progresso em relação à meta (se informada)
    """
    flux = f'''
from(bucket: "{INFLUX_BUCKET}")
  |> range(start: -{horas}h)
  |> filter(fn: (r) =>
    r._measurement == "{MEASUREMENT}" and
    r.bottleId == "{bottle_id}"
  )
  |> pivot(
    rowKey: ["_time"],
    columnKey: ["_field"],
    valueColumn: "_value"
  )
  |> sort(columns: ["_time"])
'''

    tables = query_api.query(flux)

    pontos: List[dict] = []
    for table in tables:
        for rec in table.records:
            pontos.append(_record_to_state_dict(rec))

    if not pontos:
        raise HTTPException(status_code=404, detail="Nenhum dado encontrado no período solicitado")

    # Estatísticas básicas
    first = pontos[0]
    last = pontos[-1]

    initial_volume = float(first["volume_ml"]) if first["volume_ml"] is not None else None
    final_volume = float(last["volume_ml"]) if last["volume_ml"] is not None else None

    total_drank_ml = 0.0
    num_refills = 0
    temps: List[float] = []

    prev_vol: Optional[float] = None

    for p in pontos:
        vol = p["volume_ml"]
        temp = p["temperature_c"]

        if temp is not None:
            temps.append(float(temp))

        if vol is None:
            continue

        vol = float(vol)

        if prev_vol is not None:
            delta = vol - prev_vol
            if delta < 0:
                # volume diminuiu -> gole (consumo)
                total_drank_ml += -delta
            elif delta > 0:
                # volume aumentou -> consideramos refil
                num_refills += 1

        prev_vol = vol

    avg_temp = sum(temps) / len(temps) if temps else None

    goal_progress = None
    if meta_ml is not None and meta_ml > 0:
        goal_progress = total_drank_ml / meta_ml

    return {
        "bottleId": bottle_id,
        "period_hours": horas,
        "start_time": first["time"],
        "end_time": last["time"],
        "initial_volume_ml": initial_volume,
        "final_volume_ml": final_volume,
        "total_drank_ml": total_drank_ml,
        "num_refills": num_refills,
        "avg_temperature_c": avg_temp,
        "goal_ml": meta_ml,
        "goal_progress": goal_progress,   # 0.0–1.0 (ex: 0.75 = 75% da meta)
    }

# Endpoint simples só pra health-check
@app.get("/api/health")
def health():
    return {"status": "ok"}
