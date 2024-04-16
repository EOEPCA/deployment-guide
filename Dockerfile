FROM squidfunk/mkdocs-material
COPY ./docs/requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir -U -r /tmp/requirements.txt \
  && rm /tmp/requirements.txt
RUN pip install --no-cache-dir -U mike
RUN git config --global --add safe.directory /docs
