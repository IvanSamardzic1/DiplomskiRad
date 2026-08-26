import pyodbc
import random
from datetime import date, timedelta
from collections import Counter


# ============================================================
# POSTAVKE BAZE PODATAKA
# ============================================================

SERVER = "127.0.0.1"
PORT = 1433
DATABASE = "diplomski"
USERNAME = "Ivan"
PASSWORD = "ivan1234"

CONNECTION_STRING = (
    "DRIVER={ODBC Driver 17 for SQL Server};"
    f"SERVER={SERVER},{PORT};"
    f"DATABASE={DATABASE};"
    f"UID={USERNAME};"
    f"PWD={PASSWORD};"
    "TrustServerCertificate=yes;"
)


# ============================================================
# POSTAVKE GENERIRANJA
# ============================================================

# Fiksni seed omogućuje reproducibilnost.
# Svakim pokretanjem dobivamo iste sintetičke podatke.
random.seed(42)

START_DATE = date(2026, 7, 1)
NUMBER_OF_DAYS = 30

# Vrijednosti iz tablice VrstaObroka
MEAL_TYPE_IDS = {
    "dorucak": 1,
    "rucak": 2,
    "vecera": 3,
}


# ============================================================
# KORISNICI
# ============================================================

USERS = {
    "Petar": {
        "id": 1012,
        "preference": "piletina",

        # Posebno preferirani recepti
        "favorites": [
            10,  # Tortilje s piletinom
            7,   # Slatka piletina
            27,  # Pileći rižoto
        ],
    },

    "Jakov": {
        "id": 1013,
        "preference": "junetina",

        "favorites": [
            32,  # Juneći gulaš
            33,  # Juneće ćufte
            35,  # Junetina u umaku
        ],
    },

    "Stjepan": {
        "id": 1014,
        "preference": "svinjetina",

        "favorites": [
            24,  # Svinjski gulaš
            25,  # Svinjski medaljoni
            19,  # Svinjski odrezak s krumpirom
        ],
    },
}


# ============================================================
# RECEPTI ZA RUČAK I VEČERU
# ============================================================

RECIPES = {

    # --------------------------------------------------------
    # PILETINA
    # --------------------------------------------------------

    "piletina": [
        10,  # Tortilje s piletinom
        7,   # Slatka piletina
        11,  # Pohana piletina
        3,   # Piletina s tjesteninom
        16,  # Piletina s pommesom
        27,  # Pileći rižoto
        28,  # Piletina s pečenom paprikom
        29,  # Piletina s brokulom
    ],

    # --------------------------------------------------------
    # JUNETINA
    # --------------------------------------------------------

    "junetina": [
        30,  # Junetina s krumpirom
        31,  # Junetina s povrćem
        32,  # Juneći gulaš
        33,  # Juneće ćufte
        34,  # Junetina s tikvicama
        35,  # Junetina u umaku
        36,  # Junetina s palentom
        37,  # Junetina s kvinojom
    ],

    # --------------------------------------------------------
    # SVINJETINA
    # --------------------------------------------------------

    "svinjetina": [
        19,  # Svinjski odrezak s krumpirom
        20,  # Svinjski odrezak s rižom
        21,  # Svinjetina s tjesteninom
        22,  # Svinjetina sa špinatom
        23,  # Svinjski kotlet s povrćem
        24,  # Svinjski gulaš
        25,  # Svinjski medaljoni
        26,  # Svinjski kotleti s pečenom paprikom
    ],

    # --------------------------------------------------------
    # VEGETARIJANSKI
    # --------------------------------------------------------

    "vegetarijansko": [
        38,  # Tjestenina s rajčicom
        39,  # Riža s povrćem
        40,  # Pečene tikvice
        41,  # Tjestenina sa sirom
    ],

    # --------------------------------------------------------
    # OSTALO
    # --------------------------------------------------------

    "ostalo": [
        5,   # Bolognese
        9,   # Ćevapi
        4,   # Odrezak s krumpirom
    ],
}


# ============================================================
# RECEPTI ZA DORUČAK
# ============================================================

