"""
Stage 2 of "every lemma needs ≥ 3 sentences" workstream.

Filters tools/lemma_extracted_{en,fr}.json down to teaching-relevant
lemmas. Drops:
- Specific proper nouns (people, places, brands, fictional characters)
- Country names + nationality / language words
- Pure numbers (years like 1991)
- Single-letter junk (B)
- Compound brand-like phrases ("AI tool", "Assassin's Creed")

Keeps (same triage that flagged them as suspicious — but these are real
teaching items):
- Months & days of the week
- Festivals / holidays (Noël, Pâques, Toussaint, Assomption, Chandeleur,
  Jour de l'an)
- Common abbreviations: TV, DVD, ID, OK
- Forms of address: Dad, Mom, Grand-mère
- Common nouns occasionally capitalized: Internet, Wi-Fi
- Pronouns / articles even when single-char: I, i, a, à

This was decided by an inline LLM pass (Claude Opus 4.7, 2026-05-10).
The drop lists below are hardcoded so the result is reproducible — if
the corpus grows and produces new suspicious lemmas, run extract_lemmas
again, eyeball the diff against these lists, and append. ZH not handled
here; its over-extraction issue (multi-word phrases as lemmas) needs a
different strategy.
"""
import json
from datetime import date
from pathlib import Path


DROP_EN: dict[str, str] = {
    "AI tool":        "tech compound (brand-like)",
    "Alex":           "person name",
    "B":              "single letter, no meaning",
    "Bobo":           "character name",
    "Boston":         "city",
    "Chicago":        "city",
    "China":          "country",
    "Cinderella":     "fictional character",
    "French":         "language / nationality",
    "Gretel":         "fictional character",
    "Hansel":         "fictional character",
    "Humpty Dumpty":  "fictional character",
    "Jack":           "person name",
    "Japanese":       "language / nationality",
    "Jill":           "person name",
    "London Bridge":  "landmark / song reference",
    "Mary":           "person name",
    "McGregor":       "person name (Peter Rabbit)",
    "Old MacDonald":  "song character",
    "Paris":          "city",
    "Peter":          "person name (Peter Rabbit)",
    "Portugal":       "country",
    "Tom":            "person name",
}

DROP_FR: dict[str, str] = {
    "Alpes":             "mountain range (place)",
    "Amérique":          "continent",
    "Asie":              "continent",
    "Assassin's Creed":  "game / brand",
    "Avignon":           "city",
    "Bluetooth":         "brand",
    "Bordeaux":          "city",
    "Bugatti":           "brand",
    "Cannes":            "city",
    "Cartier":           "brand",
    "Cendrillon":        "fictional character (Cinderella)",
    "Champs-Élysées":    "landmark / street",
    "Chanel":            "brand",
    "Chine":             "country",
    "Chinois":           "language / nationality",
    "Cigale":            "fable character (capitalized — common-noun form 'cigale' kept)",
    "Claire Dubois":     "person name",
    "Dagobert":          "historical person / song reference",
    "Denis Villeneuve":  "person name",
    "Dieu":              "religious proper noun",
    "Dior":              "brand",
    "Dupont":            "person name",
    "Europe":            "continent",
    "Fadette":           "fictional character",
    "Felix":             "person name",
    "Fourmi":            "fable character (capitalized — common-noun form 'fourmi' kept)",
    "France":            "country",
    "Gaspard":           "person name",
    "Grand-mère":        "capitalized artifact — lowercase 'grand-mère' is the real lemma",
    "Grèce":             "country",
    "Hermès":            "brand",
    "Hugo":              "person name",
    "Italie":            "country",
    "Jacques":           "person name",
    "Jean":              "person name (note: 'jean' lowercase = jeans)",
    "Landry":            "person name",
    "Louis Vuitton":     "brand",
    "Louvre - Rivoli":   "metro station name",
    "Lyon":              "city",
    "Marie":             "person name",
    "Marseille":         "city",
    "Moyen-Orient":      "geographic region",
    "Musique":           "capitalized artifact — lowercase 'musique' is the real lemma",
    "Nice":              "city",
    "Paris":             "city",
    "Petit Poucet":      "fictional character (Tom Thumb)",
    "Peugeot":           "brand",
    "Pierrot":           "character name",
    "Provence":          "region",
    "Sophie":            "person name",
    "Sylvinet":          "fictional character",
    "Terminus":          "place reference (metro endpoint)",
    "Thomas":            "person name",
    "Tour Eiffel":       "landmark",
    "Vietnam":           "country",
    "Éloi":              "person name (Saint Éloi)",
    "1991":              "pure number",
}


def main() -> None:
    root = Path(__file__).resolve().parent.parent

    for lang, drops in (("en", DROP_EN), ("fr", DROP_FR)):
        src = root / "tools" / f"lemma_extracted_{lang}.json"
        data = json.loads(src.read_text(encoding="utf-8"))
        original = data["lemmas"]

        kept = [l for l in original if l not in drops]
        dropped = [{"lemma": l, "reason": r} for l, r in sorted(drops.items())]

        # Sanity: every drop entry should exist in the source list — flag drift.
        missing = [l for l in drops if l not in original]
        if missing:
            raise SystemExit(
                f"{lang}: drop list references lemmas not in source: {missing}"
            )

        out = {
            "language": lang,
            "source": str(src.relative_to(root)),
            "cleaned_at": str(date.today()),
            "kept_count": len(kept),
            "dropped_count": len(dropped),
            "kept": kept,
            "dropped": dropped,
            "_note": (
                "Stage 2 cleanup. Drops are hardcoded in tools/clean_lemmas.py "
                "(decided by inline Claude Opus 4.7 pass on 2026-05-10). "
                "Re-running this script after a corpus expansion will preserve "
                "existing drops; new suspicious lemmas need to be added "
                "manually after eyeballing the next extract_lemmas output."
            ),
        }

        out_path = root / "tools" / f"lemma_clean_{lang}.json"
        out_path.write_text(
            json.dumps(out, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )
        print(
            f"{lang}: kept {len(kept):,} / dropped {len(dropped)} "
            f"-> {out_path.relative_to(root)}"
        )


if __name__ == "__main__":
    main()
