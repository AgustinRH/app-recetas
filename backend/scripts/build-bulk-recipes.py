#!/usr/bin/env python3
"""Genera recetas caseras originales a partir del catálogo de ingredientes.

No copia texto de recetarios. Las fotos se buscan aparte (Wikimedia Commons).
"""
from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SEED_TS = ROOT / "src" / "seed" / "seed-data.ts"
OUT = ROOT / "src" / "seed" / "bulk-recipes.json"

NAMES = set(re.findall(r"name: '([^']+)'", SEED_TS.read_text()))

# Proteína, carbohidratos y grasa por 100 g (o 100 ml).
PER100: dict[str, tuple[float, float, float]] = {
    "Leche": (3.4, 4.8, 3.6),
    "Yogur": (4, 6, 3),
    "Queso": (20, 2, 25),
    "Parmesano": (35, 4, 26),
    "Mantequilla": (0.7, 0.1, 81),
    "Nata": (2, 3, 35),
    "Mozzarella": (18, 2, 17),
    "Tomate": (0.9, 3.9, 0.2),
    "Cebolla": (1.1, 9, 0.1),
    "Ajo": (6, 33, 0.5),
    "Patata": (2, 17, 0.1),
    "Zanahoria": (0.9, 10, 0.2),
    "Pimiento": (1, 6, 0.3),
    "Lechuga": (1.4, 2.9, 0.2),
    "Pepino": (0.7, 3.6, 0.1),
    "Calabacín": (1.2, 3.1, 0.3),
    "Espinaca": (2.9, 3.6, 0.4),
    "Apio": (0.7, 3, 0.2),
    "Puerro": (1.5, 14, 0.3),
    "Limón": (1.1, 9, 0.3),
    "Lima": (0.7, 11, 0.2),
    "Plátano": (1.1, 23, 0.3),
    "Manzana": (0.3, 14, 0.2),
    "Aguacate": (2, 9, 15),
    "Fresa": (0.7, 8, 0.3),
    "Pollo": (27, 0, 4),
    "Ternera": (26, 0, 8),
    "Cerdo": (22, 0, 8),
    "Bacon": (13, 1, 32),
    "Atún": (24, 0, 1),
    "Salmón": (20, 0, 13),
    "Bacalao": (18, 0, 0.7),
    "Arroz": (7, 77, 0.6),
    "Pasta": (13, 75, 1.5),
    "Pan": (9, 49, 3),
    "Harina": (10, 76, 1),
    "Avena": (13, 67, 7),
    "Lentejas": (24, 63, 1),
    "Garbanzos": (20, 61, 6),
    "Alubias": (21, 63, 1),
    "Guisantes": (5, 14, 0.4),
    "Sal": (0, 0, 0),
    "Pimienta": (10, 64, 3),
    "Pimentón": (14, 54, 13),
    "Comino": (18, 44, 22),
    "Orégano": (9, 69, 4),
    "Laurel": (8, 48, 8),
    "Canela": (4, 81, 1),
    "Aceite de oliva": (0, 0, 91),
    "Vinagre": (0, 0.9, 0),
    "Salsa de soja": (8, 5, 0),
    "Miel": (0.3, 82, 0),
    "Azúcar": (0, 100, 0),
    "Caldo": (0.5, 0.5, 0.3),
    "Huevos": (13, 1.1, 11),
    "Albahaca": (3, 3, 0.6),
    "Perejil": (3, 6, 0.8),
    "Dorada": (20, 0, 3),
    "Lubina": (19, 0, 2),
    "Merluza": (17, 0, 1),
    "Sardinas": (25, 0, 11),
    "Boquerones": (20, 0, 5),
    "Gambas": (20, 1, 1),
    "Calamares": (16, 3, 1.4),
    "Mejillones": (12, 4, 2),
    "Pulpo": (15, 2, 1),
    "Trucha": (20, 0, 5),
    "Pavo": (24, 0, 2),
    "Cordero": (20, 0, 15),
    "Conejo": (21, 0, 5),
    "Chorizo": (24, 2, 38),
    "Jamón": (30, 0, 15),
    "Jamón cocido": (18, 1, 5),
    "Carne picada": (20, 0, 15),
    "Salchichas": (12, 2, 25),
    "Champiñones": (3, 3, 0.3),
    "Berenjena": (1, 6, 0.2),
    "Brócoli": (2.8, 7, 0.4),
    "Coliflor": (1.9, 5, 0.3),
    "Judías verdes": (1.8, 7, 0.2),
    "Maíz": (3, 19, 1.2),
    "Col": (1.3, 6, 0.1),
    "Alcachofa": (3, 11, 0.2),
    "Espárragos": (2.2, 4, 0.1),
    "Boniato": (1.6, 20, 0.1),
    "Calabaza": (1, 7, 0.1),
    "Rúcula": (2.6, 3.7, 0.7),
    "Naranja": (0.9, 12, 0.1),
    "Pera": (0.4, 15, 0.1),
    "Uvas": (0.7, 18, 0.2),
    "Melocotón": (0.9, 10, 0.3),
    "Sandía": (0.6, 8, 0.2),
    "Melón": (0.8, 8, 0.2),
    "Piña": (0.5, 13, 0.1),
    "Mango": (0.8, 15, 0.4),
    "Kiwi": (1.1, 15, 0.5),
    "Quinoa": (14, 64, 6),
    "Cuscús": (13, 77, 0.6),
    "Pan rallado": (13, 72, 5),
    "Tortillas de trigo": (8, 49, 7),
    "Maicena": (0.3, 91, 0),
    "Levadura": (8, 4, 1.5),
    "Tofu": (8, 2, 5),
    "Curry": (14, 56, 14),
    "Cúrcuma": (8, 67, 10),
    "Jengibre": (1.8, 18, 0.8),
    "Tomillo": (9, 24, 7),
    "Romero": (3, 21, 6),
    "Guindilla": (12, 57, 17),
    "Nuez moscada": (6, 49, 36),
    "Vainilla": (0, 13, 0),
    "Tomate frito": (1.5, 8, 2),
    "Mayonesa": (1, 1, 75),
    "Mostaza": (4, 5, 3),
    "Ketchup": (1, 25, 0.2),
    "Vino blanco": (0.1, 2.6, 0),
    "Vino tinto": (0.1, 2.6, 0),
    "Aceite de girasol": (0, 0, 91),
    "Cacao": (20, 58, 14),
    "Chocolate": (8, 46, 35),
    "Nueces": (15, 14, 65),
    "Almendras": (21, 22, 50),
    "Aceitunas": (1, 6, 11),
    "Café": (0.1, 0, 0),
    "Agua": (0, 0, 0),
}

PIECE_G = {
    "Huevos": 55,
    "Patata": 150,
    "Cebolla": 150,
    "Tomate": 120,
    "Pimiento": 150,
    "Calabacín": 200,
    "Berenjena": 250,
    "Pepino": 200,
    "Limón": 80,
    "Lima": 70,
    "Plátano": 120,
    "Manzana": 150,
    "Aguacate": 160,
    "Naranja": 180,
    "Pera": 150,
    "Yogur": 125,
    "Pan": 40,
    "Tortillas de trigo": 60,
    "Zanahoria": 80,
    "Lechuga": 200,
    "Ajo": 5,
    "Laurel": 0.5,
    "Salchichas": 60,
    "Melocotón": 150,
    "Kiwi": 80,
    "Mango": 200,
    "Chorizo": 80,
}

MEAT = {
    "Pollo", "Ternera", "Cerdo", "Bacon", "Pavo", "Cordero", "Conejo",
    "Chorizo", "Jamón", "Jamón cocido", "Carne picada", "Salchichas",
}
FISH = {
    "Atún", "Salmón", "Bacalao", "Dorada", "Lubina", "Merluza", "Sardinas",
    "Boquerones", "Gambas", "Calamares", "Mejillones", "Pulpo", "Trucha",
}
DAIRY = {"Leche", "Yogur", "Queso", "Parmesano", "Mantequilla", "Nata", "Mozzarella"}
GLUTEN = {"Pasta", "Pan", "Harina", "Pan rallado", "Tortillas de trigo", "Cuscús", "Avena"}

recipes: list[dict] = []
seen: set[str] = set()


def grams(name: str, qty: float, unit: str) -> float:
    unit = unit.lower()
    if unit in {"g", "ml"}:
        return qty
    if unit in {"ud"}:
        return qty * PIECE_G.get(name, 100)
    if unit in {"cdita"}:
        return qty * 5
    if unit in {"hoja"}:
        return qty * 0.5
    if unit in {"manojo"}:
        return qty * 20
    if unit in {"diente", "dientes"}:
        return qty * 5
    if unit in {"rebanadas"}:
        return qty * 30
    raise SystemExit(f"unidad desconocida {unit} en {name}")


def add(title, cuisine, minutes, difficulty, servings, photo, items, steps, desc=""):
    if title in seen:
        return
    seen.add(title)
    norm = []
    for raw in items:
        name, qty, unit = raw[0], raw[1], raw[2]
        optional = bool(raw[3]) if len(raw) > 3 else False
        if name not in NAMES:
            raise SystemExit(f"{title}: ingrediente fuera del catálogo: {name}")
        norm.append({"name": name, "quantity": qty, "unit": unit, "optional": optional})
    p = c = f = 0.0
    for item in norm:
        gp = grams(item["name"], item["quantity"], item["unit"])
        pp, cc, ff = PER100[item["name"]]
        p += pp * gp / 100
        c += cc * gp / 100
        f += ff * gp / 100
    servings = max(1, servings)
    p, c, f = p / servings, c / servings, f / servings
    kcal = round(4 * p + 4 * c + 9 * f)
    names = {i["name"] for i in norm}
    tags = []
    if not (names & (MEAT | FISH | DAIRY | {"Huevos", "Miel"})):
        tags.append("vegana")
    if not (names & (MEAT | FISH)):
        tags.append("vegetariana")
    if not (names & GLUTEN):
        tags.append("sin gluten")
    starch = {
        "Patata", "Arroz", "Pasta", "Pan", "Azúcar", "Miel", "Lentejas", "Garbanzos",
        "Alubias", "Harina", "Pan rallado", "Plátano", "Tortillas de trigo", "Cuscús",
        "Avena", "Quinoa", "Maíz", "Boniato", "Maicena", "Chocolate",
    }
    if c <= 15 and not (names & starch):
        tags.append("keto")
    if not desc:
        desc = f"{title}, para {servings} raciones."
    recipes.append({
        "title": title,
        "description": desc,
        "prepMinutes": minutes,
        "cuisine": cuisine,
        "dietTags": tags,
        "calories": kcal,
        "servings": servings,
        "difficulty": difficulty,
        "protein": round(p),
        "carbs": round(c),
        "fat": round(f),
        "photoQuery": photo,
        "ingredients": norm,
        "steps": steps,
    })


OIL = ("Aceite de oliva", 15, "ml")
SALT = ("Sal", 1, "cdita")
PEPPER = ("Pimienta", 1, "cdita")

# name, spoken, grams, photo noun, cuisine
PROTEINS = [
    ("Pollo", "el pollo", 400, "chicken breast", "Internacional"),
    ("Pavo", "el pavo", 400, "turkey breast", "Internacional"),
    ("Ternera", "la ternera", 400, "beef steak", "Internacional"),
    ("Cerdo", "el lomo de cerdo", 400, "pork loin", "Española"),
    ("Cordero", "el cordero", 400, "lamb chops", "Mediterránea"),
    ("Conejo", "el conejo", 400, "roast rabbit", "Española"),
    ("Carne picada", "la carne picada", 400, "ground beef", "Internacional"),
    ("Salchichas", "las salchichas", 300, "grilled sausages", "Internacional"),
    ("Chorizo", "el chorizo", 200, "spanish chorizo", "Española"),
    ("Atún", "el atún", 350, "tuna steak", "Mediterránea"),
    ("Salmón", "el salmón", 350, "salmon fillet", "Internacional"),
    ("Bacalao", "el bacalao", 400, "cod fillet", "Española"),
    ("Dorada", "la dorada", 500, "gilt head bream fish", "Española"),
    ("Lubina", "la lubina", 500, "sea bass fish", "Mediterránea"),
    ("Merluza", "la merluza", 400, "hake fish fillet", "Española"),
    ("Sardinas", "las sardinas", 400, "grilled sardines", "Española"),
    ("Boquerones", "los boquerones", 300, "fresh anchovies", "Española"),
    ("Gambas", "las gambas", 350, "cooked prawns", "Mediterránea"),
    ("Calamares", "los calamares", 350, "squid seafood", "Española"),
    ("Mejillones", "los mejillones", 600, "steamed mussels", "Española"),
    ("Pulpo", "el pulpo", 500, "cooked octopus", "Española"),
    ("Trucha", "la trucha", 400, "baked trout", "Internacional"),
    ("Tofu", "el tofu", 350, "tofu stir fry", "Asiática"),
]

