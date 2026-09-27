from __future__ import annotations

from dataclasses import dataclass
from datetime import date, datetime, time, timedelta
from math import asin, cos, radians, sin, sqrt
from pathlib import Path
from typing import Any, Iterable

import pandas as pd
import httpx


PRIORITY_ORDER = {"P1": 1, "P2": 2, "P3": 3, "P4": 4}


def _yes(value: Any) -> bool:
    return str(value).strip().lower() in {"si", "sí", "true", "1"}


def calculate_priority(row: dict[str, Any], cutoff: date) -> tuple[int, str]:
    """Replica las reglas documentadas en el Excel y devuelve puntaje y nivel."""
    management = str(row.get("Tipo_gestion", "")).upper()
    score = 0
    if management == "COMERCIAL":
        score += 40 if _yes(row.get("Cierre_o_pago_hoy")) else 0
        score += 15 if row.get("Tipo_cliente") == "Recurrente" else 0
        score += {"Alto": 25, "Medio": 12}.get(str(row.get("Nivel_interes")), 0)
        amount = float(row.get("Monto_referencial_S") or 0)
        score += 20 if amount >= 30000 else 12 if amount >= 10000 else 6 if amount >= 5000 else 0
        management_date = pd.to_datetime(row.get("Fecha_gestion"), errors="coerce")
        if not pd.isna(management_date) and management_date.date() <= cutoff + timedelta(days=1):
            score += 25
        score += 15 if _yes(row.get("Visita_confirmada")) else 0
        score -= 10 if row.get("Resultado_ultimo_contacto") == "No responde" else 0
    else:
        score += 40 if row.get("Estado_compromiso") == "Incumplido" else 0
        promise_date = pd.to_datetime(row.get("Fecha_compromiso"), errors="coerce")
        if _yes(row.get("Compromiso_pago")) and not pd.isna(promise_date) and promise_date.date() == cutoff:
            score += 35
        balance = float(row.get("Saldo_pendiente_S") or 0)
        score += 25 if balance >= 20000 else 18 if balance >= 10000 else 10 if balance >= 5000 else 0
        arrears = int(row.get("Dias_mora") or 0)
        score += 25 if arrears >= 15 else 20 if arrears >= 6 else 10 if arrears >= 3 else 0
        attempts = int(row.get("Intentos_sin_respuesta") or 0)
        score += 20 if attempts >= 3 else 10 if attempts >= 2 else 0
        score -= 10 if row.get("Resultado_ultimo_contacto") == "Respondió" else 0
        if row.get("Estado_compromiso") == "Vigente" and not pd.isna(promise_date) and promise_date.date() > cutoff:
            score -= 10
    level = "P1" if score >= 70 else "P2" if score >= 50 else "P3" if score >= 30 else "P4"
    return score, level


def load_workbook(path: str | Path) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    book = Path(path)
    clients = pd.read_excel(book, sheet_name="Clientes")
    agencies = pd.read_excel(book, sheet_name="Agencias")
    for frame in (clients, agencies):
        frame.columns = [str(column).strip() for column in frame.columns]
    cutoff = pd.to_datetime(clients["Fecha_gestion"], errors="coerce").min().date()
    records: list[dict[str, Any]] = []
    for source in clients.to_dict(orient="records"):
        row = {key: (None if pd.isna(value) else value) for key, value in source.items()}
        score, level = calculate_priority(row, cutoff)
        row["Puntaje_prioridad"] = score
        row["Prioridad"] = level
        for key in ("Fecha_gestion", "Fecha_compromiso"):
            value = row.get(key)
            if value is not None:
                row[key] = pd.to_datetime(value).date().isoformat()
        for key in ("Hora_desde", "Hora_hasta"):
            value = row.get(key)
            if value is not None:
                row[key] = _minutes(value)
        records.append(row)
    agency_records = [
        {key: (None if pd.isna(value) else value) for key, value in row.items()}
        for row in agencies.to_dict(orient="records")
    ]
    return records, agency_records


def _minutes(value: Any) -> int:
    if isinstance(value, time):
        return value.hour * 60 + value.minute
    if isinstance(value, (int, float)):
        return round(float(value) * 24 * 60) if float(value) <= 1 else round(float(value))
    parsed = pd.to_datetime(str(value), errors="coerce")
    return 8 * 60 if pd.isna(parsed) else parsed.hour * 60 + parsed.minute


