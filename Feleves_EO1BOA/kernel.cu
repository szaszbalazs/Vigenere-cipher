
#include "cuda_runtime.h"
#include "device_launch_parameters.h"

#include <stdio.h>
#include <map>
#include <iostream>

#define TEXT_N 50000
#define KEY_M 15000
#define BLOCK_SIZE 256

__device__ char dev_TEXT[TEXT_N];
__device__ char dev_KEY[KEY_M];
__device__ char dev_ENCRYPTED[TEXT_N];
__device__ char dev_DECRYPTED[TEXT_N];

__shared__ char shr_TEXT[TEXT_N];
__shared__ char shr_KEY[KEY_M];



__device__ char vigenere_encrypt(char plaintext, char key, int key_length) {
	int p = plaintext - 'A'; // A=0, B=1, ..., Z=25
	int k = key - 'A'; // A=0, B=1, ..., Z=25
	int c = (p + k) % 26; // Titkosítás
	return c + 'A'; // Visszaalakítás karakterré
}

__device__ char vigenere_decrypt(char plaintext, char key, int key_length) {
	int p = plaintext - 'A'; // A=0, B=1, ..., Z=25
	int k = key - 'A'; // A=0, B=1, ..., Z=25
	int c = (p - k) % 26; // Titkosítás
	return c + 'A'; // Visszaalakítás karakterré
}

__global__ void Kernel()
{
	//shared -> ABC
	//A MÁR uppercased mondat is mehet sharedbe

	//maga a megoldás betűnként indul, minden szál megnézi, hogy az adott helyen [i] mit mivel kell összeadnia majd moduló
	//mituán ez megvan minden szál beírja magát a megfelelő helyre ->ehhez valszeg nem elég az empty string 
	//ha megvan vissza CPURA és kiírom

	//note to self: az uppercase átalakírást és a Kulcs fill-t végezhetné a GPU.
	//idő mérés, valamint occupancy calculator
	//atomi összeadás és kivonás amikor az encryptet csinálom illetve a decryptet.

	//3 féle
	//L1 cache és equals beállítása
	//konstans memória

	//első megoldás:
	int idx = blockIdx.x * blockDim.x + threadIdx.x;
	
	if (idx < TEXT_N) {
		char key_char = dev_KEY[idx % KEY_M];
		dev_ENCRYPTED[idx] = vigenere_encrypt(dev_TEXT[idx], key_char, KEY_M);
	}
	__syncthreads();

	if (idx < TEXT_N) {
		char key_char = dev_KEY[idx % KEY_M];
		dev_DECRYPTED[idx] = vigenere_decrypt(dev_ENCRYPTED[idx], key_char, KEY_M);
	}
}
__global__ void KernelOptimal() //Amennyire lehet shared memóriát használok olvasható adattagoknál
{
	

	int idx = blockIdx.x * blockDim.x + threadIdx.x;

	if (idx < KEY_M)
	{
		shr_KEY[idx] = dev_KEY[idx];
	}

	if (idx < TEXT_N) {

		shr_TEXT[idx] = dev_TEXT[idx];

		char key_char = shr_KEY[idx % KEY_M];
		dev_ENCRYPTED[idx] = vigenere_encrypt(shr_TEXT[idx], key_char, KEY_M);
	}
	__syncthreads();

	if (idx < TEXT_N) {
		char key_char = shr_KEY[idx % KEY_M];
		dev_DECRYPTED[idx] = vigenere_decrypt(dev_ENCRYPTED[idx], key_char, KEY_M);
	}
}


