#include <string.h>

class BluecacheClient{

public:
  BluecacheClient();
  ~BluecacheClient();

  int clientId();

  char* get(char* key, size_t keylen, size_t* vallen);

  bool set(char* key, char* val, size_t keylen, size_t vallen);
                                
  bool del(char* key, size_t keylen);

private:
  int threadId;

};
