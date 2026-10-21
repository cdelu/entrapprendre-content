#!/usr/bin/env python3
"""Audit de production du contenu Entr'Apprendre (complement de tool/validate_content.dart).

Usage : python3 tool/content_production/audit_content.py [--require-all] [--units M02-U01,...]

Verifie, pour chaque unite presente (ou exigee) :
- conformite au schema JSON (schema/unit.schema.json) ;
- en-tete identique au resume du catalogue (moduleId, number, title) ;
- seuls les types de blocs/exercices utilisables par l'apprenant (manifest + liste du brief) ;
- identifiants de blocs/items/questions uniques ; options de scale distinctes ;
- onglets/processus/frise : au moins deux elements, onglets aux titres distincts ;
- structure finale : un bloc takeaway puis l'exercice journal_formation ;
- aucune instruction importante uniquement dans hint ; aucun texte de remplissage ;
- medias references presents dans media/, et aucun fichier media non reference ;
- pas de champs de notation (score, points, correct...).
Avec --require-all : chaque unite du catalogue doit avoir son dossier source.
"""
import json, re, sys, argparse
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BLOCKS = {"text", "accordion", "takeaway", "exercise", "flashcards", "tabs", "statement", "quote",
          "list", "image", "process", "timeline"}
ITEMS = {"textarea", "scale"}
PLACEHOLDER = re.compile(r"(\bTODO\b|\bTBD\b|[Ll]orem|[Ii]psum|À CRÉER|A CREER|[Pp]laceholder|XXX)")
SCORING = {"score", "scores", "points", "correct", "answer", "answers", "grade", "isCorrect", "correctAnswer"}

try:
    import jsonschema
except ImportError:
    jsonschema = None


def load(p):
    with open(p, encoding="utf-8") as f:
        return json.load(f)


def walk_strings(o, path=""):
    if isinstance(o, dict):
        for k, v in o.items():
            yield from walk_strings(v, f"{path}.{k}")
    elif isinstance(o, list):
        for i, v in enumerate(o):
            yield from walk_strings(v, f"{path}[{i}]")
    elif isinstance(o, str):
        yield path, o


def walk_keys(o, path=""):
    if isinstance(o, dict):
        for k, v in o.items():
            yield f"{path}.{k}", k
            yield from walk_keys(v, f"{path}.{k}")
    elif isinstance(o, list):
        for i, v in enumerate(o):
            yield from walk_keys(v, f"{path}[{i}]")


