FROM python:3.11-alpine

WORKDIR /app
COPY server.py /app/
COPY static /app/static

# Paquete iproute2 para comando ip y consulta de red
RUN apk add --no-cache iproute2

EXPOSE 8080
CMD ["python", "server.py"]
