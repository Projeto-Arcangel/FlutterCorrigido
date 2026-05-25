# -*- coding: utf-8 -*-
"""
seed_enem.py
============
Busca questoes da API publica do ENEM (https://api.enem.dev) e as insere no
Firestore nas colecoes Phase e Questions, no mesmo schema usado pelo app.

LIMITE DE GRAVACOES: MAX_WRITES = 200
    Cada Phase = 1 gravacao. Cada Question = 1 gravacao.
    O script para automaticamente ao atingir o limite.

Uso:
    cd scripts
    python seed_enem.py

Pre-requisitos:
    pip install firebase-admin requests
    Arquivo serviceAccountKey.json na pasta scripts/
"""

import os
import sys
import time

# Forca saida UTF-8 no Windows (evita UnicodeEncodeError com cp1252)
if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')

import requests
import firebase_admin
from firebase_admin import credentials, firestore

# ─────────────────────────────────────────────────────────────────────────────
# CONFIGURACAO
# ─────────────────────────────────────────────────────────────────────────────

# Limite total de gravacoes no Firestore (protege o plano pago)
MAX_WRITES = 200

# Anos a importar
YEARS = [2023]

# Disciplinas
DISCIPLINES = [
    {"value": "ciencias-humanas",  "label": "Ciencias Humanas"},
    {"value": "ciencias-natureza", "label": "Ciencias da Natureza"},
    {"value": "linguagens",        "label": "Linguagens"},
    {"value": "matematica",        "label": "Matematica"},
]

# Questoes por fase
# 1 Phase + 5 Questions = 6 gravacoes por fase
# 200 gravacoes / 6 = ~33 fases maximas
QUESTIONS_PER_PHASE = 5

# Questoes buscadas da API por lote (disciplina/ano)
# 4 disciplinas x 30 questoes = 120 questoes -> 24 fases -> 144 gravacoes
QUESTIONS_PER_BATCH = 30

API_BASE = "https://api.enem.dev/v1"

# ─────────────────────────────────────────────────────────────────────────────
# INICIALIZACAO DO FIREBASE
# ─────────────────────────────────────────────────────────────────────────────

script_dir = os.path.dirname(os.path.abspath(__file__))
key_path = os.path.join(script_dir, "serviceAccountKey.json")

if not os.path.exists(key_path):
    print("ERRO: serviceAccountKey.json nao encontrado em scripts/")
    print("Faca o download em:")
    print("  Console Firebase -> Configuracoes -> Contas de servico -> Gerar nova chave")
    sys.exit(1)

cred = credentials.Certificate(key_path)
firebase_admin.initialize_app(cred, {"projectId": "arcangel-4c066"})
db = firestore.client()

# ─────────────────────────────────────────────────────────────────────────────
# CONTADOR DE GRAVACOES
# ─────────────────────────────────────────────────────────────────────────────

write_count = 0

def safe_write(ref, data: dict) -> bool:
    """Grava no Firestore somente se o limite nao foi atingido."""
    global write_count
    if write_count >= MAX_WRITES:
        return False
    ref.set(data)
    write_count += 1
    return True

# ─────────────────────────────────────────────────────────────────────────────
# FUNCOES DE APOIO
# ─────────────────────────────────────────────────────────────────────────────

def fetch_questions(year: int, discipline: str, limit: int) -> list:
    """Busca questoes da API do ENEM."""
    url = f"{API_BASE}/exams/{year}/questions"
    params = {"discipline": discipline, "limit": limit, "offset": 0}
    try:
        resp = requests.get(url, params=params, timeout=30)
        resp.raise_for_status()
        data = resp.json()
        return data.get("questions", [])
    except requests.RequestException as e:
        print(f"  [AVISO] Erro ao buscar {discipline}/{year}: {e}")
        return []


def map_question(q: dict, phase_ref) -> dict:
    """Converte uma questao da API do ENEM para o schema do Firestore."""
    alternatives = q.get("alternatives", [])
    if not alternatives:
        return None

    options = [alt.get("text", "").strip() for alt in alternatives]
    correct_index = next(
        (i for i, alt in enumerate(alternatives) if alt.get("isCorrect")),
        0,
    )

    text = (q.get("alternativesIntroduction") or q.get("title") or "").strip()
    if not text:
        return None

    context = (q.get("context") or "").strip()
    explanation = (
        context[:800] if context
        else "Questao {} -- ENEM {}".format(q.get("index", ""), q.get("year", ""))
    )

    files = q.get("files") or []
    image_url = None
    if files:
        first = files[0] if isinstance(files[0], str) else files[0].get("url", "")
        if first and "broken-image" not in str(first):
            image_url = first

    doc = {
        "text": text,
        "options": options,
        "correct_answer": correct_index,
        "explanation": explanation,
        "type": 0,  # multipleChoice
        "phase_ref": phase_ref,
    }
    if image_url:
        doc["image_url"] = image_url

    return doc


