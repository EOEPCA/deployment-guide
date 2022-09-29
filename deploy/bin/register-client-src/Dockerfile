FROM python:3.9
RUN python -m pip install -U pip
WORKDIR /app
ENV PATH="/app:${PATH}"
COPY . .
RUN pip install -r requirements.txt
ENTRYPOINT [ "/app/register_client.py" ]
