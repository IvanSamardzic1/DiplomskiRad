import pyodbc

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
    "Encrypt=no;"
    "TrustServerCertificate=yes;"
)

try:
    conn = pyodbc.connect(CONNECTION_STRING)

    cursor = conn.cursor()
    cursor.execute("SELECT DB_NAME()")

    print("Uspješno spajanje!")
    print("Baza:", cursor.fetchone()[0])

    conn.close()

except Exception as e:
    print("Greška pri spajanju:")
    print(e)