VEGS = [
    ("Calabacín", "el calabacín", "zucchini"),
    ("Berenjena", "la berenjena", "eggplant"),
    ("Brócoli", "el brócoli", "broccoli"),
    ("Coliflor", "la coliflor", "cauliflower"),
    ("Calabaza", "la calabaza", "pumpkin soup"),
    ("Boniato", "el boniato", "roasted sweet potato"),
    ("Champiñones", "los champiñones", "sauteed mushrooms"),
    ("Espinaca", "las espinacas", "spinach"),
    ("Pimiento", "el pimiento", "roasted peppers"),
    ("Col", "la col", "cabbage"),
    ("Judías verdes", "las judías verdes", "green beans"),
    ("Alcachofa", "las alcachofas", "artichokes"),
    ("Espárragos", "los espárragos", "asparagus"),
    ("Zanahoria", "la zanahoria", "carrots"),
    ("Puerro", "el puerro", "leeks"),
    ("Patata", "las patatas", "roast potatoes"),
]


def base_season():
    return [OIL, SALT, PEPPER]


for name, spoken, grams_n, photo, cuisine in PROTEINS:
    add(
        f"{name} a la plancha",
        cuisine, 15, "fácil", 2,
        f"grilled {photo}",
        [(name, grams_n, "g"), *base_season(), ("Limón", 0.5, "ud", True)],
        [
            f"Sazona {spoken} con sal y pimienta.",
            f"Calienta el aceite en una sartén y cocina {spoken} a fuego medio-alto hasta que se dore por fuera y quede hecho por dentro.",
            "Retira del fuego, deja reposar dos minutos y sirve con limón si quieres.",
        ],
        f"{name} a la plancha, jugoso y listo en un cuarto de hora.",
    )
    if name not in {"Mejillones", "Boquerones", "Gambas"}:
        add(
            f"{name} al horno",
            cuisine, 35, "fácil", 2,
            f"oven baked {photo}",
            [(name, grams_n, "g"), ("Patata", 2, "ud"), *base_season(), ("Romero", 1, "cdita", True)],
            [
                "Calienta el horno a 200 °C.",
                f"Pon {spoken} en una fuente con la patata en trozos, aceite, sal, pimienta y romero.",
                "Hornea hasta que la patata esté tierna y el interior del plato, cocinado.",
            ],
            f"{name} asado al horno con patata.",
        )
    if name not in {"Salchichas", "Chorizo", "Jamón"}:
        add(
            f"{name} al ajillo",
            "Española", 20, "fácil", 2,
            f"{photo} garlic",
            [(name, grams_n, "g"), ("Ajo", 4, "dientes"), ("Guindilla", 1, "cdita", True), ("Perejil", 1, "manojo"), *base_season()],
            [
                "Filetea el ajo y dóralo en el aceite a fuego suave, con la guindilla si la usas.",
                f"Añade {spoken}, sal y pimienta, y cocínalo sin que el ajo se queme.",
                "Espolvorea perejil picado y sirve enseguida.",
            ],
            f"{name} con ajo frito y perejil.",
        )
    add(
        f"Arroz con {name.lower()}",
        cuisine, 40, "media", 4,
        f"rice with {photo}",
        [("Arroz", 300, "g"), (name, grams_n, "g"), ("Cebolla", 1, "ud"), ("Pimiento", 1, "ud"), ("Caldo", 700, "ml"), *base_season()],
        [
            f"Sofríe {spoken} troceado con la cebolla y el pimiento.",
            "Añade el arroz, nácaralo un minuto y cubre con el caldo caliente.",
            "Cocina a fuego medio unos 18 minutos, hasta que el arroz absorba el líquido. Deja reposar tapado.",
        ],
        f"Arroz caldoso de casa con {name.lower()}.",
    )
    if name not in {"Mejillones", "Boquerones"}:
        add(
            f"{name} en salsa de tomate",
            cuisine, 30, "fácil", 2,
            f"{photo} tomato sauce",
            [(name, grams_n, "g"), ("Tomate frito", 200, "g"), ("Cebolla", 1, "ud"), ("Ajo", 2, "dientes"), *base_season()],
            [
                "Pochar la cebolla y el ajo en el aceite.",
                f"Añade {spoken} y dóralo un poco.",
                "Cubre con el tomate frito, salpimenta y cocina a fuego suave hasta que la salsa espese.",
            ],
            f"{name} guisado en tomate, para acompañar con pan o arroz.",
        )
    add(
        f"{name} salteado con verduras",
        cuisine, 25, "fácil", 2,
        f"stir fried {photo} vegetables",
        [(name, grams_n, "g"), ("Pimiento", 1, "ud"), ("Calabacín", 1, "ud"), ("Cebolla", 1, "ud"), ("Ajo", 1, "diente"), *base_season()],
        [
            "Corta la verdura en tiras y el ajo en láminas.",
            f"Saltea {spoken} a fuego fuerte. Retíralo cuando esté dorado.",
            "En la misma sartén cocina la verdura, devuelve la proteína, salpimenta y mezcla un minuto.",
        ],
        f"Salteado rápido de {name.lower()} con pimiento y calabacín.",
    )
    if name not in {"Dorada", "Lubina", "Sardinas", "Mejillones", "Pulpo"}:
        add(
            f"{name} con patatas",
            "Española", 40, "media", 4,
            f"{photo} with potatoes",
            [(name, grams_n, "g"), ("Patata", 4, "ud"), ("Cebolla", 1, "ud"), ("Pimentón", 1, "cdita"), *base_season()],
            [
                "Corta la patata en rodajas y póchala con la cebolla en el aceite.",
                f"Incorpora {spoken}, el pimentón, sal y pimienta.",
                "Tapa y cocina a fuego medio hasta que la patata esté blanda y el conjunto, hecho.",
            ],
            f"Guiso sencillo de {name.lower()} y patata.",
        )

for name, spoken, photo in VEGS:
    qty_unit = ("ud", 2) if name in PIECE_G else ("g", 400)
    unit, qty = qty_unit
    add(
        f"{name} salteado",
        "Mediterránea", 15, "fácil", 2,
        f"sauteed {photo}",
        [(name, qty, unit), ("Ajo", 2, "dientes"), *base_season()],
        [
            f"Corta {spoken} en trozos regulares.",
            "Dora el ajo en el aceite y añade la verdura con sal y pimienta.",
            "Saltea a fuego medio hasta que esté tierna y aún con color.",
        ],
        f"{name} salteado con ajo, de guarnición o plato único.",
    )
    add(
        f"{name} al horno",
        "Mediterránea", 35, "fácil", 2,
        f"roasted {photo}",
        [(name, qty, unit), ("Aceite de oliva", 20, "ml"), ("Sal", 1, "cdita"), ("Pimienta", 1, "cdita"), ("Tomillo", 1, "cdita", True)],
        [
            "Calienta el horno a 200 °C.",
            f"Extiende {spoken} en una bandeja, aliña con aceite, sal, pimienta y tomillo.",
            "Hornea hasta que los bordes se doren y el centro ceda al tenedor.",
        ],
        f"{name} asado, con los bordes tostados.",
    )
    if name not in {"Patata", "Boniato"}:
        add(
            f"Crema de {name.lower()}",
            "Internacional", 30, "fácil", 4,
            f"{photo} soup",
            [(name, qty if unit == "g" else qty * PIECE_G.get(name, 150), "g"), ("Cebolla", 1, "ud"), ("Caldo", 700, "ml"), ("Patata", 1, "ud"), *base_season()],
            [
                "Sofríe la cebolla en el aceite.",
                f"Añade {spoken}, la patata y el caldo. Cuece hasta que todo esté blando.",
                "Tritura, rectifica de sal y sirve caliente.",
            ],
            f"Crema suave de {name.lower()} para cuatro.",
        )

SALADS = [
    ("Ensalada de garbanzos", "Mediterránea", "chickpea salad", [("Garbanzos", 250, "g"), ("Tomate", 2, "ud"), ("Pepino", 1, "ud"), ("Cebolla", 0.5, "ud"), ("Aceite de oliva", 20, "ml"), ("Vinagre", 10, "ml"), ("Sal", 1, "cdita"), ("Comino", 1, "cdita")]),
    ("Ensalada de lentejas", "Mediterránea", "lentil salad", [("Lentejas", 250, "g"), ("Pimiento", 1, "ud"), ("Cebolla", 0.5, "ud"), ("Perejil", 1, "manojo"), ("Aceite de oliva", 20, "ml"), ("Vinagre", 10, "ml"), ("Sal", 1, "cdita")]),
    ("Ensalada de quinoa", "Internacional", "quinoa salad", [("Quinoa", 200, "g"), ("Pepino", 1, "ud"), ("Tomate", 2, "ud"), ("Limón", 1, "ud"), ("Aceite de oliva", 20, "ml"), ("Sal", 1, "cdita"), ("Perejil", 1, "manojo")]),
    ("Ensalada de pasta", "Italiana", "pasta salad", [("Pasta", 250, "g"), ("Tomate", 2, "ud"), ("Aceitunas", 40, "g"), ("Mozzarella", 100, "g"), ("Aceite de oliva", 20, "ml"), ("Sal", 1, "cdita"), ("Orégano", 1, "cdita")]),
    ("Ensalada de arroz", "Internacional", "rice salad", [("Arroz", 250, "g"), ("Maíz", 100, "g"), ("Pimiento", 1, "ud"), ("Atún", 120, "g"), ("Aceite de oliva", 15, "ml"), ("Sal", 1, "cdita"), ("Limón", 0.5, "ud")]),
    ("Ensalada de pollo", "Internacional", "chicken salad", [("Pollo", 300, "g"), ("Lechuga", 1, "ud"), ("Tomate", 2, "ud"), ("Maíz", 80, "g"), ("Aceite de oliva", 15, "ml"), ("Sal", 1, "cdita"), ("Limón", 0.5, "ud")]),
    ("Ensalada de atún", "Mediterránea", "tuna salad", [("Atún", 200, "g"), ("Lechuga", 1, "ud"), ("Tomate", 2, "ud"), ("Cebolla", 0.5, "ud"), ("Aceitunas", 30, "g"), ("Aceite de oliva", 15, "ml"), ("Sal", 1, "cdita")]),
    ("Ensalada caprese", "Italiana", "caprese salad", [("Tomate", 3, "ud"), ("Mozzarella", 200, "g"), ("Albahaca", 1, "manojo"), ("Aceite de oliva", 20, "ml"), ("Sal", 1, "cdita")]),
    ("Ensalada de espinacas", "Internacional", "spinach salad", [("Espinaca", 150, "g"), ("Nueces", 30, "g"), ("Queso", 40, "g"), ("Manzana", 1, "ud"), ("Aceite de oliva", 15, "ml"), ("Vinagre", 10, "ml"), ("Sal", 1, "cdita")]),
    ("Ensalada de rúcula y parmesano", "Italiana", "arugula parmesan salad", [("Rúcula", 80, "g"), ("Parmesano", 30, "g"), ("Tomate", 1, "ud"), ("Aceite de oliva", 15, "ml"), ("Limón", 0.5, "ud"), ("Sal", 1, "cdita")]),
    ("Ensalada de naranja y bacalao", "Española", "orange cod salad", [("Naranja", 2, "ud"), ("Bacalao", 200, "g"), ("Cebolla", 0.5, "ud"), ("Aceitunas", 30, "g"), ("Aceite de oliva", 15, "ml"), ("Sal", 1, "cdita")]),
    ("Ensalada de aguacate", "Mexicana", "avocado salad", [("Aguacate", 2, "ud"), ("Tomate", 2, "ud"), ("Cebolla", 0.5, "ud"), ("Cilantro" if False else "Perejil", 1, "manojo"), ("Limón", 1, "ud"), ("Sal", 1, "cdita"), ("Aceite de oliva", 10, "ml")]),
    ("Ensalada de patata", "Internacional", "potato salad", [("Patata", 4, "ud"), ("Huevos", 2, "ud"), ("Cebolla", 0.5, "ud"), ("Mayonesa", 40, "g"), ("Sal", 1, "cdita"), ("Perejil", 1, "manojo")]),
    ("Ensaladilla", "Española", "spanish potato salad tuna", [("Patata", 3, "ud"), ("Zanahoria", 1, "ud"), ("Guisantes", 80, "g"), ("Atún", 100, "g"), ("Huevos", 2, "ud"), ("Mayonesa", 50, "g"), ("Sal", 1, "cdita")]),
    ("Ensalada de col", "Internacional", "coleslaw", [("Col", 300, "g"), ("Zanahoria", 1, "ud"), ("Mayonesa", 40, "g"), ("Vinagre", 10, "ml"), ("Sal", 1, "cdita")]),
    ("Ensalada griega de casa", "Mediterránea", "greek salad", [("Tomate", 2, "ud"), ("Pepino", 1, "ud"), ("Cebolla", 0.5, "ud"), ("Aceitunas", 40, "g"), ("Queso", 80, "g"), ("Aceite de oliva", 20, "ml"), ("Orégano", 1, "cdita"), ("Sal", 1, "cdita")]),
    ("Ensalada de manzana y nueces", "Internacional", "apple walnut salad", [("Manzana", 2, "ud"), ("Nueces", 40, "g"), ("Lechuga", 1, "ud"), ("Yogur", 80, "g"), ("Limón", 0.5, "ud"), ("Sal", 1, "cdita")]),
    ("Ensalada de arroz y huevo", "Internacional", "rice egg salad", [("Arroz", 200, "g"), ("Huevos", 3, "ud"), ("Tomate", 1, "ud"), ("Aceite de oliva", 15, "ml"), ("Sal", 1, "cdita")]),
    ("Ensalada de tofu", "Asiática", "tofu salad", [("Tofu", 250, "g"), ("Pepino", 1, "ud"), ("Zanahoria", 1, "ud"), ("Salsa de soja", 15, "ml"), ("Aceite de oliva", 10, "ml"), ("Jengibre", 10, "g")]),
    ("Ensalada de gambas", "Mediterránea", "prawn salad", [("Gambas", 250, "g"), ("Aguacate", 1, "ud"), ("Lechuga", 1, "ud"), ("Limón", 1, "ud"), ("Aceite de oliva", 10, "ml"), ("Sal", 1, "cdita")]),
]
for title, cuisine, photo, items in SALADS:
    add(title, cuisine, 15, "fácil", 2, photo, items, [
        "Cuece lo que haga falta (legumbre, pasta, arroz, patata o huevo) y enfríalo.",
        "Corta la verdura y mézclala con el resto en un bol.",
        "Aliña, prueba de sal y sirve fresco.",
    ], f"{title} para comer fría.")