BREAKFAST_RECIPES = [
    42,  # Kajgana
    43,  # Jaje na oko
    44,  # Kroasan
    45,  # Sendvič sa sirom
    46,  # Sendvič sa kobasicom
    47,  # Kiflice
    48,  # Baguette sa namazom
    49,  # Sendvič sa šunkom
    50,  # Šunka i sir
    51,  # Slanina, kruh i kefir
    52,  # Burek sa sirom
    2,   # Banane
    53,  # Kruh i jogurt
    54,  # Kruh i maslac
    55,  # Puding
]


# ============================================================
# VJEROJATNOST ODABIRA KATEGORIJE
# ============================================================

def get_category_probabilities(preference, day_number):
    """
    Preferencija korisnika postaje izraženija kroz vrijeme.

    Dani 1-10:
        40 % preferirana vrsta mesa

    Dani 11-20:
        60 % preferirana vrsta mesa

    Dani 21-30:
        70 % preferirana vrsta mesa
    """

    other_meats = [
        meat
        for meat in ["piletina", "junetina", "svinjetina"]
        if meat != preference
    ]

    # --------------------------------------------------------
    # PRVIH 10 DANA
    # --------------------------------------------------------

    if day_number <= 10:

        return {
            preference: 40,
            other_meats[0]: 17,
            other_meats[1]: 17,
            "vegetarijansko": 16,
            "ostalo": 10,
        }

    # --------------------------------------------------------
    # DANI 11-20
    # --------------------------------------------------------

    elif day_number <= 20:

        return {
            preference: 60,
            other_meats[0]: 10,
            other_meats[1]: 10,
            "vegetarijansko": 12,
            "ostalo": 8,
        }

    # --------------------------------------------------------
    # DANI 21-30
    # --------------------------------------------------------

    else:

        return {
            preference: 70,
            other_meats[0]: 7,
            other_meats[1]: 7,
            "vegetarijansko": 10,
            "ostalo": 6,
        }


def choose_category(preference, day_number):
    """
    Odabire kategoriju recepta prema definiranim
    vjerojatnostima.
    """

    probabilities = get_category_probabilities(
        preference,
        day_number
    )

    categories = list(probabilities.keys())
    weights = list(probabilities.values())

    return random.choices(
        categories,
        weights=weights,
        k=1
    )[0]


# ============================================================
# ODABIR KONKRETNOG RECEPTA
# ============================================================

def choose_recipe(category, favorites, recently_used):
    """
    Odabire konkretan recept iz odabrane kategorije.

    Pravila:
    - pokušava izbjegavati recepte korištene zadnja 2 dana
    - omiljeni recepti imaju dvostruku težinu
    """

    candidates = [
        recipe_id
        for recipe_id in RECIPES[category]
        if recipe_id not in recently_used
    ]

    # Ako su svi recepti kategorije nedavno korišteni,
    # ponovno dopuštamo sve recepte.
    if not candidates:
        candidates = RECIPES[category].copy()

    weights = []

    for recipe_id in candidates:

        if recipe_id in favorites:
            weights.append(2)

        else:
            weights.append(1)

    return random.choices(
        candidates,
        weights=weights,
        k=1
    )[0]


# ============================================================
# ODABIR DORUČKA
# ============================================================

def choose_breakfast(previous_breakfast):
    """
    Isti doručak ne može biti odabran dva dana zaredom.
    """

    candidates = [
        recipe_id
        for recipe_id in BREAKFAST_RECIPES
        if recipe_id != previous_breakfast
    ]

    return random.choice(candidates)


# ============================================================
# GENERIRANJE ODABRAN / IZVRSEN
# ============================================================

