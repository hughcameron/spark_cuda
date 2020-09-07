# Adapted from https://github.com/microsoft/recommenders/blob/master/tools/docker/Dockerfile
# Licensed under the MIT License.

FROM nvidia/cuda:9.0-base AS gpu

ARG HOME
ENV HOME="${HOME}"
WORKDIR ${HOME}

# Install base dependencies
RUN apt-get update && \
    apt-get install -y curl git

# Install Anaconda
ARG ANACONDA="https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh"
RUN curl ${ANACONDA} -o anaconda.sh && \
    /bin/bash anaconda.sh -b -p conda && \
    rm anaconda.sh && \
    echo ". ${HOME}/conda/etc/profile.d/conda.sh" >> ~/.bashrc && \
    echo "conda activate base" >> ~/.bashrc
ENV PATH="${HOME}/conda/bin:${PATH}"


# Setup Jupyter notebook configuration
ENV NOTEBOOK_CONFIG="${HOME}/.jupyter/jupyter_notebook_config.py"
RUN mkdir ${HOME}/.jupyter && \
    echo "c.NotebookApp.token = ''" >> ${NOTEBOOK_CONFIG} && \
    echo "c.NotebookApp.ip = '0.0.0.0'" >> ${NOTEBOOK_CONFIG} && \
    echo "c.NotebookApp.allow_root = True" >> ${NOTEBOOK_CONFIG} && \
    echo "c.NotebookApp.open_browser = False" >> ${NOTEBOOK_CONFIG} && \
    echo "c.MultiKernelManager.default_kernel_name = 'python3'" >> ${NOTEBOOK_CONFIG}


# Install Spark
ARG SPARK="http://archive.apache.org/dist/spark/spark-3.0.0/spark-3.0.0-bin-hadoop2.7.tgz"
RUN mkdir spark && \
    curl ${SPARK} -o spark.tgz && \
    tar xzf spark.tgz --strip-components 1 -C spark && \
    rm spark.tgz

ENV JAVA_HOME="/usr/lib/jvm/java-8-openjdk-amd64" \
    PYSPARK_PYTHON="${HOME}/conda/bin/python" \
    PYSPARK_DRIVER_PYTHON="${HOME}/conda/bin/python" \
    SPARK_HOME="${HOME}/spark"


# Install Conda packages
RUN conda env update -f base.yaml && \
    conda clean -fay && \
    python -m ipykernel install --user --name 'python3' --display-name 'python3'

ARG HOME
WORKDIR ${HOME}/projects

EXPOSE 8888
CMD ["jupyter", "notebook"]
