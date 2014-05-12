#include <MemcachedClient.h>
//#include <string>
/*
class ServerIndication : public ServerIndicationWrapper
{  
public:
   virtual void hexdump(uint64_t a) {
      printf("hexdump: %016x\n", a);
   }
};
*/
int main(){
   MemcachedClient *client = new MemcachedClient();

   char* key ="Hello";
   char* value ="World";
   //printf("%d",key);
   client->set(key, strlen(key), value, strlen(value));
}