PASTAS = [
    ("Pasta a la boloñesa", "ground beef bolognese pasta", [("Pasta", 300, "g"), ("Carne picada", 300, "g"), ("Tomate frito", 250, "g"), ("Cebolla", 1, "ud"), ("Zanahoria", 1, "ud"), ("Aceite de oliva", 15, "ml"), ("Sal", 1, "cdita"), ("Parmesano", 30, "g")]),
    ("Pasta con atún", "tuna pasta", [("Pasta", 300, "g"), ("Atún", 160, "g"), ("Tomate frito", 200, "g"), ("Ajo", 2, "dientes"), ("Aceite de oliva", 15, "ml"), ("Sal", 1, "cdita"), ("Perejil", 1, "manojo")]),
    ("Pasta con gambas", "prawn pasta", [("Pasta", 300, "g"), ("Gambas", 250, "g"), ("Ajo", 2, "dientes"), ("Tomate", 2, "ud"), ("Aceite de oliva", 20, "ml"), ("Sal", 1, "cdita"), ("Perejil", 1, "manojo")]),
    ("Pasta con verduras", "pasta vegetables", [("Pasta", 300, "g"), ("Calabacín", 1, "ud"), ("Pimiento", 1, "ud"), ("Berenjena", 1, "ud"), ("Ajo", 1, "diente"), ("Aceite de oliva", 20, "ml"), ("Sal", 1, "cdita"), ("Parmesano", 20, "g", True)]),
    ("Pasta con champiñones", "mushroom pasta", [("Pasta", 300, "g"), ("Champiñones", 250, "g"), ("Ajo", 2, "dientes"), ("Nata", 100, "ml"), ("Aceite de oliva", 15, "ml"), ("Sal", 1, "cdita"), ("Parmesano", 20, "g")]),
    ("Pasta al limón", "lemon pasta", [("Pasta", 300, "g"), ("Limón", 1, "ud"), ("Mantequilla", 20, "g"), ("Parmesano", 40, "g"), ("Sal", 1, "cdita"), ("Pimienta", 1, "cdita")]),
    ("Pasta con espinacas", "spinach pasta", [("Pasta", 300, "g"), ("Espinaca", 150, "g"), ("Ajo", 1, "diente"), ("Nata", 80, "ml"), ("Aceite de oliva", 10, "ml"), ("Sal", 1, "cdita"), ("Parmesano", 20, "g")]),
    ("Pasta con pollo", "chicken pasta", [("Pasta", 300, "g"), ("Pollo", 250, "g"), ("Nata", 100, "ml"), ("Champiñones", 100, "g"), ("Ajo", 1, "diente"), ("Aceite de oliva", 10, "ml"), ("Sal", 1, "cdita")]),
    ("Pasta con chorizo", "chorizo pasta", [("Pasta", 300, "g"), ("Chorizo", 120, "g"), ("Tomate frito", 150, "g"), ("Cebolla", 1, "ud"), ("Aceite de oliva", 10, "ml"), ("Sal", 1, "cdita")]),
    ("Pasta con salmón", "salmon pasta", [("Pasta", 300, "g"), ("Salmón", 200, "g"), ("Nata", 80, "ml"), ("Eneldo" if False else "Perejil", 1, "manojo"), ("Limón", 0.5, "ud"), ("Aceite de oliva", 10, "ml"), ("Sal", 1, "cdita")]),
    ("Pasta con calabacín", "zucchini pasta", [("Pasta", 300, "g"), ("Calabacín", 2, "ud"), ("Ajo", 1, "diente"), ("Parmesano", 30, "g"), ("Aceite de oliva", 20, "ml"), ("Sal", 1, "cdita")]),
    ("Pasta con berenjena", "eggplant pasta", [("Pasta", 300, "g"), ("Berenjena", 1, "ud"), ("Tomate frito", 200, "g"), ("Ajo", 1, "diente"), ("Aceite de oliva", 20, "ml"), ("Sal", 1, "cdita"), ("Albahaca", 1, "manojo")]),
    ("Pasta con alubias", "pasta beans", [("Pasta", 250, "g"), ("Alubias", 200, "g"), ("Tomate frito", 150, "g"), ("Ajo", 1, "diente"), ("Romero", 1, "cdita"), ("Aceite de oliva", 15, "ml"), ("Sal", 1, "cdita")]),
    ("Pasta con brócoli", "broccoli pasta", [("Pasta", 300, "g"), ("Brócoli", 300, "g"), ("Ajo", 2, "dientes"), ("Guindilla", 1, "cdita", True), ("Aceite de oliva", 20, "ml"), ("Sal", 1, "cdita"), ("Parmesano", 20, "g")]),
    ("Lasaña de carne", "beef lasagna", [("Pasta", 250, "g"), ("Carne picada", 350, "g"), ("Tomate frito", 300, "g"), ("Leche", 300, "ml"), ("Harina", 30, "g"), ("Mantequilla", 30, "g"), ("Queso", 80, "g"), ("Sal", 1, "cdita")]),
]
for title, photo, items in PASTAS:
    add(title, "Italiana", 30, "media", 4, photo, items, [
        "Cuece la pasta en agua salada hasta que esté al dente y escúrrela.",
        "Mientras, cocina la salsa o el sofrito en una sartén amplia.",
        "Mezcla la pasta con la salsa, ajusta de sal y sirve. Si es lasaña, monta capas y gratina.",
    ])

RICE = [
    ("Arroz con verduras", "vegetable rice", [("Arroz", 300, "g"), ("Pimiento", 1, "ud"), ("Calabacín", 1, "ud"), ("Guisantes", 80, "g"), ("Caldo", 650, "ml"), ("Cebolla", 1, "ud"), ("Aceite de oliva", 15, "ml"), ("Sal", 1, "cdita")]),
    ("Arroz con gambas", "prawn rice", [("Arroz", 300, "g"), ("Gambas", 300, "g"), ("Tomate frito", 100, "g"), ("Ajo", 2, "dientes"), ("Caldo", 650, "ml"), ("Aceite de oliva", 15, "ml"), ("Sal", 1, "cdita"), ("Perejil", 1, "manojo")]),
    ("Arroz con mejillones", "mussel rice", [("Arroz", 300, "g"), ("Mejillones", 500, "g"), ("Pimiento", 1, "ud"), ("Caldo", 600, "ml"), ("Ajo", 1, "diente"), ("Aceite de oliva", 15, "ml"), ("Sal", 1, "cdita")]),
    ("Arroz con calamares", "squid rice", [("Arroz", 300, "g"), ("Calamares", 300, "g"), ("Tomate frito", 120, "g"), ("Cebolla", 1, "ud"), ("Caldo", 650, "ml"), ("Aceite de oliva", 15, "ml"), ("Sal", 1, "cdita")]),
    ("Arroz con conejo", "rabbit rice", [("Arroz", 300, "g"), ("Conejo", 400, "g"), ("Pimiento", 1, "ud"), ("Tomate frito", 100, "g"), ("Caldo", 700, "ml"), ("Aceite de oliva", 15, "ml"), ("Sal", 1, "cdita"), ("Romero", 1, "cdita")]),
    ("Arroz tres delicias de casa", "fried rice egg ham", [("Arroz", 300, "g"), ("Huevos", 2, "ud"), ("Jamón cocido", 80, "g"), ("Guisantes", 80, "g"), ("Zanahoria", 1, "ud"), ("Salsa de soja", 15, "ml"), ("Aceite de girasol", 15, "ml")]),
    ("Arroz con leche", "spanish rice pudding", [("Arroz", 100, "g"), ("Leche", 800, "ml"), ("Azúcar", 80, "g"), ("Canela", 1, "cdita"), ("Limón", 1, "ud")]),
    ("Arroz con tofu", "tofu fried rice", [("Arroz", 250, "g"), ("Tofu", 200, "g"), ("Pimiento", 1, "ud"), ("Zanahoria", 1, "ud"), ("Salsa de soja", 20, "ml"), ("Aceite de girasol", 15, "ml"), ("Jengibre", 10, "g")]),
]
for title, photo, items in RICE:
    sweet = "leche" in title
    add(title, "Española" if not sweet else "Española", 35, "media", 4, photo, items, [
        "Si el arroz es salado, sofríe primero lo que se dore y luego añade el arroz y el líquido." if not sweet else "Lleva la leche a ebullición suave con la piel de limón y la canela.",
        "Cocina a fuego medio sin dejar de vigilar el punto." if not sweet else "Añade el arroz y el azúcar y cuece removiendo hasta que espese, unos 25 minutos.",
        "Deja reposar unos minutos antes de servir." if not sweet else "Retira el limón y sirve templado o frío, con un poco más de canela.",
    ])

LEGUMES = [
    ("Garbanzos con espinacas", "Española", "chickpeas spinach", [("Garbanzos", 300, "g"), ("Espinaca", 200, "g"), ("Cebolla", 1, "ud"), ("Ajo", 2, "dientes"), ("Pimentón", 1, "cdita"), ("Comino", 1, "cdita"), ("Aceite de oliva", 20, "ml"), ("Sal", 1, "cdita")]),
    ("Garbanzos con bacalao", "Española", "chickpeas cod", [("Garbanzos", 300, "g"), ("Bacalao", 250, "g"), ("Cebolla", 1, "ud"), ("Tomate frito", 100, "g"), ("Ajo", 1, "diente"), ("Aceite de oliva", 15, "ml"), ("Sal", 1, "cdita")]),
    ("Garbanzos al curry", "Asiática", "chickpea curry", [("Garbanzos", 300, "g"), ("Cebolla", 1, "ud"), ("Tomate frito", 200, "g"), ("Curry", 2, "cdita"), ("Jengibre", 10, "g"), ("Ajo", 2, "dientes"), ("Aceite de oliva", 15, "ml"), ("Sal", 1, "cdita")]),
    ("Hummus de garbanzos", "Mediterránea", "hummus", [("Garbanzos", 250, "g"), ("Limón", 1, "ud"), ("Ajo", 1, "diente"), ("Aceite de oliva", 30, "ml"), ("Comino", 1, "cdita"), ("Sal", 1, "cdita")]),
    ("Lentejas con chorizo", "Española", "lentils chorizo", [("Lentejas", 300, "g"), ("Chorizo", 100, "g"), ("Zanahoria", 1, "ud"), ("Cebolla", 1, "ud"), ("Ajo", 1, "diente"), ("Laurel", 1, "hoja"), ("Aceite de oliva", 15, "ml"), ("Sal", 1, "cdita")]),
    ("Lentejas con arroz", "Internacional", "lentils rice", [("Lentejas", 200, "g"), ("Arroz", 150, "g"), ("Cebolla", 1, "ud"), ("Zanahoria", 1, "ud"), ("Comino", 1, "cdita"), ("Aceite de oliva", 15, "ml"), ("Sal", 1, "cdita")]),
    ("Dal de lentejas", "Asiática", "lentil dal", [("Lentejas", 300, "g"), ("Cebolla", 1, "ud"), ("Tomate", 2, "ud"), ("Curry", 1, "cdita"), ("Cúrcuma", 1, "cdita"), ("Jengibre", 10, "g"), ("Ajo", 2, "dientes"), ("Aceite de oliva", 15, "ml"), ("Sal", 1, "cdita")]),
    ("Alubias con verduras", "Española", "white beans vegetables", [("Alubias", 300, "g"), ("Zanahoria", 1, "ud"), ("Puerro", 1, "ud"), ("Patata", 1, "ud"), ("Pimentón", 1, "cdita"), ("Aceite de oliva", 15, "ml"), ("Sal", 1, "cdita")]),
    ("Alubias con chorizo", "Española", "beans chorizo stew", [("Alubias", 300, "g"), ("Chorizo", 120, "g"), ("Cebolla", 1, "ud"), ("Ajo", 2, "dientes"), ("Pimentón", 1, "cdita"), ("Laurel", 1, "hoja"), ("Aceite de oliva", 15, "ml"), ("Sal", 1, "cdita")]),
    ("Potaje de garbanzos", "Española", "chickpea stew", [("Garbanzos", 300, "g"), ("Patata", 2, "ud"), ("Espinaca", 100, "g"), ("Huevos", 2, "ud"), ("Cebolla", 1, "ud"), ("Pimentón", 1, "cdita"), ("Aceite de oliva", 15, "ml"), ("Sal", 1, "cdita")]),
    ("Hamburguesas de lentejas", "Internacional", "lentil burger", [("Lentejas", 250, "g"), ("Cebolla", 1, "ud"), ("Ajo", 1, "diente"), ("Pan rallado", 40, "g"), ("Comino", 1, "cdita"), ("Aceite de oliva", 20, "ml"), ("Sal", 1, "cdita")]),
    ("Hamburguesas de garbanzos", "Mediterránea", "chickpea burger", [("Garbanzos", 250, "g"), ("Cebolla", 0.5, "ud"), ("Perejil", 1, "manojo"), ("Comino", 1, "cdita"), ("Harina", 30, "g"), ("Aceite de oliva", 20, "ml"), ("Sal", 1, "cdita")]),
]
for title, cuisine, photo, items in LEGUMES:
    add(title, cuisine, 40, "media", 4, photo, items, [
        "Si las legumbres están secas, tenlas ya cocidas o cuécelas en agua hasta que estén tiernas.",
        "Sofríe la verdura y las especias, y mezcla con la legumbre.",
        "Cocina unos minutos más para que se integren los sabores. Si son hamburguesas, aplasta, da forma y dóralas.",
    ])

