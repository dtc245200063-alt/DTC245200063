FROM python:3.11-alpine

WORKDIR /app

COPY server.py /app/server.py

RUN mkdir -p /data && chmod 777 /data

EXPOSE 9099

CMD ["python", "-u", "/app/server.py"]