int main()
{
	//N hosszúságú szöveg létrehozása
	//titkosítás
	//Az eredeti és a titkos szöveg alapján fel kell törni a kulcsot
	//atomi művelet és L1 cache, dinamikusan foglaljuk a memmóriát
	//sharedve mehet a constant adat
	//időmérés CPU, GPU

	std::string abc = "ABCDEFGHIJKLMNOPQRSTUVWXYZ ";

	//TODO: Random text [500] karakter és [10] kulcs
	std::string TEXT = "";
	std::string KEY = "";
	std::string KEY_C = "";
	std::string ENCRYPTED = "";
	std::string DECRYPTED = "";

	char TEXTARRAY[TEXT_N];
	char KEY_ARRAY[KEY_M];
	char ENCRYPTED_ARRAY[TEXT_N];
	char DECRYPTED_ARRAY[TEXT_N];

	float t;

	for (int i = 0; i < TEXT_N; i++)
	{
		char ch = 'a' + rand() % 26;
		TEXT += ch;
	}

	for (int i = 0; i < KEY_M; i++)
	{
		char ch = 'a' + rand() % 26;
		KEY += ch;
	}

	cudaEvent_t start, stop;
	cudaEventCreate(&start);
	cudaEventRecord(start, 0);

	std::map<char, int> CharToInt;
	std::map<int, char> IntToChar;

	for (int i = 0; i <= abc.length(); i++)
	{
		CharToInt.insert({ (char)abc[i],i });
		IntToChar.insert({ i,(char)abc[i] });
	}

	//Kulcs fillelés és nagybetűssé alakítása
	for (int i = 0; i < TEXT.length(); i++)
	{

		for (int j = 0; j < KEY.length(); j++)
		{
			if (KEY_C.length()<TEXT.length())
			{
				KEY_C += (char)toupper(KEY[j]);

			}
		}
	}

	//Kulcs nagybetűssé alakítása
	for (int i = 0; i < KEY_M; i++)
	{
		KEY_ARRAY[i] = (char)toupper(KEY[i]);
	}

	//CPU MEGVALÓSÍTÁS
	//TEXT nagybetűssé alakítása
	for (int i = 0; i < TEXT.length(); i++)
	{
		TEXT[i] = (char)toupper(TEXT[i]);
		TEXTARRAY[i] = TEXT[i];
	}
	
	//encryption
	for (int i = 0; i < TEXT.length(); i++)
	{

		int charValue = CharToInt.at(TEXT[i]) + CharToInt.at(KEY_C[i]);
		int maradekos = charValue % (abc.length());

		//std::cout << CharToInt.at(TEXT[i]) << " ";
		ENCRYPTED += IntToChar.at(maradekos);
	}
	/*
	std::cout << " " << std::endl;
	for (int i = 0; i < TEXT.length(); i++)
	{

		int charValue = CharToInt.at(TEXT[i]) + CharToInt.at(KEY_C[i]);
		int maradekos = charValue % (abc.length());

		std::cout << CharToInt.at(KEY_C[i]) << " ";
		//ENCRYPTED += IntToChar.at(maradekos);
	}
	std::cout << " " << std::endl;
	for (int i = 0; i < TEXT.length(); i++)
	{

		int charValue = CharToInt.at(TEXT[i]) + CharToInt.at(KEY_C[i]);
		int maradekos = charValue % (abc.length());

		std::cout << charValue << " ";
		//ENCRYPTED += IntToChar.at(maradekos);
	}
	*/


	//decrypt
	for (int i = 0; i < ENCRYPTED.length(); i++)
	{
		int charValue = CharToInt.at(ENCRYPTED[i]) - CharToInt.at(KEY_C[i]);
		int maradekos = charValue % (abc.length());

		DECRYPTED += IntToChar.at(maradekos);
	}

	cudaEventCreate(&stop);
	cudaEventRecord(stop, 0);
	cudaEventSynchronize(stop);
	cudaEventElapsedTime(&t, start, stop);
	
	//outputCPU
	/*std::cout << "Original Text: ";
	for (int i = 0; i < TEXT.length(); i++)
	{
		std::cout << TEXT[i];
	}
	std::cout << " "<<std::endl;
	std::cout << " " << std::endl;
	std::cout << "Encrypted Text: ";
	for (int i = 0; i < ENCRYPTED.length(); i++)
	{
		std::cout << ENCRYPTED[i];
	}
	std::cout << " " << std::endl;
	std::cout << " " << std::endl;
	std::cout << "Decrypted Text: ";
	for (int i = 0; i < DECRYPTED.length(); i++)
	{
		std::cout << DECRYPTED[i];
	}
	std::cout << " " << std::endl;*/
	std::cout << " " << std::endl;
	std::cout << "Time elapsed: ";
	std::cout << t << " ms";
	std::cout << " " << std::endl;

	//GPU
	//---------------------------
	cudaMemcpyToSymbol(dev_KEY,KEY_ARRAY,KEY_M * sizeof(char));
	cudaMemcpyToSymbol(dev_TEXT,TEXTARRAY,TEXT_N * sizeof(char));
	
	cudaEvent_t start1, stop1;
	cudaEventCreate(&start1);
	cudaEventRecord(start1, 0);
	float t1;

	int block_count = (TEXT_N - 1) / BLOCK_SIZE + 1;

	Kernel << <block_count,BLOCK_SIZE >> > ();

	cudaEventCreate(&stop1);
	cudaEventRecord(stop1, 0);
	cudaEventSynchronize(stop1);
	cudaEventElapsedTime(&t1, start1, stop1);

	//itt még lehet gatya
	cudaMemcpyFromSymbol(ENCRYPTED_ARRAY,dev_ENCRYPTED,TEXT_N * sizeof(char));
	cudaMemcpyFromSymbol(DECRYPTED_ARRAY, dev_DECRYPTED, TEXT_N * sizeof(char));

	std::string EredmenyGPU1 = "";
	std::string EredmenyGPU2 = "";

	std::string EredmenyGPU3 = "";
	std::string EredmenyGPU4 = "";

	for (int i = 0; i < TEXT_N; i++)
	{
		EredmenyGPU1 += ENCRYPTED_ARRAY[i];
		EredmenyGPU2 += DECRYPTED_ARRAY[i];
	}



	std::cout << "-------------------------------------------------------------------------";
	std::cout << std::endl;
	std::cout << "GPUS megoldas #1"<<std::endl;
	std::cout << std::endl;
	/*std::cout << "Encrypted Text: " << EredmenyGPU1 <<std::endl;
	std::cout << std::endl;
	std::cout << "Decrypted Text: " << EredmenyGPU2 << std::endl;
	std::cout << std::endl;*/
	std::cout << "Time elapsed: " << t1 <<" ms" << std::endl;
	std::cout << std::endl;


	//Megoldások a második részre:

	char OptimalEncrypted[TEXT_N];
	char OptimalDecrypted[TEXT_N];

	//dst,src,count, cuda
	
	cudaFuncSetCacheConfig(KernelOptimal, cudaFuncCachePreferEqual);
	float t3;

	cudaMemcpyToSymbol(dev_KEY, KEY_ARRAY, KEY_M * sizeof(char));
	cudaMemcpyToSymbol(dev_TEXT, TEXTARRAY, TEXT_N * sizeof(char));

	cudaEvent_t start2, stop2;
	cudaEventCreate(&start2);
	cudaEventRecord(start2, 0);
	
	//Harmadik paraméter a extern shared memóriához kell.
	KernelOptimal << <block_count, BLOCK_SIZE>> > ();

	cudaEventCreate(&stop2);
	cudaEventRecord(stop2, 0);
	cudaEventSynchronize(stop2);
	cudaEventElapsedTime(&t3, start2, stop2);

	cudaMemcpyFromSymbol(OptimalEncrypted, dev_ENCRYPTED, TEXT_N * sizeof(char));
	cudaMemcpyFromSymbol(OptimalDecrypted, dev_DECRYPTED, TEXT_N * sizeof(char));


	for (int i = 0; i < TEXT_N; i++)
	{
		EredmenyGPU3 += OptimalEncrypted[i];
		EredmenyGPU4 += OptimalDecrypted[i];
	}
	;
	//GPU optimalizált megoldása
	std::cout << "-------------------------------------------------------------------------";
	std::cout << std::endl;
	std::cout << "GPUS megoldas #2 (Optimal)" << std::endl;
	std::cout << std::endl;
	/*std::cout << "Encrypted Text: " << EredmenyGPU3 << std::endl;
	std::cout << std::endl;
	std::cout << "Decrypted Text: " << EredmenyGPU4 << std::endl;*/
	//std::cout << std::endl;
	std::cout << "Time elapsed: " << t3 << " ms" << std::endl;
	std::cout << std::endl;
	std::cout << std::endl;

	//maxthreadsinblock:1024,49152shm,65536regspblock,65536 total const memory
	cudaDeviceProp a;
	cudaGetDeviceProperties(&a,0);
	;
}