EGGS = [
    ("Tortilla francesa", "plain omelette", [("Huevos", 3, "ud"), ("Aceite de oliva", 10, "ml"), ("Sal", 1, "cdita")]),
    ("Tortilla de calabacín", "zucchini omelette", [("Huevos", 4, "ud"), ("Calabacín", 1, "ud"), ("Cebolla", 0.5, "ud"), ("Aceite de oliva", 20, "ml"), ("Sal", 1, "cdita")]),
    ("Tortilla de espinacas", "spinach omelette", [("Huevos", 4, "ud"), ("Espinaca", 100, "g"), ("Queso", 40, "g"), ("Aceite de oliva", 15, "ml"), ("Sal", 1, "cdita")]),
    ("Tortilla de champiñones", "mushroom omelette", [("Huevos", 4, "ud"), ("Champiñones", 150, "g"), ("Ajo", 1, "diente"), ("Aceite de oliva", 15, "ml"), ("Sal", 1, "cdita")]),
    ("Tortilla de pimiento", "pepper omelette", [("Huevos", 4, "ud"), ("Pimiento", 1, "ud"), ("Cebolla", 0.5, "ud"), ("Aceite de oliva", 20, "ml"), ("Sal", 1, "cdita")]),
    ("Tortilla de atún", "tuna omelette", [("Huevos", 4, "ud"), ("Atún", 100, "g"), ("Cebolla", 0.5, "ud"), ("Aceite de oliva", 15, "ml"), ("Sal", 1, "cdita")]),
    ("Revuelto de gambas", "prawn scrambled eggs", [("Huevos", 4, "ud"), ("Gambas", 150, "g"), ("Ajo", 1, "diente"), ("Aceite de oliva", 15, "ml"), ("Sal", 1, "cdita")]),
    ("Revuelto de espárragos", "asparagus scrambled eggs", [("Huevos", 4, "ud"), ("Espárragos", 200, "g"), ("Aceite de oliva", 15, "ml"), ("Sal", 1, "cdita")]),
    ("Revuelto de champiñones", "mushroom scrambled eggs", [("Huevos", 4, "ud"), ("Champiñones", 150, "g"), ("Ajo", 1, "diente"), ("Aceite de oliva", 10, "ml"), ("Sal", 1, "cdita")]),
    ("Revuelto de bacalao", "cod scrambled eggs", [("Huevos", 4, "ud"), ("Bacalao", 150, "g"), ("Pimiento", 0.5, "ud"), ("Aceite de oliva", 15, "ml"), ("Sal", 1, "cdita")]),
    ("Huevos fritos con patatas", "fried eggs potatoes", [("Huevos", 2, "ud"), ("Patata", 2, "ud"), ("Aceite de oliva", 40, "ml"), ("Sal", 1, "cdita")]),
    ("Huevos al plato", "baked eggs tomato", [("Huevos", 4, "ud"), ("Tomate frito", 150, "g"), ("Jamón", 40, "g", True), ("Aceite de oliva", 10, "ml"), ("Sal", 1, "cdita")]),
    ("Huevos rellenos", "deviled eggs", [("Huevos", 4, "ud"), ("Atún", 80, "g"), ("Mayonesa", 30, "g"), ("Sal", 1, "cdita")]),
    ("Huevos en salsa de tomate", "eggs in tomato sauce", [("Huevos", 4, "ud"), ("Tomate frito", 250, "g"), ("Cebolla", 1, "ud"), ("Pimentón", 1, "cdita"), ("Aceite de oliva", 15, "ml"), ("Sal", 1, "cdita")]),
    ("Tortilla de boniato", "sweet potato omelette", [("Huevos", 4, "ud"), ("Boniato", 1, "ud"), ("Cebolla", 0.5, "ud"), ("Aceite de oliva", 20, "ml"), ("Sal", 1, "cdita")]),
]
for title, photo, items in EGGS:
    add(title, "Española", 15, "fácil", 2, photo, items, [
        "Prepara el relleno o la verdura: saltéalo o cuécelo antes de los huevos.",
        "Bate los huevos con sal, o fríelos según el plato.",
        "Cuaja a fuego medio, sin pasarlos de cocción, y sirve enseguida.",
    ])

BREAKFAST = [
    ("Avena con plátano", "oatmeal banana", [("Avena", 60, "g"), ("Leche", 200, "ml"), ("Plátano", 1, "ud"), ("Canela", 1, "cdita")]),
    ("Avena con manzana", "oatmeal apple", [("Avena", 60, "g"), ("Leche", 200, "ml"), ("Manzana", 1, "ud"), ("Canela", 1, "cdita")]),
    ("Avena con fresas", "oatmeal strawberries", [("Avena", 60, "g"), ("Leche", 200, "ml"), ("Fresa", 80, "g"), ("Miel", 10, "ml")]),
    ("Yogur con fresas", "yogurt strawberries", [("Yogur", 200, "g"), ("Fresa", 100, "g"), ("Nueces", 15, "g")]),
    ("Yogur con mango", "yogurt mango", [("Yogur", 200, "g"), ("Mango", 0.5, "ud"), ("Miel", 10, "ml")]),
    ("Tostada de aguacate", "avocado toast", [("Pan", 2, "rebanadas"), ("Aguacate", 1, "ud"), ("Limón", 0.5, "ud"), ("Sal", 1, "cdita"), ("Aceite de oliva", 5, "ml")]),
    ("Tostada de jamón y tomate", "ham tomato toast", [("Pan", 2, "rebanadas"), ("Tomate", 1, "ud"), ("Jamón", 40, "g"), ("Aceite de oliva", 10, "ml"), ("Sal", 1, "cdita")]),
    ("Tostada de huevo", "egg toast", [("Pan", 2, "rebanadas"), ("Huevos", 2, "ud"), ("Aceite de oliva", 10, "ml"), ("Sal", 1, "cdita")]),
    ("Tostada de atún", "tuna toast", [("Pan", 2, "rebanadas"), ("Atún", 80, "g"), ("Tomate", 1, "ud"), ("Aceite de oliva", 5, "ml")]),
    ("Tostada de queso y tomate", "cheese tomato toast", [("Pan", 2, "rebanadas"), ("Queso", 40, "g"), ("Tomate", 1, "ud"), ("Orégano", 1, "cdita")]),
    ("Tostada de salmón", "smoked salmon toast", [("Pan", 2, "rebanadas"), ("Salmón", 60, "g"), ("Queso", 30, "g"), ("Limón", 0.5, "ud")]),
    ("Batido de plátano", "banana smoothie", [("Plátano", 1, "ud"), ("Leche", 200, "ml"), ("Avena", 20, "g")]),
    ("Batido de fresa", "strawberry smoothie", [("Fresa", 120, "g"), ("Yogur", 150, "g"), ("Leche", 100, "ml")]),
    ("Batido de cacao", "chocolate smoothie", [("Leche", 250, "ml"), ("Cacao", 15, "g"), ("Plátano", 1, "ud")]),
    ("Macedonia de fruta", "fruit salad", [("Manzana", 1, "ud"), ("Naranja", 1, "ud"), ("Plátano", 1, "ud"), ("Fresa", 60, "g"), ("Limón", 0.5, "ud")]),
    ("Manzana asada", "baked apple", [("Manzana", 2, "ud"), ("Canela", 1, "cdita"), ("Miel", 15, "ml"), ("Nueces", 15, "g")]),
]
for title, photo, items in BREAKFAST:
    add(title, "Internacional", 10, "fácil", 1, photo, items, [
        "Prepara la base: tuesta el pan, calienta la avena con la leche o trocea la fruta.",
        "Añade el resto de ingredientes por encima.",
        "Sirve al momento.",
    ])

DESSERTS = [
    ("Fresas con nata", "strawberries cream", [("Fresa", 250, "g"), ("Nata", 100, "ml"), ("Azúcar", 15, "g")]),
    ("Peras al vino", "pears red wine", [("Pera", 3, "ud"), ("Vino tinto", 200, "ml"), ("Azúcar", 40, "g"), ("Canela", 1, "cdita")]),
    ("Naranjas con canela", "oranges cinnamon", [("Naranja", 3, "ud"), ("Canela", 1, "cdita"), ("Miel", 10, "ml", True)]),
    ("Chocolate a la taza", "hot chocolate", [("Leche", 400, "ml"), ("Chocolate", 80, "g"), ("Maicena", 10, "g"), ("Azúcar", 15, "g")]),
    ("Natillas", "spanish custard", [("Leche", 500, "ml"), ("Huevos", 3, "ud"), ("Azúcar", 80, "g"), ("Maicena", 20, "g"), ("Canela", 1, "cdita"), ("Limón", 1, "ud")]),
    ("Flan de huevo", "creme caramel", [("Huevos", 4, "ud"), ("Leche", 500, "ml"), ("Azúcar", 120, "g"), ("Vainilla", 1, "cdita")]),
    ("Bizcocho de yogur", "yogurt cake", [("Yogur", 125, "g"), ("Huevos", 3, "ud"), ("Azúcar", 150, "g"), ("Harina", 180, "g"), ("Aceite de girasol", 80, "ml"), ("Levadura", 8, "g")]),
    ("Galletas de avena", "oatmeal cookies", [("Avena", 120, "g"), ("Harina", 80, "g"), ("Mantequilla", 80, "g"), ("Azúcar", 60, "g"), ("Huevos", 1, "ud")]),
    ("Tortitas", "pancakes", [("Harina", 150, "g"), ("Leche", 200, "ml"), ("Huevos", 1, "ud"), ("Levadura", 6, "g"), ("Azúcar", 15, "g"), ("Mantequilla", 15, "g")]),
    ("Crepes", "crepes", [("Harina", 120, "g"), ("Leche", 250, "ml"), ("Huevos", 2, "ud"), ("Mantequilla", 15, "g"), ("Sal", 1, "cdita")]),
    ("Brownie de chocolate", "chocolate brownie", [("Chocolate", 150, "g"), ("Mantequilla", 100, "g"), ("Huevos", 2, "ud"), ("Azúcar", 100, "g"), ("Harina", 60, "g")]),
    ("Peras con chocolate", "pears chocolate", [("Pera", 2, "ud"), ("Chocolate", 60, "g"), ("Leche", 30, "ml")]),
    ("Plátano asado con canela", "baked banana cinnamon", [("Plátano", 2, "ud"), ("Canela", 1, "cdita"), ("Miel", 10, "ml")]),
    ("Arroz con leche y canela", "cinnamon rice pudding", [("Arroz", 80, "g"), ("Leche", 600, "ml"), ("Azúcar", 60, "g"), ("Canela", 1, "cdita")]),
]
for title, photo, items in DESSERTS:
    # avoid duplicate of arroz con leche
    if title in seen:
        continue
    add(title, "Internacional", 25, "media", 4, photo, items, [
        "Reúne los ingredientes y precalienta el horno si el postre se hornea (180 °C).",
        "Mezcla o cuece según el caso, a fuego suave si lleva leche o chocolate, para que no se pegue.",
        "Deja templar o enfría antes de servir.",
    ])