def generate_selected_and_completed(
    meal_type,
    category,
    preference,
    recipe_id,
    favorites
):
    """
    Generira vrijednosti stupaca:
        odabran
        izvrsen

    Izvršen obrok uvijek mora prethodno biti odabran.
    """

    # --------------------------------------------------------
    # DORUČAK
    # --------------------------------------------------------

    if meal_type == "dorucak":

        selected_probability = 0.80

    # --------------------------------------------------------
    # POSEBNO OMILJEN RECEPT
    # --------------------------------------------------------

    elif recipe_id in favorites:

        selected_probability = 0.95

    # --------------------------------------------------------
    # PREFERIRANA VRSTA MESA
    # --------------------------------------------------------

    elif category == preference:

        selected_probability = 0.85

    # --------------------------------------------------------
    # VEGETARIJANSKO
    # --------------------------------------------------------

    elif category == "vegetarijansko":

        selected_probability = 0.60

    # --------------------------------------------------------
    # OSTALO
    # --------------------------------------------------------

    elif category == "ostalo":

        selected_probability = 0.50

    # --------------------------------------------------------
    # DRUGA VRSTA MESA
    # --------------------------------------------------------

    else:

        selected_probability = 0.45

    # Generiraj odabran
    odabran = (
        1
        if random.random() < selected_probability
        else 0
    )

    # --------------------------------------------------------
    # IZVRŠEN
    # --------------------------------------------------------

    # Ako nije odabran, ne može biti izvršen.
    if odabran == 0:

        izvrsen = 0

    else:

        # Ako je odabran, postoji 90 % šanse
        # da je korisnik obrok stvarno izvršio.
        izvrsen = (
            1
            if random.random() < 0.90
            else 0
        )

    return odabran, izvrsen


# ============================================================
# GENERIRANJE PODATAKA
# ============================================================

def generate_rows():

    rows = []

    statistics = {
        user_name: {
            "categories": Counter(),
            "recipes": Counter(),
            "odabran": 0,
            "izvrsen": 0,
        }
        for user_name in USERS
    }

    # Posljednji doručak svakog korisnika
    previous_breakfast = {
        user_name: None
        for user_name in USERS
    }

    # Povijest ručkova i večera
    recent_days = {
        user_name: []
        for user_name in USERS
    }

    # ========================================================
    # GENERIRAMO KRONOLOŠKI PO DATUMIMA
    # ========================================================

    for day_index in range(NUMBER_OF_DAYS):

        current_date = (
            START_DATE
            + timedelta(days=day_index)
        )

        day_number = day_index + 1

        # Za svaki datum prolazimo kroz sva 3 korisnika
        for user_name, user_data in USERS.items():

            user_id = user_data["id"]
            preference = user_data["preference"]
            favorites = user_data["favorites"]

            # ====================================================
            # DORUČAK
            # ====================================================

            breakfast = choose_breakfast(
                previous_breakfast[user_name]
            )

            odabran, izvrsen = (
                generate_selected_and_completed(
                    meal_type="dorucak",
                    category="dorucak",
                    preference=preference,
                    recipe_id=breakfast,
                    favorites=favorites
                )
            )

            rows.append({
                "user_id": user_id,
                "user_name": user_name,
                "recipe_id": breakfast,
                "date": current_date,
                "meal_type": "dorucak",
                "category": "dorucak",
                "odabran": odabran,
                "izvrsen": izvrsen,
            })

            previous_breakfast[user_name] = breakfast

            statistics[user_name]["recipes"][breakfast] += 1
            statistics[user_name]["odabran"] += odabran
            statistics[user_name]["izvrsen"] += izvrsen

            # ====================================================
            # RECEPTI KORIŠTENI PRETHODNA 2 DANA
            # ====================================================

            recently_used = set()

            for day_recipes in recent_days[user_name][-2:]:

                recently_used.update(
                    day_recipes
                )

            today_recipes = []

            # ====================================================
            # RUČAK
            # ====================================================

            lunch_category = choose_category(
                preference,
                day_number
            )

            lunch = choose_recipe(
                lunch_category,
                favorites,
                recently_used
            )

            odabran, izvrsen = (
                generate_selected_and_completed(
                    meal_type="rucak",
                    category=lunch_category,
                    preference=preference,
                    recipe_id=lunch,
                    favorites=favorites
                )
            )

            rows.append({
                "user_id": user_id,
                "user_name": user_name,
                "recipe_id": lunch,
                "date": current_date,
                "meal_type": "rucak",
                "category": lunch_category,
                "odabran": odabran,
                "izvrsen": izvrsen,
            })

            statistics[user_name]["categories"][
                lunch_category
            ] += 1

            statistics[user_name]["recipes"][
                lunch
            ] += 1

            statistics[user_name]["odabran"] += odabran
            statistics[user_name]["izvrsen"] += izvrsen

            today_recipes.append(lunch)
            recently_used.add(lunch)

            # ====================================================
            # VEČERA
            # ====================================================

            dinner_category = choose_category(
                preference,
                day_number
            )

            dinner = choose_recipe(
                dinner_category,
                favorites,
                recently_used
            )

            odabran, izvrsen = (
                generate_selected_and_completed(
                    meal_type="vecera",
                    category=dinner_category,
                    preference=preference,
                    recipe_id=dinner,
                    favorites=favorites
                )
            )

            rows.append({
                "user_id": user_id,
                "user_name": user_name,
                "recipe_id": dinner,
                "date": current_date,
                "meal_type": "vecera",
                "category": dinner_category,
                "odabran": odabran,
                "izvrsen": izvrsen,
            })

            statistics[user_name]["categories"][
                dinner_category
            ] += 1

            statistics[user_name]["recipes"][
                dinner
            ] += 1

            statistics[user_name]["odabran"] += odabran
            statistics[user_name]["izvrsen"] += izvrsen

            today_recipes.append(dinner)

            # Spremi današnje recepte u povijest
            recent_days[user_name].append(
                today_recipes
            )

    return rows, statistics


