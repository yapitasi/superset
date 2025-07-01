FROM apache/superset:5.0.0

USER root

RUN apt-get update && \
    apt-get install -y wget zip libaio1



RUN pip install --no-cache gevent psycopg2-binary redis playwright && \
playwright install-deps chromium

USER superset