BOWLS = [
    ("Bol de quinoa con pollo", "quinoa chicken bowl", [("Quinoa", 160, "g"), ("Pollo", 200, "g"), ("Aguacate", 1, "ud"), ("Tomate", 1, "ud"), ("Aceite de oliva", 10, "ml"), ("Sal", 1, "cdita"), ("Limón", 0.5, "ud")]),
    ("Bol de quinoa con salmón", "quinoa salmon bowl", [("Quinoa", 160, "g"), ("Salmón", 180, "g"), ("Pepino", 0.5, "ud"), ("Aguacate", 0.5, "ud"), ("Salsa de soja", 10, "ml"), ("Sal", 1, "cdita")]),
    ("Bol de quinoa con garbanzos", "quinoa chickpea bowl", [("Quinoa", 160, "g"), ("Garbanzos", 150, "g"), ("Pimiento", 1, "ud"), ("Limón", 0.5, "ud"), ("Aceite de oliva", 15, "ml"), ("Comino", 1, "cdita"), ("Sal", 1, "cdita")]),
    ("Bol de quinoa con tofu", "quinoa tofu bowl", [("Quinoa", 160, "g"), ("Tofu", 200, "g"), ("Brócoli", 150, "g"), ("Salsa de soja", 15, "ml"), ("Jengibre", 8, "g"), ("Aceite de oliva", 10, "ml")]),
    ("Cuscús con pollo", "couscous chicken", [("Cuscús", 200, "g"), ("Pollo", 250, "g"), ("Calabacín", 1, "ud"), ("Pimiento", 1, "ud"), ("Comino", 1, "cdita"), ("Aceite de oliva", 15, "ml"), ("Sal", 1, "cdita")]),
    ("Cuscús con verduras", "couscous vegetables", [("Cuscús", 200, "g"), ("Calabacín", 1, "ud"), ("Berenjena", 1, "ud"), ("Pimiento", 1, "ud"), ("Garbanzos", 100, "g"), ("Aceite de oliva", 15, "ml"), ("Comino", 1, "cdita"), ("Sal", 1, "cdita")]),
    ("Cuscús con cordero", "couscous lamb", [("Cuscús", 200, "g"), ("Cordero", 250, "g"), ("Cebolla", 1, "ud"), ("Calabacín", 1, "ud"), ("Comino", 1, "cdita"), ("Canela", 1, "cdita"), ("Aceite de oliva", 15, "ml"), ("Sal", 1, "cdita")]),
    ("Cuscús con gambas", "couscous prawns", [("Cuscús", 200, "g"), ("Gambas", 200, "g"), ("Tomate", 1, "ud"), ("Limón", 0.5, "ud"), ("Aceite de oliva", 15, "ml"), ("Sal", 1, "cdita")]),
]
for title, photo, items in BOWLS:
    add(title, "Internacional", 25, "fácil", 2, photo, items, [
        "Cuece la quinoa o hidrata el cuscús con agua hirviendo y sal, y sepáralo con un tenedor.",
        "Cocina la proteína o la verdura en una sartén con aceite.",
        "Monta el bol, aliña y sirve.",
    ])

WRAPS = [
    ("Wrap de pollo", "chicken wrap", [("Tortillas de trigo", 2, "ud"), ("Pollo", 200, "g"), ("Lechuga", 0.5, "ud"), ("Tomate", 1, "ud"), ("Yogur", 40, "g"), ("Sal", 1, "cdita")]),
    ("Wrap de ternera", "beef wrap", [("Tortillas de trigo", 2, "ud"), ("Ternera", 200, "g"), ("Pimiento", 1, "ud"), ("Cebolla", 0.5, "ud"), ("Aceite de oliva", 10, "ml"), ("Sal", 1, "cdita")]),
    ("Wrap de verduras", "vegetable wrap", [("Tortillas de trigo", 2, "ud"), ("Calabacín", 1, "ud"), ("Pimiento", 1, "ud"), ("Hummus" if False else "Garbanzos", 80, "g"), ("Lechuga", 0.5, "ud"), ("Aceite de oliva", 10, "ml"), ("Sal", 1, "cdita")]),
    ("Wrap de atún", "tuna wrap", [("Tortillas de trigo", 2, "ud"), ("Atún", 120, "g"), ("Lechuga", 0.5, "ud"), ("Tomate", 1, "ud"), ("Mayonesa", 20, "g")]),
    ("Wrap de pavo", "turkey wrap", [("Tortillas de trigo", 2, "ud"), ("Pavo", 180, "g"), ("Queso", 30, "g"), ("Lechuga", 0.5, "ud"), ("Tomate", 1, "ud")]),
    ("Wrap de huevo", "egg wrap", [("Tortillas de trigo", 2, "ud"), ("Huevos", 3, "ud"), ("Espinaca", 40, "g"), ("Queso", 30, "g"), ("Aceite de oliva", 5, "ml"), ("Sal", 1, "cdita")]),
    ("Fajitas de pollo", "chicken fajitas", [("Tortillas de trigo", 4, "ud"), ("Pollo", 300, "g"), ("Pimiento", 2, "ud"), ("Cebolla", 1, "ud"), ("Comino", 1, "cdita"), ("Pimentón", 1, "cdita"), ("Aceite de oliva", 15, "ml"), ("Sal", 1, "cdita")]),
    ("Fajitas de ternera", "beef fajitas", [("Tortillas de trigo", 4, "ud"), ("Ternera", 300, "g"), ("Pimiento", 2, "ud"), ("Cebolla", 1, "ud"), ("Comino", 1, "cdita"), ("Aceite de oliva", 15, "ml"), ("Sal", 1, "cdita")]),
    ("Quesadilla de pollo", "chicken quesadilla", [("Tortillas de trigo", 2, "ud"), ("Pollo", 150, "g"), ("Queso", 60, "g"), ("Pimiento", 0.5, "ud")]),
    ("Quesadilla de verduras", "vegetable quesadilla", [("Tortillas de trigo", 2, "ud"), ("Calabacín", 0.5, "ud"), ("Pimiento", 0.5, "ud"), ("Queso", 60, "g"), ("Maíz", 40, "g")]),
]
for title, photo, items in WRAPS:
    add(title, "Mexicana", 20, "fácil", 2, photo, items, [
        "Cocina el relleno en una sartén y sazónalo.",
        "Reparte el relleno sobre las tortillas. Si es quesadilla, cierra y dórala por las dos caras.",
        "Dobla y sirve enseguida.",
    ])