def haversine_km(a: tuple[float, float], b: tuple[float, float]) -> float:
    lat1, lon1, lat2, lon2 = map(radians, (a[0], a[1], b[0], b[1]))
    dlat, dlon = lat2 - lat1, lon2 - lon1
    value = sin(dlat / 2) ** 2 + cos(lat1) * cos(lat2) * sin(dlon / 2) ** 2
    return 6371.0 * 2 * asin(sqrt(value))


def _travel_minutes(a: tuple[float, float], b: tuple[float, float], speed_kmh: float = 25.0) -> int:
    return max(1, round((haversine_km(a, b) / speed_kmh) * 60))


OSRM_BASE_URL = "https://router.project-osrm.org"


def _osrm_coordinates(points: list[tuple[float, float]]) -> str:
    """OSRM recibe longitud,latitud aunque internamente usemos latitud,longitud."""
    return ";".join(f"{longitude:.6f},{latitude:.6f}" for latitude, longitude in points)


def road_time_matrix(points: list[tuple[float, float]]) -> list[list[int]]:
    """Obtiene minutos de conducción por las calles reales para cada par de puntos."""
    url = f"{OSRM_BASE_URL}/table/v1/driving/{_osrm_coordinates(points)}"
    response = httpx.get(
        url,
        params={"annotations": "duration"},
        headers={"User-Agent": "RUTECH-academic-prototype/2.1"},
        timeout=20,
    )
    response.raise_for_status()
    payload = response.json()
    if payload.get("code") != "Ok" or not payload.get("durations"):
        raise ValueError(f"OSRM no pudo calcular la matriz vial: {payload.get('message', 'sin detalle')}")
    matrix: list[list[int]] = []
    for row in payload["durations"]:
        if any(value is None for value in row):
            raise ValueError("OSRM no encontró conexión vial entre todos los puntos")
        matrix.append([max(0, round(float(value) / 60)) for value in row])
    return matrix


def road_route(points: list[tuple[float, float]]) -> dict[str, Any]:
    """Devuelve la polilínea GeoJSON que sigue calles, además de distancia y duración."""
    url = f"{OSRM_BASE_URL}/route/v1/driving/{_osrm_coordinates(points)}"
    response = httpx.get(
        url,
        params={"overview": "full", "geometries": "geojson", "steps": "false"},
        headers={"User-Agent": "RUTECH-academic-prototype/2.1"},
        timeout=20,
    )
    response.raise_for_status()
    payload = response.json()
    if payload.get("code") != "Ok" or not payload.get("routes"):
        raise ValueError(f"OSRM no pudo construir la ruta vial: {payload.get('message', 'sin detalle')}")
    route = payload["routes"][0]
    geometry = [
        {"latitud": float(latitude), "longitud": float(longitude)}
        for longitude, latitude in route["geometry"]["coordinates"]
    ]
    return {
        "geometria_ruta": geometry,
        "distancia_vial_km": round(float(route["distance"]) / 1000, 2),
        "duracion_vial_min": round(float(route["duration"]) / 60),
    }


def select_candidates(clients: Iterable[dict[str, Any]], agency_code: str, max_visits: int) -> list[dict[str, Any]]:
    selected = [row for row in clients if row.get("Codigo_agencia") == agency_code]
    selected.sort(key=lambda row: (PRIORITY_ORDER.get(str(row.get("Prioridad")), 9), -int(row.get("Puntaje_prioridad") or 0), int(row.get("Hora_hasta") or 1440)))
    return selected[:max_visits]


def assign_clusters(clients: list[dict[str, Any]], advisors: int) -> list[list[dict[str, Any]]]:
    """Agrupa geográficamente sin alterar la prioridad previamente calculada."""
    if advisors <= 1 or len(clients) <= 1:
        return [clients]
    from sklearn.cluster import KMeans

    count = min(advisors, len(clients))
    coordinates = [[float(row["Latitud"]), float(row["Longitud"])] for row in clients]
    labels = KMeans(n_clusters=count, init="k-means++", random_state=20260926, n_init=10).fit_predict(coordinates)
    groups = [[] for _ in range(count)]
    for row, label in zip(clients, labels):
        copy = dict(row)
        copy["Cluster"] = int(label) + 1
        groups[int(label)].append(copy)
    return groups


@dataclass
class Stop:
    client: dict[str, Any]
    arrival: int
    departure: int
    travel_minutes: int


def _greedy_vrptw(clients: list[dict[str, Any]], depot: tuple[float, float], start: int, end: int) -> tuple[list[Stop], list[str]]:
    current, clock = depot, start
    pending = list(clients)
    route: list[Stop] = []
    omitted: list[str] = []
    while pending:
        feasible: list[tuple[tuple[int, int, int], dict[str, Any], int, int]] = []
        for row in pending:
            coords = (float(row["Latitud"]), float(row["Longitud"]))
            travel = _travel_minutes(current, coords)
            arrival = max(clock + travel, int(row.get("Hora_desde") or start))
            departure = arrival + int(row.get("Duracion_visita_min") or 30)
            if departure <= min(end, int(row.get("Hora_hasta") or end)):
                key = (PRIORITY_ORDER.get(str(row.get("Prioridad")), 9), int(row.get("Hora_hasta") or end), travel)
                feasible.append((key, row, arrival, travel))
        if not feasible:
            omitted.extend(str(row.get("ID_cliente")) for row in pending)
            break
        _, chosen, arrival, travel = min(feasible, key=lambda item: item[0])
        departure = arrival + int(chosen.get("Duracion_visita_min") or 30)
        route.append(Stop(chosen, arrival, departure, travel))
        current = (float(chosen["Latitud"]), float(chosen["Longitud"]))
        clock = departure
        pending.remove(chosen)
    return route, omitted


def _ortools_vrptw(
    clients: list[dict[str, Any]],
    depot: tuple[float, float],
    start: int,
    end: int,
    travel_matrix: list[list[int]] | None = None,
) -> tuple[list[Stop], list[str]] | None:
    """Resuelve el VRPTW; devuelve None cuando OR-Tools no está instalado."""
    try:
        from ortools.constraint_solver import pywrapcp, routing_enums_pb2
    except ImportError:
        return None
    points = [depot] + [(float(row["Latitud"]), float(row["Longitud"])) for row in clients]
    manager = pywrapcp.RoutingIndexManager(len(points), 1, 0)
    routing = pywrapcp.RoutingModel(manager)

    def transit(from_index: int, to_index: int) -> int:
        origin, destination = manager.IndexToNode(from_index), manager.IndexToNode(to_index)
        service = 0 if origin == 0 else int(clients[origin - 1].get("Duracion_visita_min") or 30)
        travel = travel_matrix[origin][destination] if travel_matrix else _travel_minutes(points[origin], points[destination])
        return service + travel

    callback = routing.RegisterTransitCallback(transit)
    routing.SetArcCostEvaluatorOfAllVehicles(callback)
    routing.AddDimension(callback, 180, end + 180, False, "Time")
    dimension = routing.GetDimensionOrDie("Time")
    dimension.CumulVar(routing.Start(0)).SetRange(start, start)
    dimension.CumulVar(routing.End(0)).SetRange(start, end)
    for node, row in enumerate(clients, start=1):
        index = manager.NodeToIndex(node)
        service = int(row.get("Duracion_visita_min") or 30)
        window_start = int(row.get("Hora_desde") or start)
        window_end = int(row.get("Hora_hasta") or end) - service
        dimension.CumulVar(index).SetRange(window_start, window_end)
        penalty = {"P1": 10_000_000, "P2": 1_000_000, "P3": 100_000, "P4": 10_000}.get(str(row.get("Prioridad")), 1_000)
        routing.AddDisjunction([index], penalty)
    parameters = pywrapcp.DefaultRoutingSearchParameters()
    parameters.first_solution_strategy = routing_enums_pb2.FirstSolutionStrategy.PATH_CHEAPEST_ARC
    parameters.local_search_metaheuristic = routing_enums_pb2.LocalSearchMetaheuristic.GUIDED_LOCAL_SEARCH
    parameters.time_limit.seconds = 5
    solution = routing.SolveWithParameters(parameters)
    if solution is None:
        return [], [str(row.get("ID_cliente")) for row in clients]
    route: list[Stop] = []
    visited: set[int] = set()
    index = routing.Start(0)
    previous_node = 0
    while not routing.IsEnd(index):
        next_index = solution.Value(routing.NextVar(index))
        if routing.IsEnd(next_index):
            break
        node = manager.IndexToNode(next_index)
        row = clients[node - 1]
        arrival = solution.Value(dimension.CumulVar(next_index))
        travel = travel_matrix[previous_node][node] if travel_matrix else _travel_minutes(points[previous_node], points[node])
        departure = arrival + int(row.get("Duracion_visita_min") or 30)
        route.append(Stop(row, arrival, departure, travel))
        visited.add(node)
        previous_node = node
        index = next_index
    omitted = [str(row.get("ID_cliente")) for node, row in enumerate(clients, start=1) if node not in visited]
    return route, omitted


