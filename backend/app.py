from pathlib import Path

from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware

from .planner import build_multi_plan, build_plan, load_workbook


ROOT = Path(__file__).resolve().parent
DATA_FILE = ROOT / "data" / "Base_sintetica_200_clientes_Piura.xlsx"
app = FastAPI(title="RUTECH API", version="2.0.0")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])


@app.get("/salud")
def health() -> dict[str, str]:
    return {"estado": "ok", "base": DATA_FILE.name}


@app.get("/agencias")
def agencies() -> list[dict]:
    _, data = load_workbook(DATA_FILE)
    return data


@app.get("/clientes")
def clients(agencia: str | None = None, prioridad: str | None = None) -> list[dict]:
    data, _ = load_workbook(DATA_FILE)
    if agencia:
        data = [row for row in data if row.get("Codigo_agencia") == agencia]
    if prioridad:
        data = [row for row in data if row.get("Prioridad") == prioridad.upper()]
    return data


@app.get("/planificar")
def plan(
    agencia: str = Query(default="AG01"),
    max_visitas: int = Query(default=15, ge=1, le=40),
    inicio_min: int = Query(default=480, ge=0, le=1439),
    fin_min: int = Query(default=1080, ge=1, le=1440),
    asesores: int = Query(default=1, ge=1, le=5),
) -> dict:
    try:
        data, agency_data = load_workbook(DATA_FILE)
        if asesores > 1:
            return build_multi_plan(data, agency_data, agencia.upper(), asesores, max_visitas, inicio_min, fin_min)
        return build_plan(data, agency_data, agencia.upper(), max_visitas, inicio_min, fin_min)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc

