import json
import os
import sys
from typing  import Optional
from datetime import datetime
from kafka import KafkaConsumer
from influxdb_client import InfluxDBClient, Point, WriteOptions
import psycopg2


# =========================
#  Configuração do Kafka
# =========================
try:
    from const import KAFKA_SERVER, KAFKA_PORT
    KAFKA_BOOTSTRAP = f"{KAFKA_SERVER}:{KAFKA_PORT}"
except ImportError:
    kafka_server = os.environ.get("KAFKA_SERVER", "localhost")
    kafka_port = os.environ.get("KAFKA_PORT", "9092")
    KAFKA_BOOTSTRAP = f"{kafka_server}:{kafka_port}"

TOPIC = "water_bottle.sensor"

# =========================
#  Configuração do InfluxDB
# =========================
INFLUX_URL = "http://13.217.153.230:8086"
INFLUX_TOKEN = "qitLpKmQYK0RGpZlW4IqCvSxqZJiM4k-NbfsE3MHliWTfphGPJ9K3Hl7RM8BJx74CqKz94z4oV3zdENZbAalZA=="
INFLUX_ORG = "GarrafaInteligente"
INFLUX_BUCKET = "GarrafaInteligente"

MISSING = [name for name, val in [
    ("INFLUX_URL", INFLUX_URL),
    ("INFLUX_TOKEN", INFLUX_TOKEN),
    ("INFLUX_ORG", INFLUX_ORG),
    ("INFLUX_BUCKET", INFLUX_BUCKET),
] if not val]

if MISSING:
    print(f"[kafka_to_influx] ERRO: faltam variáveis de ambiente: {', '.join(MISSING)}")
    print("  Exemplo:")
    print('  export INFLUX_URL="http://SEU_IP:8086"')
    print('  export INFLUX_ORG="cmu"')
    print('  export INFLUX_BUCKET="garrafas"')
    print('  export INFLUX_TOKEN="SEU_TOKEN_AQUI"')
    sys.exit(1)


POSTGRES_HOST = "localhost"
POSTGRES_PORT = "5432"
POSTGRES_USER = "garrafa_user"
POSTGRES_PASSWORD = "garrafa123"
POSTGRES_DB = "garrafa"

USE_POSTGRES = all([POSTGRES_HOST, POSTGRES_USER, POSTGRES_PASSWORD, POSTGRES_DB])

if not USE_POSTGRES:
	print("[kafka_to_influx] Aviso: variáveis do Postgres não completas.")
	print("  Não será feita gravação em Postgres. (Influx continua normal.)")


def create_postgres_conn():
	if not USE_POSTGRES:
		return None
	print(
        f"[kafka_to_influx] Conectando no Postgres em {POSTGRES_HOST}:{POSTGRES_PORT}, "
        f"db='{POSTGRES_DB}', user='{POSTGRES_USER}'...")
	conn = psycopg2.connect(
		host=POSTGRES_HOST,
		port=int(POSTGRES_PORT),
		user=POSTGRES_USER,
		password=POSTGRES_PASSWORD,
		dbname=POSTGRES_DB,
	)
	conn.autocommit = True
	return conn

def parse_timestamp(ts):
	if not ts:
		return None
	try:
		return datetime.fromisoformat(ts)
	except Exception:
		return None


def create_kafka_consumer() -> KafkaConsumer:
    """
    Cria um KafkaConsumer que lê JSON do tópico de sensores da garrafa.
    """
    print(f"[kafka_to_influx] Conectando no Kafka em {KAFKA_BOOTSTRAP}, tópico '{TOPIC}'...")
    consumer = KafkaConsumer(
        TOPIC,
        bootstrap_servers=[KAFKA_BOOTSTRAP],
        value_deserializer=lambda v: json.loads(v.decode("utf-8")),
        auto_offset_reset="latest",       # começa a ler a partir de agora
        enable_auto_commit=True,
        group_id="water_influx_writer",   # consumer group desse serviço
    )
    return consumer


def create_influx_writer():
    """
    Cria cliente e write_api do InfluxDB.
    """
    print(f"[kafka_to_influx] Conectando no InfluxDB em {INFLUX_URL} (org='{INFLUX_ORG}', bucket='{INFLUX_BUCKET}')...")
    client = InfluxDBClient(url=INFLUX_URL, token=INFLUX_TOKEN, org=INFLUX_ORG)
    write_api = client.write_api(write_options=WriteOptions(batch_size=1, flush_interval=1000))
    return client, write_api