def build_plan(
    clients: list[dict[str, Any]],
    agencies: list[dict[str, Any]],
    agency_code: str,
    max_visits: int = 15,
    start: int = 8 * 60,
    end: int = 18 * 60,
    use_road_network: bool = False,
) -> dict[str, Any]:
    agency = next((row for row in agencies if row.get("Codigo") == agency_code), None)
    if agency is None:
        raise ValueError(f"Agencia desconocida: {agency_code}")
    candidates = select_candidates(clients, agency_code, max_visits)
    depot = (float(agency["Latitud"]), float(agency["Longitud"]))
    candidate_points = [depot] + [(float(row["Latitud"]), float(row["Longitud"])) for row in candidates]
    travel_matrix = None
    road_warning = None
    if use_road_network:
        try:
            travel_matrix = road_time_matrix(candidate_points)
        except (httpx.HTTPError, ValueError) as exc:
            road_warning = f"No se pudo consultar la red vial; se usó estimación temporal: {exc}"
    optimized = _ortools_vrptw(candidates, depot, start, end, travel_matrix)
    stops, omitted = optimized if optimized is not None else _greedy_vrptw(candidates, depot, start, end)
    distance = 0.0
    previous = depot
    payload = []
    for sequence, stop in enumerate(stops, start=1):
        coords = (float(stop.client["Latitud"]), float(stop.client["Longitud"]))
        distance += haversine_km(previous, coords)
        previous = coords
        payload.append({**stop.client, "Orden": sequence, "Llegada_min": stop.arrival, "Salida_min": stop.departure, "Traslado_min": stop.travel_minutes})
    if stops:
        distance += haversine_km(previous, depot)
    result = {
        "metodo": "VRPTW con OR-Tools" if optimized is not None else "VRPTW heurístico con prioridad lexicográfica",
        "agencia": agency,
        "visitas": payload,
        "omitidos": omitted,
        "distancia_estimada_km": round(distance, 2),
        "inicio_min": start,
        "fin_min": stops[-1].departure if stops else start,
        "red_vial": False,
    }
    if stops and use_road_network:
        ordered_points = [depot] + [
            (float(stop.client["Latitud"]), float(stop.client["Longitud"])) for stop in stops
        ] + [depot]
        try:
            road_data = road_route(ordered_points)
            result.update(road_data)
            result["distancia_estimada_km"] = road_data["distancia_vial_km"]
            result["red_vial"] = True
        except (httpx.HTTPError, ValueError) as exc:
            road_warning = f"No se pudo obtener la geometría vial; se muestran segmentos directos: {exc}"
    if road_warning:
        result["aviso_ruteo"] = road_warning
    return result


def build_multi_plan(clients: list[dict[str, Any]], agencies: list[dict[str, Any]], agency_code: str, advisors: int, max_visits: int = 15, start: int = 8 * 60, end: int = 18 * 60) -> dict[str, Any]:
    agency = next((row for row in agencies if row.get("Codigo") == agency_code), None)
    if agency is None:
        raise ValueError(f"Agencia desconocida: {agency_code}")
    candidates = select_candidates(clients, agency_code, max_visits * advisors)
    routes = []
    for number, group in enumerate(assign_clusters(candidates, advisors), start=1):
        plan = build_plan(group, agencies, agency_code, len(group), start, end, use_road_network=True)
        plan["asesor"] = number
        routes.append(plan)
    return {"agencia": agency, "asesores": len(routes), "rutas": routes, "criterio_agrupacion": "K-means++ después de priorizar"}
