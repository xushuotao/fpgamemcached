#include "MemcachedClient.h"
#include <stdlib.h>
#include <string.h>

#include <time.h>
#include <sys/time.h>
#include <iostream>

int main(){
   MemcachedClient *client = new MemcachedClient();

   srand(time(NULL));
   
   client->initSystem(8,16,32, 1<<25, 1<<26, 1<<27);

   //clock_t t1, t2;
   //float diff_t, sum_t_set=0, sum_t_get=0;
   /*   time_t t1, t2;
        double diff_t, sum_t_set=0, sum_t_get=0;*/
   timeval t1, t2;
   double elapsedTime, avg_t_set=0, avg_t_get=0;

   int iters = 20000;

   int valSz;
   std::cout << "Input value size: ";
   std::cin >> valSz;

   for ( int k = 0; k < iters; k++ ){
     int keySz = 64;
     //int valSz = 64;
   
     char* key = (char*) malloc (keySz);
     char* value = (char*) malloc(valSz);

     int i;
     for (i=0; i<keySz; i++)
       key[i]=rand()%26+'a';

   
     for (i=0; i<valSz; i++)
       value[i]=rand()%26+'a';
   
     gettimeofday(&t1, NULL);
     client->set(key, keySz, value, valSz);
     gettimeofday(&t2, NULL);
     elapsedTime = (t2.tv_sec - t1.tv_sec) * 1000.0;      // sec to ms
     elapsedTime += (t2.tv_usec - t1.tv_usec) / 1000.0;   // us to ms
     printf("Main:: Done executing set in %lf millisecs\n", elapsedTime );
     avg_t_set = (avg_t_set * i + elapsedTime)/(i+1);


     gettimeofday(&t1, NULL);
     char *data = client->get(key, keySz);
     gettimeofday(&t2, NULL);
     elapsedTime = (t2.tv_sec - t1.tv_sec) * 1000.0;      // sec to ms
     elapsedTime += (t2.tv_usec - t1.tv_usec) / 1000.0;   // us to ms
     printf("Main:: Done executing get in %lf millisecs\n", elapsedTime );
     //sum_t_get += elapsedTime;
     avg_t_get = (avg_t_get * i + elapsedTime)/(i+1);


     if ( memcmp(data, value, valSz) == 0 )
       printf("Main:: %dth run PASS:)\n",k);
     else{
       printf("Main:: %dth run FAIL:(\n",k);
       for ( int j = 0; j < valSz; j++ ){
         printf("byte: value[%d] = %02x, data[%d] = %02x: ", j, value[j], j, data[j]);
         if ( value[j] == data[j] ) printf("Equals\n");
         else printf("Not Equal!!\n");
       }
       exit(0);
     }
   //     printf("Main:: data = %s\n", data);
   }

   printf("Set: %f miliseconds\n", avg_t_set);
   printf("Get: %f miliseconds\n", avg_t_get);
   printf("Get: %f queries per second\n", 1000.0/avg_t_get);
   printf("Set: %f queries per second\n", 1000.0/avg_t_set);

   /*for ( int k = 0; k < 256; k++ ){
     int keySz = rand()%256;
     int valSz = rand()%256;
   
     char* key = (char*) malloc (keySz);
     char* value = (char*) malloc(valSz);

     int i;
     for (i=0; i<keySz; i++)
       key[i]=rand()%26+'a';

   
     for (i=0; i<valSz; i++)
       value[i]=rand()%26+'a';

   
     //char* key ="HelloHello";
     //char* value ="World!";

     //uint8_t *k0 = (uint8_t*)key;
     //uint32_t *k1 = (uint32_t*)key;
   
     //printf("Main::%02x, %02x, %02x, %02x\n", k0[0], k0[1], k0[2], k0[3]);
     //printf("Main::%04x\n", k1[0]);
   
     //printf("%d",key);
   

     client->set(key, keySz, value, valSz);
     printf("Main:: Done executing set\n");

     //sleep(2);
     char* data = client->get(key, keySz);
   
     if ( memcmp(data, value, valSz) == 0 )
       printf("Main:: %dth run PASS:)\n",k);
     else{
       printf("Main:: %dth run FAIL:(\n",k);
       for ( int j = 0; j < valSz; j++ ){
         printf("byte: value[%d] = %02x, data[%d] = %02x: ", j, value[j], j, data[j]);
         if ( value[j] == data[j] ) printf("Equals\n");
         else printf("Not Equal!!\n");
       }
       exit(0);
     }
   //     printf("Main:: data = %s\n", data);
   }*/
     
}
