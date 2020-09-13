# Spark 3 with Cuda for GPUs


Docker-compose does not support GPU passthrough so run this container with:
`docker run -d --name jupyterlab --restart unless-stopped --gpus all --network=host spark_cuda`