A project I made for my CUDA course assignment in university

The program measures the time it takes for the CPU and the GPU to calculate and cypher input strings with the Vigenére cipher. My solution also includes a de-ciphering process which is also included in the time.
To get more accurate results I did not inculde the time it takes to allocate memory, so the event pipeline for measuring time is only started after the memory allocation is done. This can be said for both the CPU and GPU.

The program calculates the solution first on the CPU (C++).
Then a suboptimal GPU solution to test the time the GPU takes to calculate the cypher and decypher process.
Finally a solution that uses optimal memory optimizations with shared and cache memory. 
