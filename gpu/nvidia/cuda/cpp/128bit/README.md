# performance

## Compile / Run
```

cd gpu/nvidia/cuda/cpp/128bit/collatz_cuda
nvcc -o kernel_collatz kernel_collatz.cu
./kernel_collatz 
```

### Example run on clean Lenovo SR250v3 - 20261121 new RTX-A100

https://github.com/ObrienlabsDev/blog/issues/231#issuecomment-7071432420
```
``
ubuntu@sr250:~$ history
    1  history
    2  ls
    3  nvidia-smi
    4  nvcc --version
    5  sudo apt install nvidia-cuda-toolkit
    6  nvidia-smi
    7  nvcc --version
    8  history
ubuntu@sr250:~$ nvidia-smi
Sat Nov 21 19:05:25 2026       
+-----------------------------------------------------------------------------------------+
| NVIDIA-SMI 595.99.02              Driver Version: 595.99.02      CUDA Version: 13.2     |
+-----------------------------------------+------------------------+----------------------+
| GPU  Name                 Persistence-M | Bus-Id          Disp.A | Volatile Uncorr. ECC |
| Fan  Temp   Perf          Pwr:Usage/Cap |           Memory-Usage | GPU-Util  Compute M. |
|                                         |                        |               MIG M. |
|=========================================+========================+======================|
|   0  NVIDIA RTX A1000               Off |   00000000:02:00.0 Off |                  N/A |
| 30%   33C    P8            N/A  /   50W |      15MiB /   8188MiB |      0%      Default |
|                                         |                        |                  N/A |
+-----------------------------------------+------------------------+----------------------+

+-----------------------------------------------------------------------------------------+
| Processes:                                                                              |
|  GPU   GI   CI              PID   Type   Process name                        GPU Memory |
|        ID   ID                                                               Usage      |
|=========================================================================================|
|    0   N/A  N/A            2855      G   /usr/lib/xorg/Xorg                        4MiB |
+-----------------------------------------------------------------------------------------+
ubuntu@sr250:~$ nvcc --version
nvcc: NVIDIA (R) Cuda compiler driver
Copyright (c) 2005-2023 NVIDIA Corporation
Built on Fri_Jan__6_16:45:21_PST_2023
Cuda compilation tools, release 12.0, V12.0.140
Build cuda_12.0.r12.0/compiler.32267302_0

git clone https://github.com/ObrienlabsDev/performance
ubuntu@sr250:~/wse_github/obrienlabsdev$ cd performance/
ubuntu@sr250:~/wse_github/obrienlabsdev/performance$ cd gpu/nvidia/cuda/cpp/128bit/collatz_cuda/
- get gcc first
sudo apt update
sudo apt install build-essential
nvcc -o kernel_collatz kernel_collatz.cu
./kernel_collatz


Every 2.0s: nvidia-smi                                                                                                                                                                        sr250: Sat Nov 21 19:15:39 2026

Sat Nov 21 19:15:39 2026
+-----------------------------------------------------------------------------------------+
| NVIDIA-SMI 595.99.02              Driver Version: 595.99.02      CUDA Version: 13.2     |
+-----------------------------------------+------------------------+----------------------+
| GPU  Name                 Persistence-M | Bus-Id          Disp.A | Volatile Uncorr. ECC |
| Fan  Temp   Perf          Pwr:Usage/Cap |           Memory-Usage | GPU-Util  Compute M. |
|                                         |                        |               MIG M. |
|=========================================+========================+======================|
|   0  NVIDIA RTX A1000               Off |   00000000:02:00.0 Off |                  N/A |
| 30%   54C    P0            N/A  /   50W |     103MiB /   8188MiB |     67%      Default |
|                                         |                        |                  N/A |
+-----------------------------------------+------------------------+----------------------+

+-----------------------------------------------------------------------------------------+
| Processes:                                                                              |
|  GPU   GI   CI              PID   Type   Process name                        GPU Memory |
|        ID   ID                                                               Usage      |
|=========================================================================================|
|    0   N/A  N/A            2855      G   /usr/lib/xorg/Xorg                        4MiB |
|    0   N/A  N/A            8097      C   ./kernel_collatz                         80MiB |
+-----------------------------------------------------------------------------------------+

untu@sr250:~/wse_github/obrienlabsdev/performance/gpu/nvidia/cuda/cpp/128bit/collatz_cuda$ ./kernel_collatz 
1 CUDA devices found - reallocating
endSequenceNumber: 0
BatchNumberPower: 3
BatchNumber: 257348542465872
Iterations: 9223371761976868863
array allocation bytes per GPU: 16 * 35840 is 286720 maxSearch: 549755813889 to 0
GPU0: Iterations: 9223371761976868863 via (Threads: 35840 * Batches: 257348542465872 * 2 (odd mult)) ThreadsPerBlock: 256 Blocks: 1120
GPU00:Sec: 0 path: 153 GlobalMax: 0:549755813889 : 0:1649267441668 last search: 549755885569
GPU00:Sec: 0 path: 197 GlobalMax: 0:549755813891 : 0:2473901162512 last search: 549755885569
GPU00:Sec: 0 path: 197 GlobalMax: 0:549755813895 : 0:3710851743796 last search: 549755885569
GPU00:Sec: 0 path: 197 GlobalMax: 0:549755813903 : 0:5566277615776 last search: 549755885569
GPU00:Sec: 0 path: 595 GlobalMax: 0:549755813915 : 0:3212877821281504 last search: 549755885569
GPU00:Sec: 0 path: 595 GlobalMax: 0:549755813929 : 0:3614487549038224 last search: 549755885569
GPU00:Sec: 0 path: 595 GlobalMax: 0:549755817055 : 0:4011567636389416 last search: 549755885569
GPU00:Sec: 0 path: 582 GlobalMax: 0:549755838127 : 0:22282723978367380 last search: 549755885569
GPU00:Sec: 0 path: 445 GlobalMax: 0:549755840511 : 0:125198954472303376 last search: 549755885569
GPU00:Sec: 0 path: 489 GlobalMax: 0:549756021439 : 0:1171094407924307632 last search: 549756028929
GPU00:Sec: 0 path: 701 GlobalMax: 0:549756426633 : 0:4684381084302265060 last search: 549756459009
GPU00:Sec: 0 path: 556 GlobalMax: 0:549757934079 : 0:10004657736992888032 last search: 549757964289
GPU00:Sec: 1 path: 582 GlobalMax: 0:549823088553 : 0:10684950975402144424 last search: 549823121409


6 min

Every 2.0s: nvidia-smi                                                                                                                                                                        sr250: Sat Nov 21 19:21:24 2026

Sat Nov 21 19:21:24 2026
+-----------------------------------------------------------------------------------------+
| NVIDIA-SMI 595.99.02              Driver Version: 595.99.02      CUDA Version: 13.2     |
+-----------------------------------------+------------------------+----------------------+
| GPU  Name                 Persistence-M | Bus-Id          Disp.A | Volatile Uncorr. ECC |
| Fan  Temp   Perf          Pwr:Usage/Cap |           Memory-Usage | GPU-Util  Compute M. |
|                                         |                        |               MIG M. |
|=========================================+========================+======================|
|   0  NVIDIA RTX A1000               Off |   00000000:02:00.0 Off |                  N/A |
| 42%   70C    P0            N/A  /   50W |     103MiB /   8188MiB |     67%      Default |
|                                         |                        |                  N/A |
+-----------------------------------------+------------------------+----------------------+

+-----------------------------------------------------------------------------------------+
| Processes:                                                                              |
|  GPU   GI   CI              PID   Type   Process name                        GPU Memory |
|        ID   ID                                                               Usage      |
|=========================================================================================|
|    0   N/A  N/A            2855      G   /usr/lib/xorg/Xorg                        4MiB |
|    0   N/A  N/A            8097      C   ./kernel_collatz                         80MiB |
+-----------------------------------------------------------------------------------------+



```
