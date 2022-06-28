FROM squidfunk/mkdocs-material
RUN pip install mike
RUN git config --global --add safe.directory /docs
