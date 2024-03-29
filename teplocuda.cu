#include <stdio.h>
#include <math.h>
#include <stdlib.h>
#include <time.h>
#include <cuda_runtime.h>
#include <cub/cub.cuh>
#include <cuda.h>


__global__
void countnewmatrix(double* mas_old, double* mas, size_t size)
{
	size_t i = blockIdx.x;
	size_t j = threadIdx.x;

	if (!(blockIdx.x == 0 || threadIdx.x == 0))
		mas[i * size + j] = 0.25 * (mas_old[i * size + j - 1] + mas_old[(i - 1) * size + j] + mas_old[(i + 1) * size + j] + mas_old[i * size + j + 1]);
	
}
__global__
void finderr(double* mas_old, double* mas, double* outMatrix)
{
	size_t idx = blockIdx.x * blockDim.x + threadIdx.x;

	if (!(blockIdx.x == 0 || threadIdx.x == 0))
		outMatrix[idx] = fabs(mas[idx] - mas_old[idx]);
	
}




int main(int argc, char** argv) {
	int SIZE;
	double err_max;
	int iter_max;

	SIZE = atoi(argv[2]);
	err_max = atof(argv[1]);
	iter_max = atoi(argv[3]);


	clock_t start;
	start = clock();


	double* mas = (double*)calloc(SIZE * SIZE, sizeof(double));
	double* mas_old = (double*)calloc(SIZE * SIZE, sizeof(double));

	mas[0] = 10;
	mas[SIZE - 1] = 20;
	mas[(SIZE) * (SIZE - 1)] = 20;
	mas[(SIZE) * (SIZE)-1] = 30;



	for (int i = 1; i < SIZE - 1; i++)
		mas[i] = mas[i - 1] + (mas[SIZE - 1] - mas[0]) / SIZE;

	for (int i = 1; i < SIZE - 1; i++) {
		mas[SIZE * (SIZE - 1) + i] = mas[SIZE * (SIZE - 1) + i - 1] + (mas[(SIZE) * (SIZE)-1] - mas[(SIZE) * (SIZE - 1)]) / SIZE;
		mas[(SIZE) * (i)] = mas[(i - 1) * (SIZE)] + (mas[(SIZE) * (SIZE - 1)] - mas[0]) / SIZE;
		mas[(SIZE) * (i)+(SIZE - 1)] = mas[(SIZE) * (i - 1) + (SIZE - 1)] + (mas[(SIZE) * (SIZE)-1] - mas[SIZE - 1]) / SIZE;
	}


	int iter = 0;
	double err = 1.0;


	for (int i = 0; i < SIZE * SIZE; i++) 
		mas_old[i] = mas[i];


	


	cudaSetDevice(3);

	double* mas_old_dev, * mas_dev, * deviceError, * errorMatrix, * tempStorage = NULL; //Device-accessible allocation of temporary storage
	size_t tempStorageSize = 0;

	cudaMalloc((void**)(&mas_old_dev), sizeof(double) * SIZE*SIZE);
	cudaMalloc((void**)(&mas_dev), sizeof(double) * SIZE*SIZE);
	cudaMalloc((void**)&deviceError, sizeof(double));
	cudaMalloc((void**)&errorMatrix, sizeof(double) * SIZE*SIZE);

	cudaMemcpy(mas_old_dev, mas_old, sizeof(double) * SIZE*SIZE, cudaMemcpyHostToDevice);
	cudaMemcpy(mas_dev, mas, sizeof(double) * SIZE*SIZE, cudaMemcpyHostToDevice);

	// Determine temporary device storage requirements
	cub::DeviceReduce::Max(tempStorage, tempStorageSize, errorMatrix, deviceError, SIZE * SIZE);
	// Allocate temporary storage
	cudaMalloc(&tempStorage, tempStorageSize);
	


		while ((err > err_max) && iter < iter_max) {
			iter += 1;
			countnewmatrix <<<SIZE - 1, SIZE - 1 >>> (mas_old_dev, mas_dev, SIZE);

			if (iter % 100 == 0 && iter !=1)
			{
				finderr <<<SIZE - 1, SIZE - 1>>> (mas_old_dev, mas_dev, errorMatrix);

				cub::DeviceReduce::Max(tempStorage, tempStorageSize, errorMatrix, deviceError, SIZE*SIZE);
				cudaMemcpy(&err, deviceError, sizeof(double), cudaMemcpyDeviceToHost);

				double t = (double)(clock() - start) / CLOCKS_PER_SEC;
				printf(" time: %lf\n", t);
				printf("%d  %lf", iter, err);
				printf("\n");

			}
				double* m = mas_dev;
				mas_dev = mas_old_dev;
				mas_old_dev = m;
			
		}

	cudaFree(mas_old_dev);
	cudaFree(mas_dev);
	cudaFree(errorMatrix);
	cudaFree(tempStorage);
	//for (int i = 0; i < SIZE * SIZE; i++)
	free(mas_old);

	//for (int i = 0; i < SIZE*SIZE; i++)
	free(mas);

	double t = (double)(clock() - start) / CLOCKS_PER_SEC;
	printf(" time: %lf\n", t);
	return EXIT_SUCCESS;

}