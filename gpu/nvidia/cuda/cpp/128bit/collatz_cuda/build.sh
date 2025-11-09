docker build -t collatz_cuda .
docker run --rm --gpus all --name collatz_cuda collatz_cuda

