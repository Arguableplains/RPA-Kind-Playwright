FROM python:3.13-slim

WORKDIR /app

RUN pip install playwright==1.58.0

COPY ./robot.py /app/robot.py

CMD ["python3", "/app/robot.py"]
