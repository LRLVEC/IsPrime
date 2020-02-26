#include <_Time.h>
//1226564
#define MAXN 180
#define MAXL 1050
unsigned int* prime;
bool* check;
unsigned int tot = 0;
unsigned int call(unsigned int* prime);

namespace CPU
{
	int isPrimeCPU(unsigned long long a)
	{
		int c0(0);
		for (;;)
		{
			unsigned int p(prime[c0++]);
			if (unsigned long long(p) * p > a)
				return 1;
			if (a % p == 0)
				return 0;
		}
	}
	unsigned long long qml(unsigned long long a, unsigned long long b, unsigned long long m)
	{
		unsigned long long s = 0;
		while (b) {
			if (b & 1) s = (s + a) % m;
			a = (a + a) % m, b /= 2;
		}
		return s;
	}
	unsigned long long mypow(unsigned long long a, unsigned long long b, unsigned long long m)
	{
		unsigned long long s = 1;
		while (b)
		{
			if (b & 1) s = qml(s, a, m);
			a = qml(a, a, m), b /= 2;
		}
		return s;
	}
	int Miller_Rabbin(unsigned long long x)
	{
		if (x == 2) return true;
		unsigned int table[24] = { 2,3,5,7,11,13,17,19,23,29,31,
			37,41,43,47,53,59,61,67,71,73,79,83,89 //,97,101,103,
			//107,109,113,127,131,137,139,149,151,157,163,167,173,
			//179,181,191,193,197,199,211,223,227,229
		};
		int c1(0);
		for (; c1 < 24; ++c1)
			if (x % table[c1] == 0)
			{
				if (x == table[c1])return 1;
				else return 0;
			}
		if (c1 == 24)
			for (int c0(0); c0 < 7; ++c0)
				if (mypow(table[c0], x - 1, x) != 1)return 0;
		return 1;

	}
}

int main()
{
	unsigned int num(0);
	srand(time(nullptr));
	Timer timer;
	//----------------------
	timer.begin();
	prime = (unsigned int*)::malloc(MAXN * sizeof(unsigned int));
	check = (bool*)::calloc(MAXL, sizeof(bool));
	for (unsigned long long i = 2; i < MAXL; ++i)
	{
		if (!check[i])prime[tot++] = i;
		for (unsigned long long j = 0; j < tot; ++j)
		{
			if (i * prime[j] > MAXL)break;
			check[i * prime[j]] = true;
			if (i % prime[j] == 0)break;
		}
	}
	for (int c0(2); c0 < 500000; ++c0)
	{
		unsigned long long a(c0);
		a = 2 * a - 1;
		num += CPU::isPrimeCPU(a);
	}
	timer.end();
	timer.print("CPU");
	::printf("Total prime num CPU: %u\n", num);
	//----------------------
	num = 0;
	timer.begin();
	for (int c0(2); c0 < 500000; ++c0)
	{
		unsigned long long a(c0);
		a = 2 * a - 1;
		num += CPU::Miller_Rabbin(a);
	}
	timer.end();
	timer.print("Miller Rabbin");
	::printf("Total prime num Miller Rabbin: %u\n", num);
	//----------------------
	timer.begin();
	num = call(prime);
	timer.end();
	timer.print("CUDA");
	::printf("Total prime num CUDA: %llu\n", num);//5437850

	//for (unsigned long long i = 0; i < 50; ++i)
	//	::printf("%llu\n", prime[i]);
	::printf("Prime num: %u\n", tot);

	return 0;
}