def audit_unit(uid, summary, errors, warnings, validator):
    folder = ROOT / "source" / "units" / uid
    f = folder / "unit.json"
    E = lambda m: errors.append(f"{uid}: {m}")
    W = lambda m: warnings.append(f"{uid}: {m}")
    try:
        u = load(f)
    except Exception as e:
        E(f"JSON illisible ({e})"); return None
    if validator:
        for err in sorted(validator.iter_errors(u), key=lambda e: list(e.path)):
            E("schéma : " + "/".join(map(str, err.path)) + " : " + err.message[:160])
    if u.get("id") != uid:
        E("id différent du dossier")
    for k in ("moduleId", "number", "title"):
        if summary and u.get(k) != summary.get(k):
            E(f"{k} diffère du catalogue ({u.get(k)!r} / {summary.get(k)!r})")
    blocks = u.get("blocks", [])
    seen = set()
    referenced = set()
    for i, b in enumerate(blocks):
        bp = f"blocks[{i}] {b.get('id')}"
        if b.get("id") in seen:
            E(f"{bp}: id de bloc dupliqué")
        seen.add(b.get("id"))
        kind = b.get("kind")
        if kind not in BLOCKS:
            E(f"{bp}: type non utilisable : {kind}")
        if kind in ("tabs", "process", "timeline") and len(b.get("items", [])) < 2:
            E(f"{bp}: au moins deux éléments")
        if kind == "tabs":
            titles = [it.get("title") for it in b.get("items", [])]
            if len(set(titles)) != len(titles):
                E(f"{bp}: titres d'onglets en double")
        if kind == "image":
            referenced.add(b.get("image", {}).get("path"))
        audio = b.get("audio")
        if audio:
            if "path" in audio:
                referenced.add(audio["path"])
            for tr in audio.get("tracks", {}).values():
                referenced.add(tr.get("path"))
        if kind == "exercise":
            ids = set()
            for it in b.get("items", []):
                ik = it.get("kind")
                if ik not in ITEMS:
                    E(f"{bp}: exercice non utilisable : {ik}")
                if it.get("id") in ids:
                    E(f"{bp}: id d'item dupliqué {it.get('id')}")
                ids.add(it.get("id"))
                if ik == "textarea" and not it.get("prompt", "").strip():
                    E(f"{bp}/{it.get('id')}: consigne vide")
                if it.get("hint"):
                    W(f"{bp}/{it.get('id')}: hint présent (non affiché par l'apprenant)")
                if ik == "scale":
                    opts = it.get("options", [])
                    if len(opts) < 2 or len(set(opts)) != len(opts):
                        E(f"{bp}/{it.get('id')}: options de scale invalides")
                    qids = [q.get("id") for q in it.get("questions", [])]
                    if len(set(qids)) != len(qids) or not qids:
                        E(f"{bp}/{it.get('id')}: questions absentes ou ids dupliqués")
    # structure finale
    if len(blocks) < 2 or blocks[-1].get("id") != "journal_formation" or blocks[-1].get("kind") != "exercise":
        E("le dernier bloc doit être l'exercice journal_formation")
    elif blocks[-1].get("title") != "Mon journal de formation":
        E("titre du journal : « Mon journal de formation »")
    if len(blocks) >= 2 and blocks[-2].get("kind") != "takeaway":
        E("l'avant-dernier bloc doit être un takeaway")
    kinds = [b.get("kind") for b in blocks]
    if "exercise" not in kinds[:-1]:
        W("aucune activité pratique avant le journal")
    for p, s in walk_strings(u):
        if PLACEHOLDER.search(s):
            E(f"texte de remplissage {p}: {s[:60]}")
        if re.search(r"\bM0\d-U0\d\b", s) and not p.endswith((".id", ".moduleId")) and p not in (".id",):
            E(f"identifiant interne visible {p}")
        if re.search(r"<[a-z/][^>]*>|\*\*|__", s):
            W(f"balisage HTML/Markdown {p}")
    for p, k in walk_keys(u):
        if k in SCORING:
            E(f"champ de notation interdit {p}")
    # medias
    media = folder / "media"
    present = {f"media/{x.name}" for x in media.iterdir()} if media.is_dir() else set()
    for r in referenced:
        if r and r not in present:
            E(f"média introuvable : {r}")
    for x in present - referenced:
        E(f"fichier média non référencé (serait publié) : {x}")
    for r in referenced:
        if r and not re.fullmatch(r"media/[A-Za-z0-9._-]+", r):
            E(f"nom de média non portable : {r}")
    return u


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--require-all", action="store_true")
    ap.add_argument("--units")
    a = ap.parse_args()
    cat = load(ROOT / "source" / "catalog.source.json")
    summaries = {u["id"]: u for u in cat["units"]}
    validator = None
    if jsonschema:
        validator = jsonschema.Draft202012Validator(load(ROOT / "schema" / "unit.schema.json"))
    errors, warnings = [], []
    present = sorted(p.name for p in (ROOT / "source" / "units").iterdir() if p.is_dir())
    for d in present:
        if d not in summaries:
            errors.append(f"{d}: dossier orphelin (absent du catalogue)")
    wanted = a.units.split(",") if a.units else present
    if a.require_all:
        for uid in summaries:
            if uid not in present:
                errors.append(f"{uid}: unité du catalogue sans source")
    # coherence catalogue
    mods = {m["id"]: m for m in cat["modules"]}
    for m in cat["modules"]:
        if "generatesCertificate" not in m:
            errors.append(f"{m['id']}: generatesCertificate absent")
        for uid in m["unitIds"]:
            if summaries.get(uid, {}).get("moduleId") != m["id"]:
                errors.append(f"{m['id']}: unité {uid} mal rattachée")
    for uid in wanted:
        if uid in present:
            audit_unit(uid, summaries.get(uid), errors, warnings, validator)
    for w in warnings:
        print("AVERTISSEMENT", w)
    for e in errors:
        print("ERREUR", e)
    print(f"{len(wanted)} unité(s) auditée(s), {len(errors)} erreur(s), {len(warnings)} avertissement(s)")
    sys.exit(1 if errors else 0)


if __name__ == "__main__":
    main()