CLASSICS = [
    ("Salmorejo", "Española", 15, "fácil", 4, "spanish salmorejo", [("Tomate", 8, "ud"), ("Pan", 100, "g"), ("Ajo", 1, "diente"), ("Aceite de oliva", 60, "ml"), ("Sal", 1, "cdita"), ("Huevos", 2, "ud"), ("Jamón", 40, "g")]),
    ("Ajoblanco", "Española", 15, "fácil", 4, "ajoblanco cold soup", [("Almendras", 150, "g"), ("Pan", 80, "g"), ("Ajo", 1, "diente"), ("Aceite de oliva", 50, "ml"), ("Vinagre", 15, "ml"), ("Agua", 400, "ml"), ("Sal", 1, "cdita"), ("Uvas", 80, "g")]),
    ("Pisto", "Española", 40, "media", 4, "spanish pisto", [("Calabacín", 2, "ud"), ("Berenjena", 1, "ud"), ("Pimiento", 2, "ud"), ("Tomate", 3, "ud"), ("Cebolla", 1, "ud"), ("Ajo", 2, "dientes"), ("Aceite de oliva", 30, "ml"), ("Sal", 1, "cdita")]),
    ("Escalivada", "Española", 45, "fácil", 4, "escalivada roasted vegetables", [("Berenjena", 2, "ud"), ("Pimiento", 2, "ud"), ("Cebolla", 2, "ud"), ("Aceite de oliva", 20, "ml"), ("Sal", 1, "cdita")]),
    ("Patatas bravas de casa", "Española", 35, "media", 4, "patatas bravas", [("Patata", 4, "ud"), ("Tomate frito", 150, "g"), ("Pimentón", 1, "cdita"), ("Guindilla", 1, "cdita"), ("Ajo", 1, "diente"), ("Aceite de oliva", 30, "ml"), ("Sal", 1, "cdita")]),
    ("Patatas a lo pobre", "Española", 35, "fácil", 4, "spanish poor potatoes", [("Patata", 4, "ud"), ("Pimiento", 1, "ud"), ("Cebolla", 1, "ud"), ("Aceite de oliva", 40, "ml"), ("Sal", 1, "cdita")]),
    ("Patatas panaderas", "Española", 50, "fácil", 4, "boulangere potatoes", [("Patata", 5, "ud"), ("Cebolla", 2, "ud"), ("Caldo", 200, "ml"), ("Aceite de oliva", 20, "ml"), ("Laurel", 1, "hoja"), ("Sal", 1, "cdita")]),
    ("Puré de patata", "Internacional", 25, "fácil", 4, "mashed potatoes", [("Patata", 4, "ud"), ("Leche", 80, "ml"), ("Mantequilla", 20, "g"), ("Sal", 1, "cdita"), ("Nuez moscada", 1, "cdita")]),
    ("Puré de boniato", "Internacional", 25, "fácil", 4, "mashed sweet potato", [("Boniato", 2, "ud"), ("Mantequilla", 15, "g"), ("Sal", 1, "cdita"), ("Pimienta", 1, "cdita")]),
    ("Sopa de ajo", "Española", 25, "fácil", 4, "spanish garlic soup", [("Pan", 4, "rebanadas"), ("Ajo", 4, "dientes"), ("Pimentón", 1, "cdita"), ("Huevos", 4, "ud"), ("Caldo", 800, "ml"), ("Aceite de oliva", 20, "ml"), ("Sal", 1, "cdita")]),
    ("Sopa de cebolla", "Francesa", 40, "media", 4, "french onion soup", [("Cebolla", 4, "ud"), ("Caldo", 800, "ml"), ("Pan", 4, "rebanadas"), ("Queso", 60, "g"), ("Aceite de oliva", 15, "ml"), ("Sal", 1, "cdita"), ("Tomillo", 1, "cdita")]),
    ("Sopa de tomate", "Internacional", 25, "fácil", 4, "tomato soup", [("Tomate", 6, "ud"), ("Cebolla", 1, "ud"), ("Caldo", 400, "ml"), ("Aceite de oliva", 15, "ml"), ("Sal", 1, "cdita"), ("Albahaca", 1, "manojo")]),
    ("Crema de champiñones", "Internacional", 30, "fácil", 4, "mushroom soup", [("Champiñones", 400, "g"), ("Cebolla", 1, "ud"), ("Patata", 1, "ud"), ("Caldo", 600, "ml"), ("Nata", 50, "ml"), ("Aceite de oliva", 15, "ml"), ("Sal", 1, "cdita")]),
    ("Vichyssoise", "Internacional", 35, "media", 4, "vichyssoise leek potato", [("Puerro", 2, "ud"), ("Patata", 3, "ud"), ("Caldo", 600, "ml"), ("Nata", 50, "ml"), ("Mantequilla", 15, "g"), ("Sal", 1, "cdita")]),
    ("Albóndigas en salsa", "Española", 40, "media", 4, "spanish meatballs", [("Carne picada", 400, "g"), ("Huevos", 1, "ud"), ("Pan rallado", 40, "g"), ("Ajo", 1, "diente"), ("Tomate frito", 250, "g"), ("Cebolla", 1, "ud"), ("Aceite de oliva", 20, "ml"), ("Sal", 1, "cdita")]),
    ("Albóndigas de pavo", "Internacional", 35, "media", 4, "turkey meatballs", [("Pavo", 400, "g"), ("Huevos", 1, "ud"), ("Pan rallado", 30, "g"), ("Perejil", 1, "manojo"), ("Tomate frito", 200, "g"), ("Aceite de oliva", 15, "ml"), ("Sal", 1, "cdita")]),
    ("Albóndigas de lentejas", "Internacional", 30, "media", 4, "lentil meatballs", [("Lentejas", 250, "g"), ("Huevos", 1, "ud"), ("Pan rallado", 30, "g"), ("Comino", 1, "cdita"), ("Tomate frito", 150, "g"), ("Aceite de oliva", 15, "ml"), ("Sal", 1, "cdita")]),
    ("Hamburguesa de ternera", "Internacional", 20, "fácil", 2, "beef burger", [("Carne picada", 300, "g"), ("Pan", 2, "ud"), ("Lechuga", 0.25, "ud"), ("Tomate", 1, "ud"), ("Cebolla", 0.5, "ud"), ("Sal", 1, "cdita"), ("Pimienta", 1, "cdita")]),
    ("Pizza casera", "Italiana", 40, "media", 4, "homemade pizza margherita", [("Harina", 250, "g"), ("Agua", 150, "ml"), ("Levadura", 5, "g"), ("Aceite de oliva", 15, "ml"), ("Tomate frito", 120, "g"), ("Mozzarella", 150, "g"), ("Sal", 1, "cdita"), ("Orégano", 1, "cdita")]),
    ("Pan de ajo", "Italiana", 15, "fácil", 4, "garlic bread", [("Pan", 1, "ud"), ("Mantequilla", 40, "g"), ("Ajo", 2, "dientes"), ("Perejil", 1, "manojo"), ("Sal", 1, "cdita")]),
    ("Migas", "Española", 25, "media", 4, "spanish migas breadcrumbs", [("Pan", 300, "g"), ("Ajo", 3, "dientes"), ("Pimiento", 1, "ud"), ("Chorizo", 80, "g"), ("Aceite de oliva", 40, "ml"), ("Sal", 1, "cdita"), ("Agua", 80, "ml")]),
    ("Croquetas de jamón", "Española", 45, "difícil", 4, "ham croquettes", [("Jamón", 80, "g"), ("Leche", 400, "ml"), ("Harina", 50, "g"), ("Mantequilla", 40, "g"), ("Huevos", 1, "ud"), ("Pan rallado", 60, "g"), ("Aceite de girasol", 25, "ml"), ("Sal", 1, "cdita")]),
    ("Croquetas de pollo", "Española", 45, "difícil", 4, "chicken croquettes", [("Pollo", 150, "g"), ("Leche", 400, "ml"), ("Harina", 50, "g"), ("Mantequilla", 40, "g"), ("Huevos", 1, "ud"), ("Pan rallado", 60, "g"), ("Aceite de girasol", 25, "ml"), ("Sal", 1, "cdita")]),
    ("Calamares a la romana", "Española", 25, "media", 4, "fried calamari", [("Calamares", 400, "g"), ("Harina", 80, "g"), ("Huevos", 1, "ud"), ("Aceite de girasol", 25, "ml"), ("Sal", 1, "cdita"), ("Limón", 1, "ud")]),
    ("Boquerones en vinagre", "Española", 20, "fácil", 4, "anchovies in vinegar", [("Boquerones", 400, "g"), ("Vinagre", 100, "ml"), ("Ajo", 2, "dientes"), ("Perejil", 1, "manojo"), ("Aceite de oliva", 30, "ml"), ("Sal", 1, "cdita")]),
    ("Pulpo con cachelos", "Española", 50, "media", 4, "galician octopus potatoes", [("Pulpo", 600, "g"), ("Patata", 4, "ud"), ("Pimentón", 1, "cdita"), ("Aceite de oliva", 20, "ml"), ("Sal", 1, "cdita")]),
    ("Gambas al ajillo", "Española", 15, "fácil", 2, "garlic prawns", [("Gambas", 300, "g"), ("Ajo", 4, "dientes"), ("Guindilla", 1, "cdita"), ("Aceite de oliva", 40, "ml"), ("Sal", 1, "cdita"), ("Perejil", 1, "manojo")]),
    ("Mejillones al vapor", "Española", 15, "fácil", 2, "steamed mussels", [("Mejillones", 800, "g"), ("Ajo", 2, "dientes"), ("Vino blanco", 50, "ml"), ("Perejil", 1, "manojo"), ("Aceite de oliva", 10, "ml")]),
    ("Mejillones en salsa", "Española", 25, "media", 2, "mussels tomato sauce", [("Mejillones", 800, "g"), ("Tomate frito", 150, "g"), ("Cebolla", 1, "ud"), ("Ajo", 1, "diente"), ("Aceite de oliva", 15, "ml"), ("Sal", 1, "cdita")]),
    ("Bacalao al pil pil", "Española", 30, "difícil", 2, "basque cod pil pil", [("Bacalao", 400, "g"), ("Ajo", 4, "dientes"), ("Guindilla", 1, "cdita"), ("Aceite de oliva", 120, "ml")]),
    ("Merluza en salsa verde", "Española", 25, "media", 2, "hake green sauce", [("Merluza", 400, "g"), ("Ajo", 2, "dientes"), ("Perejil", 1, "manojo"), ("Caldo", 80, "ml"), ("Aceite de oliva", 30, "ml"), ("Sal", 1, "cdita")]),
    ("Sardinas a la plancha", "Española", 15, "fácil", 2, "grilled sardines", [("Sardinas", 400, "g"), ("Sal", 1, "cdita"), ("Aceite de oliva", 10, "ml"), ("Limón", 1, "ud"), ("Perejil", 1, "manojo")]),
    ("Atún encebollado", "Española", 30, "media", 2, "tuna with onions", [("Atún", 350, "g"), ("Cebolla", 2, "ud"), ("Vino blanco", 40, "ml"), ("Aceite de oliva", 20, "ml"), ("Sal", 1, "cdita"), ("Pimienta", 1, "cdita")]),
    ("Pollo asado", "Española", 70, "media", 4, "roast chicken", [("Pollo", 1000, "g"), ("Patata", 3, "ud"), ("Limón", 1, "ud"), ("Ajo", 3, "dientes"), ("Romero", 1, "cdita"), ("Aceite de oliva", 20, "ml"), ("Sal", 1, "cdita")]),
    ("Pollo al curry", "Asiática", 30, "media", 4, "chicken curry", [("Pollo", 500, "g"), ("Cebolla", 1, "ud"), ("Tomate frito", 200, "g"), ("Yogur", 80, "g"), ("Curry", 2, "cdita"), ("Jengibre", 10, "g"), ("Ajo", 2, "dientes"), ("Aceite de oliva", 15, "ml"), ("Sal", 1, "cdita")]),
    ("Pollo a la nata", "Internacional", 30, "media", 4, "chicken cream sauce", [("Pollo", 500, "g"), ("Champiñones", 150, "g"), ("Nata", 150, "ml"), ("Ajo", 1, "diente"), ("Aceite de oliva", 10, "ml"), ("Sal", 1, "cdita"), ("Pimienta", 1, "cdita")]),
    ("Cerdo agridulce", "Asiática", 25, "media", 2, "sweet sour pork", [("Cerdo", 350, "g"), ("Pimiento", 1, "ud"), ("Piña", 100, "g"), ("Salsa de soja", 20, "ml"), ("Miel", 15, "ml"), ("Vinagre", 10, "ml"), ("Aceite de girasol", 15, "ml")]),
    ("Ternera encebollada", "Española", 40, "media", 4, "beef and onions", [("Ternera", 400, "g"), ("Cebolla", 3, "ud"), ("Vino blanco", 50, "ml"), ("Aceite de oliva", 15, "ml"), ("Sal", 1, "cdita"), ("Pimienta", 1, "cdita")]),
    ("Estofado de ternera", "Española", 80, "media", 4, "beef stew", [("Ternera", 500, "g"), ("Patata", 2, "ud"), ("Zanahoria", 2, "ud"), ("Cebolla", 1, "ud"), ("Vino tinto", 100, "ml"), ("Caldo", 300, "ml"), ("Laurel", 1, "hoja"), ("Aceite de oliva", 15, "ml"), ("Sal", 1, "cdita")]),
    ("Cordero al horno", "Española", 70, "media", 4, "roast lamb", [("Cordero", 700, "g"), ("Patata", 3, "ud"), ("Ajo", 3, "dientes"), ("Vino blanco", 50, "ml"), ("Romero", 1, "cdita"), ("Aceite de oliva", 15, "ml"), ("Sal", 1, "cdita")]),
    ("Conejo al ajillo", "Española", 40, "media", 4, "garlic rabbit", [("Conejo", 600, "g"), ("Ajo", 6, "dientes"), ("Vino blanco", 50, "ml"), ("Aceite de oliva", 20, "ml"), ("Sal", 1, "cdita"), ("Perejil", 1, "manojo")]),
    ("Chili con carne", "Mexicana", 45, "media", 4, "chili con carne", [("Carne picada", 400, "g"), ("Alubias", 250, "g"), ("Tomate frito", 250, "g"), ("Cebolla", 1, "ud"), ("Pimiento", 1, "ud"), ("Comino", 1, "cdita"), ("Pimentón", 1, "cdita"), ("Guindilla", 1, "cdita"), ("Aceite de oliva", 15, "ml"), ("Sal", 1, "cdita")]),
    ("Chili de alubias", "Mexicana", 40, "fácil", 4, "vegetarian chili", [("Alubias", 300, "g"), ("Maíz", 100, "g"), ("Tomate frito", 250, "g"), ("Pimiento", 1, "ud"), ("Cebolla", 1, "ud"), ("Comino", 1, "cdita"), ("Pimentón", 1, "cdita"), ("Aceite de oliva", 15, "ml"), ("Sal", 1, "cdita")]),
    ("Berenjenas rellenas", "Mediterránea", 45, "media", 4, "stuffed eggplant", [("Berenjena", 2, "ud"), ("Carne picada", 200, "g"), ("Tomate frito", 150, "g"), ("Cebolla", 1, "ud"), ("Queso", 40, "g"), ("Aceite de oliva", 15, "ml"), ("Sal", 1, "cdita")]),
    ("Calabacines rellenos", "Mediterránea", 40, "media", 4, "stuffed zucchini", [("Calabacín", 3, "ud"), ("Pavo", 200, "g"), ("Tomate frito", 100, "g"), ("Cebolla", 0.5, "ud"), ("Queso", 30, "g"), ("Aceite de oliva", 10, "ml"), ("Sal", 1, "cdita")]),
    ("Pimientos rellenos", "Española", 45, "media", 4, "stuffed peppers", [("Pimiento", 4, "ud"), ("Carne picada", 250, "g"), ("Arroz", 80, "g"), ("Tomate frito", 150, "g"), ("Cebolla", 1, "ud"), ("Aceite de oliva", 15, "ml"), ("Sal", 1, "cdita")]),
    ("Tomates rellenos", "Mediterránea", 30, "fácil", 4, "stuffed tomatoes", [("Tomate", 4, "ud"), ("Atún", 120, "g"), ("Arroz", 80, "g"), ("Cebolla", 0.5, "ud"), ("Aceite de oliva", 10, "ml"), ("Sal", 1, "cdita"), ("Perejil", 1, "manojo")]),
    ("Champiñones rellenos", "Internacional", 25, "fácil", 2, "stuffed mushrooms", [("Champiñones", 300, "g"), ("Jamón", 40, "g"), ("Ajo", 1, "diente"), ("Queso", 40, "g"), ("Perejil", 1, "manojo"), ("Aceite de oliva", 10, "ml"), ("Sal", 1, "cdita")]),
    ("Boniatos rellenos", "Internacional", 45, "fácil", 2, "stuffed sweet potato", [("Boniato", 2, "ud"), ("Garbanzos", 100, "g"), ("Espinaca", 50, "g"), ("Yogur", 40, "g"), ("Comino", 1, "cdita"), ("Sal", 1, "cdita")]),
    ("Col rellena", "Internacional", 50, "media", 4, "stuffed cabbage", [("Col", 1, "ud"), ("Carne picada", 300, "g"), ("Arroz", 80, "g"), ("Tomate frito", 200, "g"), ("Cebolla", 1, "ud"), ("Aceite de oliva", 15, "ml"), ("Sal", 1, "cdita")]),
    ("Lasaña de verduras", "Italiana", 45, "media", 4, "vegetable lasagna", [("Pasta", 200, "g"), ("Calabacín", 1, "ud"), ("Berenjena", 1, "ud"), ("Tomate frito", 250, "g"), ("Queso", 80, "g"), ("Aceite de oliva", 15, "ml"), ("Sal", 1, "cdita")]),
    ("Musaka", "Mediterránea", 60, "difícil", 6, "moussaka", [("Berenjena", 2, "ud"), ("Carne picada", 400, "g"), ("Patata", 2, "ud"), ("Tomate frito", 200, "g"), ("Leche", 300, "ml"), ("Harina", 30, "g"), ("Mantequilla", 30, "g"), ("Queso", 40, "g"), ("Sal", 1, "cdita")]),
    ("Quiche de verduras", "Francesa", 45, "media", 4, "vegetable quiche", [("Harina", 150, "g"), ("Mantequilla", 70, "g"), ("Huevos", 3, "ud"), ("Nata", 150, "ml"), ("Calabacín", 1, "ud"), ("Queso", 40, "g"), ("Sal", 1, "cdita")]),
    ("Pastel de carne", "Internacional", 50, "media", 4, "meatloaf", [("Carne picada", 500, "g"), ("Huevos", 1, "ud"), ("Pan rallado", 40, "g"), ("Cebolla", 1, "ud"), ("Tomate frito", 80, "g"), ("Sal", 1, "cdita"), ("Pimienta", 1, "cdita")]),
    ("Pastel de merluza", "Española", 40, "media", 4, "fish pie hake", [("Merluza", 400, "g"), ("Patata", 3, "ud"), ("Leche", 80, "ml"), ("Mantequilla", 20, "g"), ("Huevos", 1, "ud"), ("Sal", 1, "cdita")]),
    ("Brandada de bacalao", "Mediterránea", 30, "media", 4, "brandade salt cod", [("Bacalao", 300, "g"), ("Patata", 2, "ud"), ("Ajo", 1, "diente"), ("Aceite de oliva", 40, "ml"), ("Leche", 40, "ml")]),
    ("Ceviche de pescado", "Internacional", 20, "fácil", 2, "fish ceviche", [("Merluza", 300, "g"), ("Limón", 3, "ud"), ("Cebolla", 0.5, "ud"), ("Tomate", 1, "ud"), ("Sal", 1, "cdita"), ("Guindilla", 1, "cdita", True)]),
    ("Escabeche de caballa" if False else "Escabeche de sardinas", "Española", 30, "media", 4, "marinated sardines", [("Sardinas", 400, "g"), ("Vinagre", 80, "ml"), ("Aceite de oliva", 40, "ml"), ("Ajo", 2, "dientes"), ("Laurel", 1, "hoja"), ("Pimentón", 1, "cdita"), ("Sal", 1, "cdita")]),
    ("Salmón al horno con limón", "Internacional", 25, "fácil", 2, "baked salmon lemon", [("Salmón", 350, "g"), ("Limón", 1, "ud"), ("Aceite de oliva", 10, "ml"), ("Sal", 1, "cdita"), ("Pimienta", 1, "cdita"), ("Ajo", 1, "diente")]),
    ("Salmón a la soja", "Asiática", 20, "fácil", 2, "soy glazed salmon", [("Salmón", 350, "g"), ("Salsa de soja", 20, "ml"), ("Miel", 10, "ml"), ("Jengibre", 8, "g"), ("Ajo", 1, "diente")]),
    ("Trucha a la navarra", "Española", 25, "media", 2, "trout with ham", [("Trucha", 2, "ud"), ("Jamón", 40, "g"), ("Aceite de oliva", 20, "ml"), ("Ajo", 1, "diente"), ("Sal", 1, "cdita")]),
    ("Dorada a la sal", "Española", 40, "media", 2, "fish baked in salt", [("Dorada", 600, "g"), ("Sal", 800, "g"), ("Limón", 1, "ud"), ("Perejil", 1, "manojo")]),
    ("Lubina al horno", "Mediterránea", 30, "fácil", 2, "baked sea bass", [("Lubina", 600, "g"), ("Patata", 2, "ud"), ("Limón", 1, "ud"), ("Aceite de oliva", 15, "ml"), ("Sal", 1, "cdita"), ("Romero", 1, "cdita")]),
    ("Pisto con huevo", "Española", 40, "media", 2, "pisto with egg", [("Calabacín", 1, "ud"), ("Pimiento", 1, "ud"), ("Tomate", 2, "ud"), ("Cebolla", 1, "ud"), ("Huevos", 2, "ud"), ("Aceite de oliva", 20, "ml"), ("Sal", 1, "cdita")]),
    ("Shakshuka de casa", "Internacional", 25, "fácil", 2, "shakshuka eggs", [("Huevos", 4, "ud"), ("Tomate frito", 300, "g"), ("Pimiento", 1, "ud"), ("Cebolla", 1, "ud"), ("Comino", 1, "cdita"), ("Pimentón", 1, "cdita"), ("Aceite de oliva", 15, "ml"), ("Sal", 1, "cdita")]),
    ("Guisantes con jamón", "Española", 15, "fácil", 2, "peas with ham", [("Guisantes", 300, "g"), ("Jamón", 50, "g"), ("Cebolla", 0.5, "ud"), ("Huevos", 2, "ud", True), ("Aceite de oliva", 10, "ml"), ("Sal", 1, "cdita")]),
    ("Judías verdes con jamón", "Española", 20, "fácil", 2, "green beans ham", [("Judías verdes", 400, "g"), ("Jamón", 50, "g"), ("Ajo", 1, "diente"), ("Aceite de oliva", 15, "ml"), ("Sal", 1, "cdita")]),
    ("Menestra", "Española", 30, "media", 4, "spanish vegetable stew", [("Alcachofa", 2, "ud"), ("Guisantes", 100, "g"), ("Judías verdes", 150, "g"), ("Zanahoria", 1, "ud"), ("Espárragos", 100, "g"), ("Huevos", 2, "ud"), ("Aceite de oliva", 15, "ml"), ("Sal", 1, "cdita")]),
    ("Baba ganoush", "Mediterránea", 40, "fácil", 4, "baba ganoush", [("Berenjena", 2, "ud"), ("Ajo", 1, "diente"), ("Limón", 1, "ud"), ("Aceite de oliva", 20, "ml"), ("Comino", 1, "cdita"), ("Sal", 1, "cdita")]),
    ("Paté de atún", "Internacional", 10, "fácil", 4, "tuna pate", [("Atún", 160, "g"), ("Queso", 60, "g"), ("Limón", 0.5, "ud"), ("Aceite de oliva", 10, "ml"), ("Sal", 1, "cdita")]),
    ("Sopa fría de pepino", "Internacional", 15, "fácil", 4, "cold cucumber soup", [("Pepino", 2, "ud"), ("Yogur", 250, "g"), ("Ajo", 1, "diente"), ("Aceite de oliva", 10, "ml"), ("Eneldo" if False else "Perejil", 1, "manojo"), ("Sal", 1, "cdita")]),
    ("Gazpacho de sandía", "Española", 15, "fácil", 4, "watermelon gazpacho", [("Sandía", 400, "g"), ("Tomate", 2, "ud"), ("Pepino", 0.5, "ud"), ("Aceite de oliva", 15, "ml"), ("Vinagre", 10, "ml"), ("Sal", 1, "cdita")]),
    ("Brochetas de pollo", "Internacional", 25, "fácil", 2, "chicken skewers", [("Pollo", 350, "g"), ("Pimiento", 1, "ud"), ("Cebolla", 1, "ud"), ("Aceite de oliva", 15, "ml"), ("Pimentón", 1, "cdita"), ("Sal", 1, "cdita")]),
    ("Brochetas de verdura", "Mediterránea", 25, "fácil", 2, "vegetable skewers", [("Calabacín", 1, "ud"), ("Pimiento", 1, "ud"), ("Champiñones", 150, "g"), ("Cebolla", 1, "ud"), ("Aceite de oliva", 15, "ml"), ("Sal", 1, "cdita"), ("Tomillo", 1, "cdita")]),
    ("Brochetas de fruta", "Internacional", 10, "fácil", 2, "fruit skewers", [("Fresa", 80, "g"), ("Melón", 100, "g"), ("Piña", 80, "g"), ("Uvas", 80, "g")]),
    ("Tofu a la plancha", "Asiática", 15, "fácil", 2, "grilled tofu", [("Tofu", 300, "g"), ("Salsa de soja", 15, "ml"), ("Aceite de oliva", 10, "ml"), ("Jengibre", 8, "g"), ("Ajo", 1, "diente")]),
    ("Tofu al curry", "Asiática", 25, "fácil", 2, "tofu curry", [("Tofu", 300, "g"), ("Curry", 2, "cdita"), ("Tomate frito", 150, "g"), ("Cebolla", 1, "ud"), ("Leche", 100, "ml"), ("Aceite de oliva", 10, "ml"), ("Sal", 1, "cdita")]),
    ("Wok de verduras", "Asiática", 15, "fácil", 2, "vegetable stir fry", [("Brócoli", 150, "g"), ("Pimiento", 1, "ud"), ("Zanahoria", 1, "ud"), ("Champiñones", 100, "g"), ("Salsa de soja", 15, "ml"), ("Jengibre", 8, "g"), ("Aceite de girasol", 15, "ml")]),
    ("Wok de pollo", "Asiática", 20, "fácil", 2, "chicken stir fry", [("Pollo", 300, "g"), ("Pimiento", 1, "ud"), ("Brócoli", 150, "g"), ("Salsa de soja", 15, "ml"), ("Jengibre", 8, "g"), ("Ajo", 1, "diente"), ("Aceite de girasol", 15, "ml")]),
    ("Wok de gambas", "Asiática", 15, "fácil", 2, "prawn stir fry", [("Gambas", 250, "g"), ("Pimiento", 1, "ud"), ("Calabacín", 1, "ud"), ("Salsa de soja", 15, "ml"), ("Ajo", 1, "diente"), ("Aceite de girasol", 10, "ml")]),
    ("Fideos de verdura" if False else "Pasta salteada con verduras", "Asiática", 20, "fácil", 2, "stir fried noodles vegetables", [("Pasta", 200, "g"), ("Pimiento", 1, "ud"), ("Zanahoria", 1, "ud"), ("Col", 100, "g"), ("Salsa de soja", 20, "ml"), ("Aceite de girasol", 15, "ml"), ("Jengibre", 8, "g")]),
    ("Pasta salteada con pollo", "Asiática", 20, "fácil", 2, "stir fried noodles chicken", [("Pasta", 200, "g"), ("Pollo", 200, "g"), ("Pimiento", 1, "ud"), ("Salsa de soja", 20, "ml"), ("Ajo", 1, "diente"), ("Aceite de girasol", 15, "ml")]),
    ("Bocadillo de tortilla", "Española", 10, "fácil", 1, "spanish omelette sandwich", [("Pan", 1, "ud"), ("Huevos", 2, "ud"), ("Patata", 1, "ud"), ("Aceite de oliva", 20, "ml"), ("Sal", 1, "cdita")]),
    ("Bocadillo de atún", "Española", 10, "fácil", 1, "tuna sandwich", [("Pan", 1, "ud"), ("Atún", 80, "g"), ("Tomate", 1, "ud"), ("Aceite de oliva", 5, "ml")]),
    ("Bocadillo de jamón", "Española", 5, "fácil", 1, "serrano ham sandwich", [("Pan", 1, "ud"), ("Jamón", 50, "g"), ("Tomate", 1, "ud"), ("Aceite de oliva", 5, "ml")]),
    ("Sándwich de pollo", "Internacional", 15, "fácil", 1, "chicken sandwich", [("Pan", 2, "rebanadas"), ("Pollo", 100, "g"), ("Lechuga", 0.25, "ud"), ("Tomate", 0.5, "ud"), ("Mayonesa", 15, "g")]),
    ("Sándwich de pavo y queso", "Internacional", 10, "fácil", 1, "turkey cheese sandwich", [("Pan", 2, "rebanadas"), ("Pavo", 80, "g"), ("Queso", 30, "g"), ("Lechuga", 0.25, "ud")]),
    ("Emparedado de huevo", "Internacional", 10, "fácil", 1, "egg sandwich", [("Pan", 2, "rebanadas"), ("Huevos", 2, "ud"), ("Mayonesa", 15, "g"), ("Sal", 1, "cdita")]),
    ("Pollo empanado", "Internacional", 25, "media", 2, "breaded chicken", [("Pollo", 350, "g"), ("Huevos", 1, "ud"), ("Harina", 40, "g"), ("Pan rallado", 50, "g"), ("Aceite de girasol", 40, "ml"), ("Sal", 1, "cdita")]),
    ("Merluza empanada", "Española", 25, "media", 2, "breaded hake", [("Merluza", 350, "g"), ("Huevos", 1, "ud"), ("Harina", 40, "g"), ("Pan rallado", 50, "g"), ("Aceite de girasol", 40, "ml"), ("Sal", 1, "cdita"), ("Limón", 1, "ud")]),
    ("Berenjena empanada", "Internacional", 25, "media", 2, "breaded eggplant", [("Berenjena", 1, "ud"), ("Huevos", 1, "ud"), ("Harina", 40, "g"), ("Pan rallado", 50, "g"), ("Aceite de girasol", 40, "ml"), ("Sal", 1, "cdita")]),
    ("San jacobos", "Española", 20, "fácil", 2, "ham cheese cutlet", [("Cerdo", 250, "g"), ("Jamón cocido", 40, "g"), ("Queso", 40, "g"), ("Huevos", 1, "ud"), ("Pan rallado", 40, "g"), ("Aceite de girasol", 30, "ml"), ("Sal", 1, "cdita")]),
    ("Pimientos del piquillo" if False else "Pimientos asados", "Española", 30, "fácil", 4, "roasted red peppers", [("Pimiento", 4, "ud"), ("Ajo", 1, "diente"), ("Aceite de oliva", 20, "ml"), ("Sal", 1, "cdita")]),
    ("Coliflor con bechamel", "Española", 35, "media", 4, "cauliflower cheese", [("Coliflor", 1, "ud"), ("Leche", 300, "ml"), ("Harina", 25, "g"), ("Mantequilla", 25, "g"), ("Queso", 30, "g"), ("Sal", 1, "cdita"), ("Nuez moscada", 1, "cdita")]),
    ("Brócoli gratinado", "Internacional", 25, "fácil", 2, "broccoli cheese", [("Brócoli", 400, "g"), ("Queso", 50, "g"), ("Nata", 50, "ml"), ("Ajo", 1, "diente"), ("Sal", 1, "cdita")]),
    ("Espinacas con garbanzos", "Española", 25, "fácil", 4, "spinach chickpeas", [("Espinaca", 200, "g"), ("Garbanzos", 250, "g"), ("Ajo", 2, "dientes"), ("Pimentón", 1, "cdita"), ("Comino", 1, "cdita"), ("Pan", 30, "g"), ("Aceite de oliva", 20, "ml"), ("Sal", 1, "cdita")]),
    ("Acelgas" if False else "Espinacas a la crema", "Internacional", 15, "fácil", 2, "creamed spinach", [("Espinaca", 250, "g"), ("Nata", 80, "ml"), ("Ajo", 1, "diente"), ("Sal", 1, "cdita"), ("Nuez moscada", 1, "cdita")]),
    ("Alcachofas con jamón", "Española", 25, "media", 2, "artichokes ham", [("Alcachofa", 4, "ud"), ("Jamón", 40, "g"), ("Ajo", 1, "diente"), ("Aceite de oliva", 15, "ml"), ("Sal", 1, "cdita")]),
    ("Alcachofas a la plancha", "Mediterránea", 20, "fácil", 2, "grilled artichokes", [("Alcachofa", 4, "ud"), ("Limón", 1, "ud"), ("Aceite de oliva", 15, "ml"), ("Sal", 1, "cdita")]),
    ("Espárragos a la plancha", "Mediterránea", 12, "fácil", 2, "grilled asparagus", [("Espárragos", 300, "g"), ("Aceite de oliva", 10, "ml"), ("Sal", 1, "cdita"), ("Limón", 0.5, "ud")]),
    ("Espárragos con mayonesa", "Española", 15, "fácil", 2, "asparagus mayonnaise", [("Espárragos", 300, "g"), ("Mayonesa", 40, "g"), ("Huevos", 1, "ud"), ("Sal", 1, "cdita")]),
    ("Maíz salteado", "Mexicana", 10, "fácil", 2, "sauteed corn", [("Maíz", 250, "g"), ("Mantequilla", 15, "g"), ("Sal", 1, "cdita"), ("Pimentón", 1, "cdita")]),
    ("Guacamole con nachos" if False else "Guacamole casero", "Mexicana", 10, "fácil", 2, "homemade guacamole", [("Aguacate", 2, "ud"), ("Tomate", 1, "ud"), ("Cebolla", 0.25, "ud"), ("Limón", 1, "ud"), ("Sal", 1, "cdita")]),
    ("Pico de gallo", "Mexicana", 10, "fácil", 4, "pico de gallo", [("Tomate", 3, "ud"), ("Cebolla", 0.5, "ud"), ("Limón", 1, "ud"), ("Sal", 1, "cdita"), ("Guindilla", 1, "cdita", True)]),
    ("Salsa de yogur", "Mediterránea", 5, "fácil", 4, "yogurt sauce", [("Yogur", 200, "g"), ("Ajo", 1, "diente"), ("Limón", 0.5, "ud"), ("Aceite de oliva", 10, "ml"), ("Sal", 1, "cdita"), ("Perejil", 1, "manojo")]),
    ("Salsa de tomate casera", "Italiana", 30, "fácil", 4, "homemade tomato sauce", [("Tomate", 6, "ud"), ("Cebolla", 1, "ud"), ("Ajo", 2, "dientes"), ("Aceite de oliva", 20, "ml"), ("Sal", 1, "cdita"), ("Albahaca", 1, "manojo"), ("Azúcar", 5, "g", True)]),
    ("Bechamel", "Francesa", 15, "media", 4, "bechamel sauce", [("Leche", 400, "ml"), ("Harina", 30, "g"), ("Mantequilla", 30, "g"), ("Sal", 1, "cdita"), ("Nuez moscada", 1, "cdita")]),
    ("Mayonesa casera", "Internacional", 10, "media", 4, "homemade mayonnaise", [("Huevos", 1, "ud"), ("Aceite de girasol", 150, "ml"), ("Limón", 0.5, "ud"), ("Sal", 1, "cdita")]),
    ("Vinagreta", "Internacional", 5, "fácil", 4, "vinaigrette", [("Aceite de oliva", 60, "ml"), ("Vinagre", 20, "ml"), ("Sal", 1, "cdita"), ("Mostaza", 1, "cdita"), ("Pimienta", 1, "cdita")]),
    ("Café con leche", "Española", 5, "fácil", 1, "cafe con leche", [("Café", 40, "ml"), ("Leche", 120, "ml"), ("Azúcar", 5, "g", True)]),
    ("Cacao caliente", "Internacional", 8, "fácil", 1, "hot cocoa", [("Leche", 250, "ml"), ("Cacao", 15, "g"), ("Azúcar", 10, "g")]),
    ("Batido de mango", "Internacional", 5, "fácil", 1, "mango smoothie", [("Mango", 1, "ud"), ("Yogur", 150, "g"), ("Leche", 80, "ml")]),
    ("Batido de melocotón", "Internacional", 5, "fácil", 1, "peach smoothie", [("Melocotón", 2, "ud"), ("Yogur", 150, "g"), ("Miel", 10, "ml")]),
    ("Yogur con kiwi", "Internacional", 5, "fácil", 1, "kiwi yogurt", [("Yogur", 200, "g"), ("Kiwi", 2, "ud"), ("Miel", 10, "ml")]),
    ("Yogur con nueces", "Internacional", 5, "fácil", 1, "yogurt walnuts", [("Yogur", 200, "g"), ("Nueces", 20, "g"), ("Miel", 10, "ml")]),
    ("Ensalada de melón y jamón", "Española", 10, "fácil", 2, "melon serrano ham", [("Melón", 300, "g"), ("Jamón", 60, "g")]),
    ("Sandía con queso", "Internacional", 5, "fácil", 2, "watermelon cheese", [("Sandía", 300, "g"), ("Queso", 60, "g"), ("Menta" if False else "Albahaca", 4, "hoja")]),
    ("Uvas con queso", "Internacional", 5, "fácil", 2, "grapes cheese", [("Uvas", 150, "g"), ("Queso", 60, "g"), ("Nueces", 15, "g")]),
    ("Tostada de plátano y cacao", "Internacional", 8, "fácil", 1, "banana cocoa toast", [("Pan", 2, "rebanadas"), ("Plátano", 1, "ud"), ("Cacao", 5, "g"), ("Miel", 10, "ml")]),
    ("Gachas de avena saladas", "Internacional", 12, "fácil", 1, "savory oatmeal", [("Avena", 50, "g"), ("Caldo", 200, "ml"), ("Huevos", 1, "ud"), ("Queso", 20, "g"), ("Sal", 1, "cdita")]),
]
for row in CLASSICS:
    title, cuisine, minutes, difficulty, servings, photo, items = row
    add(title, cuisine, minutes, difficulty, servings, photo, items, [
        f"Prepara y corta los ingredientes de {title.lower()}.",
        "Cocina a fuego medio, o en el horno si el plato es asado o gratinado, hasta el punto justo.",
        "Prueba de sal, deja reposar un minuto si está muy caliente y sirve.",
    ], f"{title}, receta de casa.")

