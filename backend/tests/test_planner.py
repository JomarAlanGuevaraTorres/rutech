import unittest
from datetime import date
from pathlib import Path

from backend.planner import build_plan, calculate_priority, load_workbook


class PlannerTests(unittest.TestCase):
    def test_overdue_broken_commitment_is_p1(self):
        score, level = calculate_priority({
            "Tipo_gestion": "COBRANZA", "Estado_compromiso": "Incumplido",
            "Saldo_pendiente_S": 25000, "Dias_mora": 6,
            "Intentos_sin_respuesta": 3, "Resultado_ultimo_contacto": "No responde",
        }, date(2026, 9, 26))
        self.assertGreaterEqual(score, 70)
        self.assertEqual(level, "P1")

    def test_plan_respects_windows_and_priority(self):
        book = Path(__file__).parents[1] / "data" / "Base_sintetica_200_clientes_Piura.xlsx"
        clients, agencies = load_workbook(book)
        plan = build_plan(clients, agencies, "AG01", max_visits=12)
        self.assertTrue(plan["visitas"])
        priorities = [row["Prioridad"] for row in plan["visitas"]]
        self.assertIn("P1", priorities)
        for row in plan["visitas"]:
            self.assertGreaterEqual(row["Llegada_min"], row["Hora_desde"])
            self.assertLessEqual(row["Salida_min"], row["Hora_hasta"])


if __name__ == "__main__":
    unittest.main()
