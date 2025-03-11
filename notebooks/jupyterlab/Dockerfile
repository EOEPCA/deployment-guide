FROM quay.io/jupyter/base-notebook:lab-4.3.5

# Additional tooling
USER root
RUN apt-get update && \
    apt-get install -y git

# Use the built-in user
USER ${NB_USER}

# Move to the work dir
WORKDIR ${HOME}/work

# Install the python requirements in an early layer,
# since it shouldn't change that often and takes a while to execute.
COPY --chown=${NB_UID}:${NB_GID} jupyterlab/requirements.txt .
RUN pip install --no-cache-dir -U -r requirements.txt