# Más variaciones de pescado en papillote y carnes guisadas, títulos únicos.
PAPILLOTE = ["Salmón", "Merluza", "Bacalao", "Trucha", "Dorada", "Lubina"]
for name in PAPILLOTE:
    spoken = next(s for n, s, *_ in PROTEINS if n == name)
    add(
        f"{name} en papillote",
        "Mediterránea", 25, "fácil", 2,
        f"{name.lower()} en papillote baked",
        [(name, 350, "g"), ("Limón", 1, "ud"), ("Pimiento", 1, "ud"), ("Calabacín", 1, "ud"), *base_season()],
        [
            "Calienta el horno a 190 °C.",
            f"Pon {spoken} sobre papel de horno con la verdura, el limón, aceite, sal y pimienta. Cierra el paquete.",
            "Hornea 18 minutos y abre el paquete en la mesa.",
        ],
        f"{name} al vapor dentro de un paquete, con verdura.",
    )

CURRY_NAMES = ["Pollo", "Pavo", "Gambas", "Tofu", "Garbanzos", "Coliflor", "Boniato", "Lentejas"]
# Pollo al curry and garbanzos/lentejas/tofu already exist. Skip seen.
for name in CURRY_NAMES:
    title = f"Curry de {name.lower()}"
    if title in seen or f"{name} al curry" in seen:
        continue
    unit = "g"
    qty = 200 if name in {"Garbanzos", "Lentejas"} else 350
    add(
        title,
        "Asiática", 30, "media", 4,
        f"{name.lower()} curry",
        [(name, qty, unit), ("Cebolla", 1, "ud"), ("Tomate frito", 180, "g"), ("Yogur", 60, "g"), ("Curry", 2, "cdita"), ("Jengibre", 10, "g"), ("Ajo", 1, "diente"), *base_season()],
        [
            "Sofríe la cebolla, el ajo y el jengibre.",
            f"Añade el curry, {name.lower()}, el tomate y un poco de agua.",
            "Cocina hasta que esté tierno y liga con el yogur fuera del fuego.",
        ],
    )

