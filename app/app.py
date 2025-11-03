from flask import Flask, jsonify
import os
import psycopg2

app = Flask(__name__)

DB_HOST = os.environ.get("DB_HOST", "host.docker.internal")
DB_PORT = int(os.environ.get("DB_PORT", 5432))
DB_NAME = os.environ.get("DB_NAME", "dev_db")
DB_USER = os.environ.get("DB_USER", "dev")
DB_PASS = os.environ.get("DB_PASS", "devpass")


def check_db():
    try:
        conn = psycopg2.connect(host=DB_HOST, port=DB_PORT, dbname=DB_NAME, user=DB_USER, password=DB_PASS, connect_timeout=2)
        cur = conn.cursor()
        cur.execute("SELECT 1")
        cur.close()
        conn.close()
        return True
    except Exception as e:
        app.logger.debug(f"DB check failed: {e}")
        return False


@app.route("/")
def index():
    return jsonify({"message": "DevOps Platform Demo App", "db": ("reachable" if check_db() else "unreachable")})


@app.route("/health")
def health():
    return jsonify({"status": "ok"})


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