def chunk(lst: list, size: int) -> list:
    """Divide uma lista em sublistas de tamanho `size`."""
    return [lst[i: i + size] for i in range(0, len(lst), size)]


def estimate_writes() -> int:
    """Calcula estimativa de gravacoes sem tocar o Firestore."""
    total = 0
    for disc in DISCIPLINES:
        for year in YEARS:
            q_count = QUESTIONS_PER_BATCH
            groups = (q_count + QUESTIONS_PER_PHASE - 1) // QUESTIONS_PER_PHASE
            for g in range(groups):
                size = min(QUESTIONS_PER_PHASE, q_count - g * QUESTIONS_PER_PHASE)
                total += 1 + size  # 1 phase + questoes
    return total

# ─────────────────────────────────────────────────────────────────────────────
# SEED PRINCIPAL
# ─────────────────────────────────────────────────────────────────────────────

def seed():
    global write_count

    print("=" * 60)
    print("  SEED ENEM -> Firestore")
    print("=" * 60)

    estimated = estimate_writes()
    print(f"\n[INFO] Estimativa de gravacoes: ~{estimated}")
    print(f"[INFO] Limite configurado:       {MAX_WRITES}")

    if estimated > MAX_WRITES:
        print(
            f"\n[AVISO] Estimativa ({estimated}) excede o limite ({MAX_WRITES}).\n"
            f"        O script para ao atingir {MAX_WRITES} gravacoes.\n"
        )
    else:
        print(f"[OK]    Dentro do limite - prosseguindo!\n")

    global_order = 1
    limit_reached = False

    for disc in DISCIPLINES:
        if limit_reached:
            break
        disc_value = disc["value"]
        disc_label = disc["label"]

        for year in YEARS:
            if limit_reached:
                break

            print(f"\n[DISC] {disc_label} - ENEM {year}")
            print(f"       Gravacoes usadas: {write_count}/{MAX_WRITES}")

            questions_raw = fetch_questions(year, disc_value, limit=QUESTIONS_PER_BATCH)

            if not questions_raw:
                print("       Nenhuma questao retornada, pulando...")
                continue

            print(f"       {len(questions_raw)} questoes recebidas da API")

            groups = chunk(questions_raw, QUESTIONS_PER_PHASE)
            print(f"       -> {len(groups)} fases de {QUESTIONS_PER_PHASE} questoes cada")

            for group_idx, group in enumerate(groups):
                if limit_reached:
                    break

                remaining = MAX_WRITES - write_count
                if remaining < 2:
                    print(f"\n[STOP] Limite de {MAX_WRITES} gravacoes atingido! Parando.")
                    limit_reached = True
                    break

                phase_name = f"{disc_label} - ENEM {year} (Fase {group_idx + 1})"
                phase_data = {
                    "name": phase_name,
                    "description": (
                        f"Questoes de {disc_label} do ENEM {year}. "
                        f"Fase {group_idx + 1} de {len(groups)}."
                    ),
                    "order": global_order,
                    "year": year,
                    "discipline": disc_value,
                }

                phase_ref = db.collection("Phase").document()
                if not safe_write(phase_ref, phase_data):
                    print(f"\n[STOP] Limite de {MAX_WRITES} gravacoes atingido! Parando.")
                    limit_reached = True
                    break

                global_order += 1
                inserted = 0

                for q_raw in group:
                    if write_count >= MAX_WRITES:
                        print(f"\n[STOP] Limite de {MAX_WRITES} gravacoes atingido! Parando.")
                        limit_reached = True
                        break

                    q_doc = map_question(q_raw, phase_ref)
                    if q_doc is None:
                        continue

                    q_ref = db.collection("Questions").document()
                    if safe_write(q_ref, q_doc):
                        inserted += 1

                print(
                    f"  [OK] '{phase_name}' -> {inserted} questoes "
                    f"[gravacoes: {write_count}/{MAX_WRITES}]"
                )

                time.sleep(0.25)

    print("\n" + "=" * 60)
    print(f"  [DONE] Seed ENEM concluido!")
    print(f"  Total de gravacoes: {write_count}/{MAX_WRITES}")
    print(f"  Fases criadas:      {global_order - 1}")
    print("=" * 60)


if __name__ == "__main__":
    seed()
