# Licensed under the MIT License.

FROM nvidia/cuda:11.0-cudnn8-runtime-ubuntu18.04

ARG HOME="/root"
ENV HOME="${HOME}"
WORKDIR ${HOME}

## SPARK & CUDA REQUIREMENTS ##

# Install base dependencies
RUN apt-get update && \
    apt-get install -y curl git vim libgomp1 openjdk-8-jre

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
    echo "c.MultiKernelManager.default_kernel_name = 'python3'" >> ${NOTEBOOK_CONFIG} && \
    echo "c.NotebookApp.terminado_settings = {'shell_command': ['/bin/bash', '--login', '-i']}" >> ${NOTEBOOK_CONFIG}


## Set Spark Vesion
ENV SPARK_VERSION=3.0.1 \
    HADOOP_VERSION=2.7


# Install Spark
ARG SPARK="http://archive.apache.org/dist/spark/spark-{$SPARK_VERSION}/spark-{$SPARK_VERSION}-bin-hadoop{$HADOOP_VERSION}.tgz"
RUN mkdir spark && \
    curl ${SPARK} -o spark.tgz && \
    tar xzf spark.tgz --strip-components 1 -C spark && \
    rm spark.tgz

ENV JAVA_HOME="/usr/lib/jvm/java-8-openjdk-amd64" \
    PYSPARK_PYTHON="${HOME}/conda/bin/python" \
    PYSPARK_DRIVER_PYTHON="${HOME}/conda/bin/python" \
    SPARK_HOME="${HOME}/spark" \
    SPARK_JARS="${SPARK_HOME}/jars"

# Add Jars
ADD https://search.maven.org/remotecontent?filepath=ai/rapids/cudf/0.15/cudf-0.15-cuda11.jar $SPARK_HOME/jars/cudf-0.15-cuda11.jar
ADD https://search.maven.org/remotecontent?filepath=com/nvidia/rapids-4-spark_2.12/0.1.0/rapids-4-spark_2.12-0.1.0.jar $SPARK_HOME/jars/rapids-4-spark_2.12-0.1.0.jar
ADD https://search.maven.org/remotecontent?filepath=com/nvidia/xgboost4j_3.0/1.0.0-0.1.0/xgboost4j_3.0-1.0.0-0.1.0.jar $SPARK_HOME/jars/xgboost4j_3.0-1.0.0-0.1.0.jar
ADD https://search.maven.org/remotecontent?filepath=com/nvidia/xgboost4j-spark_3.0/1.0.0-0.1.0/xgboost4j-spark_3.0-1.0.0-0.1.0.jar $SPARK_HOME/jars/xgboost4j-spark_3.0-1.0.0-0.1.0.jar
RUN chmod a+r $SPARK_HOME/jars/*

# Install Conda packages
COPY base.yaml /root/base.yaml
RUN conda env update -f base.yaml && \
    conda clean -fay && \
    python -m ipykernel install --user --name 'python3' --display-name 'python3'


# Configure Spark Worker
RUN cp $SPARK_HOME/conf/spark-env.sh.template $SPARK_HOME/conf/spark-env.sh
RUN echo "SPARK_WORKER_OPTS=\"-Dspark.worker.resource.gpu.amount=1 -Dspark.worker.resource.gpu.discoveryScript=/root/spark/examples/src/main/scripts/getGpusResources.sh\"" >> $SPARK_HOME/conf/spark-env.sh

## ADDITIONAL FEATURES ##

# JupyterLab Extensions
RUN jupyter labextension install \
    @jupyterlab/shortcutui \
    @jupyterlab/toc \
    jupyterlab-execute-time \
    jupyterlab-plotly@4.8.0 \
    jupyterlab-s3-browser \
    jupyterlab-tailwind-theme \
    @ryantam626/jupyterlab_code_formatter \
    plotlywidget@4.8.0

# This increases the cell width set by the Tailwind theme
RUN find . | grep jupyterlab-tailwind-theme/style/index.css |  xargs -i sed -i 's/max-width: 1000px/max-width: 1200px/g' {}


RUN jupyter serverextension enable --py jupyterlab_code_formatter
RUN jupyter lab build

# Persist JupyterLab Settings
COPY settings/shortcuts.json /root/.jupyter/lab/user-settings/@jupyterlab/shortcuts-extension/shortcuts.jupyterlab-settings
COPY settings/theme.json /root/.jupyter/lab/user-settings/@jupyterlab/apputils-extension/themes.jupyterlab-settings
COPY settings/terminal.json /root/.jupyter/lab/user-settings/@jupyterlab/terminal-extension/plugin.jupyterlab-settings
COPY settings/notebook.json /root/.jupyter/lab/user-settings/@jupyterlab/notebook-extension/tracker.jupyterlab-settings

# Install Oh My Bash
RUN sh -c "$(curl -fsSL https://raw.github.com/ohmybash/oh-my-bash/master/tools/install.sh)"

ARG HOME
WORKDIR ${HOME}/projects

EXPOSE 8888
EXPOSE 4040
CMD ["jupyter", "lab"]