def process_message(data, write_api, pg_cursor):
    """
    Grava a mensagem no InfluxDB e, se configurado, também no Postgres.
    """
    bottle_id = str(data.get("bottleId", "unknown"))
    sensor_type = data.get("sensorType", "water_temp")
    ts = data.get("timestamp")
    ts_dt = parse_timestamp(ts)
    # Campos numéricos – se não vierem, vira None
    temp_value = data.get("value")
    volume_ml = data.get("volumeMl")
    capacity_ml = data.get("capacityMl")

    temp_unit = data.get("unit", "C")

    # Se nem temperatura nem volume vieram, não faz sentido gravar
    if temp_value is None and volume_ml is None:
        print("[kafka_to_influx] Aviso: mensagem sem 'value' nem 'volumeMl', ignorando:", data)
        return

    # Monta o ponto
    point = (
        Point("water_bottle_state")   # measurement único com o estado da garrafa
        .tag("bottleId", bottle_id)
        .tag("sensorType", sensor_type)
    )

    # Campos: temperatura
    if temp_value is not None:
        try:
            point = point.field("temperature_c", float(temp_value))
        except ValueError:
            print("[kafka_to_influx] Aviso: não consegui converter 'value' para float:", temp_value)

    # Unidade de temperatura
    if temp_unit:
        point = point.field("temp_unit", str(temp_unit))

    # Campos: volume e capacidade
    if volume_ml is not None:
        try:
            point = point.field("volume_ml", float(volume_ml))
        except ValueError:
            print("[kafka_to_influx] Aviso: não consegui converter 'volumeMl' para float:", volume_ml)

    if capacity_ml is not None:
        try:
            point = point.field("capacity_ml", float(capacity_ml))
        except ValueError:
            print("[kafka_to_influx] Aviso: não consegui converter 'capacityMl' para float:", capacity_ml)

    # Timestamp – se vier, usamos; se não, Influx usa o horário atual do servidor
    if ts:
        point = point.time(ts)

    # Grava no Influx
    write_api.write(bucket=INFLUX_BUCKET, record=point)
    print(f"[kafka_to_influx] Gravado no Influx (bottleId={bottle_id}, sensorType={sensor_type})")

    if pg_cursor is not None:
        try:
            insert_sql = """
                INSERT INTO water_bottle_state
                    (bottle_id, measured_at, temperature_c, temp_unit, volume_ml, capacity_ml)
                VALUES (%s, %s, %s, %s, %s, %s)
            """
            pg_cursor.execute(
                insert_sql,
                (
                    bottle_id,
                    ts_dt or datetime.utcnow(),
                    float(temp_value) if temp_value is not None else None,
                    temp_unit,
                    float(volume_ml) if volume_ml is not None else None,
                    float(capacity_ml) if capacity_ml is not None else None,
                ),
            )
        except Exception as e:
            print(
                "[kafka_to_influx] ERRO ao gravar no Postgres:",
                e,
                "Dados:",
                data,
            )

    print(
        "[kafka_to_influx] Gravado Influx "
        f"(e Postgres={'sim' if pg_cursor else 'não'}) "
        f"para bottleId={bottle_id}"
    )


def main():
    consumer = create_kafka_consumer()
    client, write_api = create_influx_writer()
    pg_conn = create_postgres_conn()
    pg_cursor = pg_conn.cursor() if pg_conn is not None else None

    print(
        "[kafka_to_influx] Iniciado. Aguardando mensagens... "
        "(Ctrl+C para sair)"
    )

    try:
        for msg in consumer:
            data = msg.value
            print("[kafka_to_influx] Recebido do Kafka:", data)
            try:
                process_message(data, write_api, pg_cursor)
            except Exception as e:
                print(
                    "[kafka_to_influx] ERRO ao processar/gravar mensagem:",
                    e,
                    "Mensagem:",
                    data,
                )
    except KeyboardInterrupt:
        print("\n[kafka_to_influx] Encerrando por Ctrl+C...")
    finally:
        if pg_cursor is not None:
            pg_cursor.close()
        if pg_conn is not None:
            pg_conn.close()
        client.close()
        consumer.close()
        print("[kafka_to_influx] Encerrado.")


if __name__ == "__main__":
    main()
