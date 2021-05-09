# Author: Glen Adams
FROM continuumio/miniconda3

WORKDIR /python3_env

# Create the environment:
COPY environment.yml .
RUN conda env create -f environment.yml
ENV PATH /opt/conda/envs/python3_env/bin:$PATH

# Make RUN commands use the new environment:
RUN /bin/bash -c "source activate python3_env"

# The code to run when container is started:
CMD ["python", "/scripts/RealtimeDataUpdate.py"]