# ============================================================
# ISPIS STATISTIKE
# ============================================================

def print_statistics(rows, statistics):

    print()
    print("=" * 50)
    print("GENERIRANI PODACI")
    print("=" * 50)

    print(
        f"\nUkupno generirano zapisa: {len(rows)}"
    )

    for user_name, user_data in USERS.items():

        user_rows = [
            row
            for row in rows
            if row["user_name"] == user_name
        ]

        print()
        print("-" * 50)
        print(
            f"{user_name.upper()} "
            f"(preferira {user_data['preference']})"
        )
        print("-" * 50)

        print(f"Ukupno zapisa: {len(user_rows)}")
        print("Doručak:       30")
        print("Ručak:         30")
        print("Večera:        30")

        print()
        print("Ručak + večera po kategorijama:")

        for category in [
            "piletina",
            "junetina",
            "svinjetina",
            "vegetarijansko",
            "ostalo"
        ]:

            count = (
                statistics[user_name]
                ["categories"][category]
            )

            percentage = (
                count / 60 * 100
            )

            print(
                f"{category.capitalize():18}"
                f"{count:2} / 60 "
                f"({percentage:.1f}%)"
            )

        selected = (
            statistics[user_name]["odabran"]
        )

        completed = (
            statistics[user_name]["izvrsen"]
        )

        print()
        print("Interakcije:")

        print(
            f"Odabran = 1: "
            f"{selected}/90 "
            f"({selected / 90 * 100:.1f}%)"
        )

        print(
            f"Izvršen = 1: "
            f"{completed}/90 "
            f"({completed / 90 * 100:.1f}%)"
        )

        print()
        print("5 najčešćih recepata:")

        most_common = (
            statistics[user_name]["recipes"]
            .most_common(5)
        )

        for recipe_id, count in most_common:

            print(
                f"Recept ID {recipe_id}: "
                f"{count} puta"
            )


# ============================================================
# PROVJERA POSTOJE LI VEĆ PODACI
# ============================================================

def check_existing_data(cursor):

    end_date = (
        START_DATE
        + timedelta(days=NUMBER_OF_DAYS - 1)
    )

    user_ids = [
        user["id"]
        for user in USERS.values()
    ]

    placeholders = ",".join(
        "?"
        for _ in user_ids
    )

    query = f"""
        SELECT
            idKorisnik,
            COUNT(*) AS brojZapisa
        FROM PlanObroka
        WHERE idKorisnik IN ({placeholders})
          AND datumObrok BETWEEN ? AND ?
        GROUP BY idKorisnik
    """

    parameters = (
        user_ids
        + [
            START_DATE,
            end_date
        ]
    )

    cursor.execute(
        query,
        parameters
    )

    existing = cursor.fetchall()

    if existing:

        print()
        print("=" * 50)
        print("POSTOJEĆI PODACI")
        print("=" * 50)

        for row in existing:

            print(
                f"Korisnik {row.idKorisnik}: "
                f"{row.brojZapisa} postojećih zapisa."
            )

        print()
        print(
            "Skripta je prekinuta kako se podaci "
            "ne bi duplicirali."
        )

        return False

    return True