GUISOS = ["Ternera", "Cerdo", "Pollo", "Conejo", "Cordero", "Pavo", "Bacalao", "Pulpo"]
for name in GUISOS:
    title = f"Guiso de {name.lower()}"
    if title in seen:
        continue
    wine = "Vino tinto" if name in MEAT else "Vino blanco"
    add(
        title,
        "Española", 60, "media", 4,
        f"{name.lower()} stew",
        [(name, 500, "g"), ("Cebolla", 1, "ud"), ("Zanahoria", 2, "ud"), ("Patata", 2, "ud"), (wine, 80, "ml"), ("Caldo", 300, "ml"), ("Laurel", 1, "hoja"), *base_season()],
        [
            f"Dora el {name.lower()} en el aceite y retíralo.",
            "Sofríe la cebolla y la zanahoria, devuelve la pieza, añade el vino y deja evaporar.",
            "Cubre con el caldo, añade la patata y el laurel, y cocina tapado hasta que esté tierno.",
        ],
    )

# Fruta simple para llegar al volumen sin platos absurdos.
FRUITS = [
    ("Naranja", "naranja", "orange slices", 2, "ud"),
    ("Manzana", "manzana", "apple slices", 2, "ud"),
    ("Pera", "pera", "pear slices", 2, "ud"),
    ("Melocotón", "melocotón", "peach slices", 2, "ud"),
    ("Piña", "piña", "pineapple", 200, "g"),
    ("Mango", "mango", "mango", 1, "ud"),
    ("Kiwi", "kiwi", "kiwi fruit", 3, "ud"),
    ("Sandía", "sandía", "watermelon slices", 300, "g"),
    ("Melón", "melón", "melon slices", 300, "g"),
    ("Uvas", "uvas", "grapes", 200, "g"),
    ("Fresa", "fresas", "strawberries", 200, "g"),
    ("Plátano", "plátano", "banana", 2, "ud"),
]
for name, spoken, photo, qty, unit in FRUITS:
    add(
        f"{name} con yogur y miel",
        "Internacional", 5, "fácil", 1,
        f"{photo} yogurt",
        [(name, qty, unit), ("Yogur", 180, "g"), ("Miel", 10, "ml")],
        [
            f"Lava y trocea el {spoken}.",
            "Sirve el yogur en un bol y reparte la fruta.",
            "Termina con la miel.",
        ],
        f"Desayuno o postre de {spoken} con yogur.",
    )
    if name not in {"Sandía", "Melón", "Uvas", "Fresa"}:
        add(
            f"{name} asada con canela",
            "Internacional", 20, "fácil", 2,
            f"baked {photo}",
            [(name, qty if unit == "g" else qty + 1, unit), ("Canela", 1, "cdita"), ("Miel", 15, "ml"), ("Mantequilla", 10, "g")],
            [
                "Calienta el horno a 180 °C.",
                f"Parte el {spoken}, ponle mantequilla, miel y canela.",
                "Hornea hasta que esté blando y los bordes, dorados.",
            ],
        )

# Rellenar hasta pasar de 500 con salteados de una verdura y una proteína concreta que aún no existan.
EXTRAS = []
for veg, spoken_v, photo_v in VEGS:
    if veg in {"Patata"}:
        continue
    for prot in ("Pollo", "Pavo", "Tofu", "Gambas", "Huevos"):
        title = f"{veg} con {prot.lower()}"
        if title in seen:
            continue
        EXTRAS.append((title, veg, prot, photo_v))

for title, veg, prot, photo_v in EXTRAS:
    if len(recipes) >= 520:
        break
    unit, qty = ("ud", 1) if veg in PIECE_G else ("g", 300)
    pqty = 2 if prot == "Huevos" else 200
    punit = "ud" if prot == "Huevos" else "g"
    add(
        title,
        "Internacional", 20, "fácil", 2,
        f"{photo_v} with {prot.lower()}",
        [(veg, qty, unit), (prot, pqty, punit), ("Ajo", 1, "diente"), *base_season()],
        [
            f"Corta el {veg.lower()} y dóralo con el ajo.",
            f"Añade el {prot.lower()} y cocina hasta que esté hecho.",
            "Salpimenta y sirve caliente.",
        ],
        f"Plato rápido de {veg.lower()} y {prot.lower()}.",
    )

if len(recipes) < 500:
    raise SystemExit(f"solo {len(recipes)} recetas")

# Quitar títulos que ya viven en RECIPE_SEEDS para no duplicar el texto,
# pero conservar una ficha mínima de foto para que el sync les ponga imagen.
EXISTING = {
    "Tortilla de patatas", "Ensalada mixta", "Pasta al pesto", "Arroz con pollo",
    "Gazpacho", "Huevos revueltos", "Guacamole", "Lentejas estofadas",
    "Pan con tomate", "Yogur con fruta",
}
photo_only = []
# Las 10 de siempre no están en este generador salvo solapes de título.
# Si alguna coincidiera, se queda: el sync no la reinserta.

OUT.write_text(json.dumps(recipes, ensure_ascii=False, indent=2) + "\n")
print(f"{len(recipes)} recetas -> {OUT}")
from collections import Counter
print(Counter(r["cuisine"] for r in recipes))
print("dietas", Counter(t for r in recipes for t in r["dietTags"]))
print("con foto query", sum(1 for r in recipes if r["photoQuery"]))
