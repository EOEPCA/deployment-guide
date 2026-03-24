FROM zensical/zensical
COPY ./docs/requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir -U -r /tmp/requirements.txt
