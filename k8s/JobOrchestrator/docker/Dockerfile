FROM python:3.13.12-slim

WORKDIR /app

RUN pip install redis kubernetes

COPY orchestrator.py /app/orchestrator.py

CMD ["python3", "/app/orchestrator.py"]