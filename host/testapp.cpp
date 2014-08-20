#include "MemcachedClient.h"
#include <stdlib.h>

int main(){
   MemcachedClient *client = new MemcachedClient();

   srand(time(NULL));

   client->initSystem(8,16,32, 1<<25, 1<<26, 1<<27);
   for ( int k = 0; k < 256; k++ ){
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
   }
     
}