# ============================================================
# INSERT U PLANOBROKA
# ============================================================

def insert_rows(cursor, rows):

    query = """
        INSERT INTO PlanObroka
        (
            idKorisnik,
            idRecept,
            datumObrok,
            tipObroka,
            izvrsen,
            odabran
        )
        VALUES (?, ?, ?, ?, ?, ?)
    """

    for row in rows:

        cursor.execute(
            query,
            row["user_id"],
            row["recipe_id"],
            row["date"],
            MEAL_TYPE_IDS[
                row["meal_type"]
            ],
            row["izvrsen"],
            row["odabran"]
        )


# ============================================================
# MAIN
# ============================================================

def main():

    # --------------------------------------------------------
    # 1. GENERIRAJ PODATKE
    # --------------------------------------------------------

    rows, statistics = generate_rows()

    # --------------------------------------------------------
    # 2. PROVJERI BROJ REDAKA
    # --------------------------------------------------------

    expected_rows = (
        len(USERS)
        * NUMBER_OF_DAYS
        * 3
    )

    if len(rows) != expected_rows:

        raise Exception(
            f"Očekivano {expected_rows} zapisa, "
            f"ali generirano je {len(rows)}."
        )

    # --------------------------------------------------------
    # 3. ISPIS STATISTIKE
    # --------------------------------------------------------

    print_statistics(
        rows,
        statistics
    )

    print()
    print("=" * 50)
    print("SPAJANJE NA SQL SERVER")
    print("=" * 50)

    connection = None

    try:

        # ----------------------------------------------------
        # 4. SPAJANJE
        # ----------------------------------------------------

        connection = pyodbc.connect(
            CONNECTION_STRING
        )

        # Sve INSERT naredbe bit će jedna transakcija.
        connection.autocommit = False

        cursor = connection.cursor()

        print()
        print("Uspješno spojeno na bazu diplomski.")

        # ----------------------------------------------------
        # 5. PROVJERA POSTOJEĆIH PODATAKA
        # ----------------------------------------------------

        if not check_existing_data(cursor):

            connection.rollback()
            return

        # ----------------------------------------------------
        # 6. INSERT 270 REDAKA
        # ----------------------------------------------------

        print()
        print("Dodavanje podataka...")

        insert_rows(
            cursor,
            rows
        )

        # ----------------------------------------------------
        # 7. COMMIT
        # ----------------------------------------------------

        connection.commit()

        print()
        print("=" * 50)
        print("USPJEŠNO ZAVRŠENO")
        print("=" * 50)

        print()
        print(
            f"U PlanObroka dodano je "
            f"{len(rows)} zapisa."
        )

        print()
        print("Petar   (1012): 90 zapisa")
        print("Jakov   (1013): 90 zapisa")
        print("Stjepan (1014): 90 zapisa")

        print()
        print(
            "Razdoblje: "
            "01.07.2026. - 30.07.2026."
        )

    except Exception as error:

        print()
        print("=" * 50)
        print("GREŠKA")
        print("=" * 50)

        print()
        print(error)

        # ----------------------------------------------------
        # Ako jedan INSERT pukne, poništi SVE.
        # ----------------------------------------------------

        if connection is not None:

            connection.rollback()

            print()
            print(
                "Napravljen je ROLLBACK."
            )

            print(
                "Nijedan novi zapis iz ovog "
                "pokretanja nije spremljen."
            )

    finally:

        # ----------------------------------------------------
        # ZATVARANJE KONEKCIJE
        # ----------------------------------------------------

        if connection is not None:

            connection.close()

            print()
            print(
                "Veza s bazom je zatvorena."
            )


# ============================================================
# POKRETANJE
# ============================================================

if __name__ == "__main__":
    main()