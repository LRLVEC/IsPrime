
#include <cuda_runtime.h>
#include <device_launch_parameters.h>
#ifndef __CUDACC__ 
#define __CUDACC__
#endif
#include <device_functions.h>
#include <curand_kernel.h>
#include <stdlib.h>
#define Num 500000
#define PrimeNumMax 5000000
#define GroupSize 8

__inline__ __device__ int isPrime(unsigned int* prime, unsigned long long a)
{
	int c0(0);
	for (;;)
	{
		unsigned int p(prime[c0++]);
		if (unsigned long long(p) * p > a)return 1;
		if (a % p == 0)return 0;
	}
}
__inline__ __device__ unsigned long long qml(unsigned long long a, unsigned long long b, unsigned long long m)
{
	unsigned long long s = 0;
	while (b)
	{
		if (b & 1) s = (s + a) % m;
		a = (a + a) % m;
		b >>= 1;
	}
	return s;
}
__inline__ __device__ unsigned long long mypow(unsigned long long a, unsigned long long b, unsigned long long m)
{
	unsigned long long s = 1;
	while (b)
	{
		if (b & 1) s = qml(s, a, m);
		a = qml(a, a, m);
		b >>= 1;
	}
	return s;
}
__inline__ __device__ int Miller_Rabbin(unsigned long long x, curandState* state)
{
	if (x == 2) return true;
	for (int i = 0; i < 2; ++i)
	{
		unsigned long long a = curand(state) % (x - 2) + 2;
		if (mypow(a, x - 1, x) != 1)
			return 0;
	}
	return 1;
}
__inline__ __device__ int Miller_Rabbin_Op(unsigned long long x)
{
	if (x == 2) return true;
	unsigned int table[7]{ 2,3,5,7,11,13,17 };
	for (int c0(0); c0 < 7; ++c0)
	{
		unsigned long long a = table[c0];
		if (mypow(a, x - 1, x) != 1)
			return 0;
	}
	return 1;
}


__global__ void initRandom(curandState* state, unsigned int seed)
{
	int id = blockIdx.x * blockDim.x + threadIdx.x;
	curand_init(seed, id, 0, state + id);
}

__global__ void fuckCPU(unsigned int* prime, unsigned int* answer)
{
	unsigned int id(threadIdx.x + blockIdx.x * blockDim.x);
	unsigned int upper((id + 1) * GroupSize + 2);
	unsigned int limit((upper > Num + 1) ? (Num + 1) : upper);
	unsigned int num(0);
	for (unsigned int c0(id* GroupSize + 2); c0 < limit; ++c0)
	{
		unsigned long long a(c0);
		a = 2 * a * a - 1;
		num += isPrime(prime, a);
	}
	answer[id] = num;
}
__global__ void fuckCPU_Op1(unsigned int* prime, unsigned int* answer)//blocksize: 64
{
	__shared__ unsigned int primeS[8192];
	for (int c0(0); c0 < 64; ++c0)
	{
		unsigned int id(threadIdx.x + c0 * 128);
		primeS[id] = prime[id];
		primeS[id + 64] = prime[id + 64];
	}
	__syncthreads();
	unsigned int id(threadIdx.x + blockIdx.x * blockDim.x);
	unsigned int upper((id + 1) * GroupSize + 2);
	unsigned int limit((upper > Num + 1) ? (Num + 1) : upper);
	unsigned int num(0);
	for (unsigned int c0(id* GroupSize + 2); c0 < limit; ++c0)
	{
		unsigned long long a(c0);
		a = 2 * a * a - 1;
		int c1(0);
		for (;;)
		{
			unsigned int p;
			if (c1 < 8192)p = primeS[c1++];
			else p = prime[c1++];
			if (unsigned long long(p) * p > a)
			{
				num += 1;
				break;
			}
			if (a % p == 0)break;
		}
	}
	answer[id] = num;
}
__global__ void fuckCPU_Op2(unsigned int* answer)//, curandState* state)
{
	unsigned int table[24] = { 2,3,5,7,11,13,17,19,23,29,31,
		37,41,43,47,53,59,61,67,71,73,79,83,89 //,97,101,103,
		//107,109,113,127,131,137,139,149,151,157,163,167,173,
		//179,181,191,193,197,199,211,223,227,229
	};
	unsigned int id(threadIdx.x + blockIdx.x * blockDim.x);
	unsigned int upper((id + 1) * GroupSize + 2);
	unsigned int limit((upper > Num + 1) ? (Num + 1) : upper);
	unsigned int num(0);
	//state += id;
	for (unsigned int c0(id* GroupSize + 2); c0 < limit; ++c0)
	{
		unsigned long long a(c0);
		a = 2 * a - 1;
		int c1(0);
		for (; c1 < 24; ++c1)
			if (a % table[c1] == 0)
			{
				if (a == table[c1])num++;
				break;
			}
		if (c1 == 24)
			num += Miller_Rabbin_Op(a);
	}
	answer[id] = num;
}

unsigned int call(unsigned int* prime)
{
	size_t answerSize(68 * 1024 * 4);
	//size_t stateSize(272 * 1024 * sizeof(curandState));
	//unsigned int* primeGPU;
	unsigned int* answerGPU;
	unsigned int* answerCPU((unsigned int*)::malloc(answerSize));
	//curandState* state;
	//cudaMalloc(&primeGPU, PrimeNumMax * 4);
	cudaMalloc(&answerGPU, answerSize);
	//cudaMalloc(&state, stateSize);
	//cudaMemcpy(primeGPU, prime, PrimeNumMax * 4, cudaMemcpyHostToDevice);
	//fuckCPU_Op1 << <68, 64 >> > (primeGPU, answerGPU);
	//initRandom << <272, 1024 >> > (state, rand());
	fuckCPU_Op2 << <68, 1024 >> > (answerGPU);
	//fuckCPU_Op2 << <272, 1024 >> > (answerGPU, state);
	cudaMemcpy(answerCPU, answerGPU, answerSize, cudaMemcpyDeviceToHost);
	unsigned int answer(0);
	for (int c0(0); c0 < answerSize / 4; ++c0)
		answer += answerCPU[c0];
	//cudaFree(primeGPU);
	cudaFree(answerGPU);
	//cudaFree(state);
	free(answerCPU);
	return answer;
}