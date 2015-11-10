#ifndef __GENERATED_TYPES__
#define __GENERATED_TYPES__
#include "portal.h"
#ifdef __cplusplus
extern "C" {
#endif
typedef enum IfcNames { IfcNames_BluecacheIndication, IfcNames_BluecacheRequest, IfcNames_HostMemServerIndication, IfcNames_HostMemServerRequest, IfcNames_HostMMURequest, IfcNames_HostMMUIndication } IfcNames;
typedef enum ChannelType { ChannelType_Read, ChannelType_Write } ChannelType;
typedef struct DmaDbgRec {
    uint32_t x : 32;
    uint32_t y : 32;
    uint32_t z : 32;
    uint32_t w : 32;
} DmaDbgRec;
typedef enum DmaErrorType { DmaErrorType_DmaErrorNone, DmaErrorType_DmaErrorSGLIdOutOfRange_r, DmaErrorType_DmaErrorSGLIdOutOfRange_w, DmaErrorType_DmaErrorMMUOutOfRange_r, DmaErrorType_DmaErrorMMUOutOfRange_w, DmaErrorType_DmaErrorOffsetOutOfRange, DmaErrorType_DmaErrorSGLIdInvalid } DmaErrorType;


int BluecacheRequest_eraseBlock ( struct PortalInternal *p, const uint32_t bus, const uint32_t chip, const uint32_t block, const uint32_t tag );
int BluecacheRequest_populateMap ( struct PortalInternal *p, const uint32_t idx, const uint32_t data );
int BluecacheRequest_dumpMap ( struct PortalInternal *p, const uint32_t dummy );
int BluecacheRequest_initDMARefs ( struct PortalInternal *p, const uint32_t rp, const uint32_t wp );
int BluecacheRequest_startRead ( struct PortalInternal *p, const uint32_t rp, const uint32_t numBytes );
int BluecacheRequest_freeWriteBufId ( struct PortalInternal *p, const uint32_t wp );
int BluecacheRequest_initDMABufSz ( struct PortalInternal *p, const uint32_t bufSz );
int BluecacheRequest_initTable ( struct PortalInternal *p, const uint64_t lgOffset );
int BluecacheRequest_initValDelimit ( struct PortalInternal *p, const uint32_t randMax1, const uint32_t randMax2, const uint32_t randMax3, const uint32_t lgSz1, const uint32_t lgSz2, const uint32_t lgSz3 );
int BluecacheRequest_initAddrDelimit ( struct PortalInternal *p, const uint32_t offset1, const uint32_t offset2, const uint32_t offset3 );
int BluecacheRequest_reset ( struct PortalInternal *p, const uint32_t randNum );
int BluecacheRequest_recvData_0 ( struct PortalInternal *p, const uint32_t v );
int BluecacheRequest_recvData_1 ( struct PortalInternal *p, const uint32_t v );
int BluecacheRequest_recvData_2 ( struct PortalInternal *p, const uint32_t v );
enum { CHAN_NUM_BluecacheRequest_eraseBlock,CHAN_NUM_BluecacheRequest_populateMap,CHAN_NUM_BluecacheRequest_dumpMap,CHAN_NUM_BluecacheRequest_initDMARefs,CHAN_NUM_BluecacheRequest_startRead,CHAN_NUM_BluecacheRequest_freeWriteBufId,CHAN_NUM_BluecacheRequest_initDMABufSz,CHAN_NUM_BluecacheRequest_initTable,CHAN_NUM_BluecacheRequest_initValDelimit,CHAN_NUM_BluecacheRequest_initAddrDelimit,CHAN_NUM_BluecacheRequest_reset,CHAN_NUM_BluecacheRequest_recvData_0,CHAN_NUM_BluecacheRequest_recvData_1,CHAN_NUM_BluecacheRequest_recvData_2};
#define BluecacheRequest_reqinfo 0xe001c

int BluecacheRequest_handleMessage(struct PortalInternal *p, unsigned int channel, int messageFd);
typedef struct {
    void (*eraseBlock) (  struct PortalInternal *p, const uint32_t bus, const uint32_t chip, const uint32_t block, const uint32_t tag );
    void (*populateMap) (  struct PortalInternal *p, const uint32_t idx, const uint32_t data );
    void (*dumpMap) (  struct PortalInternal *p, const uint32_t dummy );
    void (*initDMARefs) (  struct PortalInternal *p, const uint32_t rp, const uint32_t wp );
    void (*startRead) (  struct PortalInternal *p, const uint32_t rp, const uint32_t numBytes );
    void (*freeWriteBufId) (  struct PortalInternal *p, const uint32_t wp );
    void (*initDMABufSz) (  struct PortalInternal *p, const uint32_t bufSz );
    void (*initTable) (  struct PortalInternal *p, const uint64_t lgOffset );
    void (*initValDelimit) (  struct PortalInternal *p, const uint32_t randMax1, const uint32_t randMax2, const uint32_t randMax3, const uint32_t lgSz1, const uint32_t lgSz2, const uint32_t lgSz3 );
    void (*initAddrDelimit) (  struct PortalInternal *p, const uint32_t offset1, const uint32_t offset2, const uint32_t offset3 );
    void (*reset) (  struct PortalInternal *p, const uint32_t randNum );
    void (*recvData_0) (  struct PortalInternal *p, const uint32_t v );
    void (*recvData_1) (  struct PortalInternal *p, const uint32_t v );
    void (*recvData_2) (  struct PortalInternal *p, const uint32_t v );
} BluecacheRequestCb;

int BluecacheIndication_initDone ( struct PortalInternal *p, const uint32_t dummy );
int BluecacheIndication_rdDone ( struct PortalInternal *p, const uint32_t bufId );
int BluecacheIndication_wrDone ( struct PortalInternal *p, const uint32_t bufId );
int BluecacheIndication_sendData_0 ( struct PortalInternal *p, const uint32_t v );
int BluecacheIndication_elementReq_0 ( struct PortalInternal *p, const uint32_t v );
int BluecacheIndication_sendData_1 ( struct PortalInternal *p, const uint32_t v );
int BluecacheIndication_elementReq_1 ( struct PortalInternal *p, const uint32_t v );
int BluecacheIndication_sendData_2 ( struct PortalInternal *p, const uint32_t v );
int BluecacheIndication_elementReq_2 ( struct PortalInternal *p, const uint32_t v );
enum { CHAN_NUM_BluecacheIndication_initDone,CHAN_NUM_BluecacheIndication_rdDone,CHAN_NUM_BluecacheIndication_wrDone,CHAN_NUM_BluecacheIndication_sendData_0,CHAN_NUM_BluecacheIndication_elementReq_0,CHAN_NUM_BluecacheIndication_sendData_1,CHAN_NUM_BluecacheIndication_elementReq_1,CHAN_NUM_BluecacheIndication_sendData_2,CHAN_NUM_BluecacheIndication_elementReq_2};
#define BluecacheIndication_reqinfo 0x90008

int BluecacheIndication_handleMessage(struct PortalInternal *p, unsigned int channel, int messageFd);
typedef struct {
    void (*initDone) (  struct PortalInternal *p, const uint32_t dummy );
    void (*rdDone) (  struct PortalInternal *p, const uint32_t bufId );
    void (*wrDone) (  struct PortalInternal *p, const uint32_t bufId );
    void (*sendData_0) (  struct PortalInternal *p, const uint32_t v );
    void (*elementReq_0) (  struct PortalInternal *p, const uint32_t v );
    void (*sendData_1) (  struct PortalInternal *p, const uint32_t v );
    void (*elementReq_1) (  struct PortalInternal *p, const uint32_t v );
    void (*sendData_2) (  struct PortalInternal *p, const uint32_t v );
    void (*elementReq_2) (  struct PortalInternal *p, const uint32_t v );
} BluecacheIndicationCb;

int MemServerRequest_addrTrans ( struct PortalInternal *p, const uint32_t sglId, const uint32_t offset );
int MemServerRequest_stateDbg ( struct PortalInternal *p, const ChannelType rc );
int MemServerRequest_memoryTraffic ( struct PortalInternal *p, const ChannelType rc );
enum { CHAN_NUM_MemServerRequest_addrTrans,CHAN_NUM_MemServerRequest_stateDbg,CHAN_NUM_MemServerRequest_memoryTraffic};
#define MemServerRequest_reqinfo 0x3000c

int MemServerRequest_handleMessage(struct PortalInternal *p, unsigned int channel, int messageFd);
typedef struct {
    void (*addrTrans) (  struct PortalInternal *p, const uint32_t sglId, const uint32_t offset );
    void (*stateDbg) (  struct PortalInternal *p, const ChannelType rc );
    void (*memoryTraffic) (  struct PortalInternal *p, const ChannelType rc );
} MemServerRequestCb;

int MMURequest_sglist ( struct PortalInternal *p, const uint32_t sglId, const uint32_t sglIndex, const uint64_t addr, const uint32_t len );
int MMURequest_region ( struct PortalInternal *p, const uint32_t sglId, const uint64_t barr8, const uint32_t index8, const uint64_t barr4, const uint32_t index4, const uint64_t barr0, const uint32_t index0 );
int MMURequest_idRequest ( struct PortalInternal *p, const SpecialTypeForSendingFd fd );
int MMURequest_idReturn ( struct PortalInternal *p, const uint32_t sglId );
int MMURequest_setInterface ( struct PortalInternal *p, const uint32_t interfaceId, const uint32_t sglId );
enum { CHAN_NUM_MMURequest_sglist,CHAN_NUM_MMURequest_region,CHAN_NUM_MMURequest_idRequest,CHAN_NUM_MMURequest_idReturn,CHAN_NUM_MMURequest_setInterface};
#define MMURequest_reqinfo 0x5002c

int MMURequest_handleMessage(struct PortalInternal *p, unsigned int channel, int messageFd);
typedef struct {
    void (*sglist) (  struct PortalInternal *p, const uint32_t sglId, const uint32_t sglIndex, const uint64_t addr, const uint32_t len );
    void (*region) (  struct PortalInternal *p, const uint32_t sglId, const uint64_t barr8, const uint32_t index8, const uint64_t barr4, const uint32_t index4, const uint64_t barr0, const uint32_t index0 );
    void (*idRequest) (  struct PortalInternal *p, const SpecialTypeForSendingFd fd );
    void (*idReturn) (  struct PortalInternal *p, const uint32_t sglId );
    void (*setInterface) (  struct PortalInternal *p, const uint32_t interfaceId, const uint32_t sglId );
} MMURequestCb;

int MemServerIndication_addrResponse ( struct PortalInternal *p, const uint64_t physAddr );
int MemServerIndication_reportStateDbg ( struct PortalInternal *p, const DmaDbgRec rec );
int MemServerIndication_reportMemoryTraffic ( struct PortalInternal *p, const uint64_t words );
int MemServerIndication_error ( struct PortalInternal *p, const uint32_t code, const uint32_t sglId, const uint64_t offset, const uint64_t extra );
enum { CHAN_NUM_MemServerIndication_addrResponse,CHAN_NUM_MemServerIndication_reportStateDbg,CHAN_NUM_MemServerIndication_reportMemoryTraffic,CHAN_NUM_MemServerIndication_error};
#define MemServerIndication_reqinfo 0x4001c

int MemServerIndication_handleMessage(struct PortalInternal *p, unsigned int channel, int messageFd);
typedef struct {
    void (*addrResponse) (  struct PortalInternal *p, const uint64_t physAddr );
    void (*reportStateDbg) (  struct PortalInternal *p, const DmaDbgRec rec );
    void (*reportMemoryTraffic) (  struct PortalInternal *p, const uint64_t words );
    void (*error) (  struct PortalInternal *p, const uint32_t code, const uint32_t sglId, const uint64_t offset, const uint64_t extra );
} MemServerIndicationCb;

int MMUIndication_idResponse ( struct PortalInternal *p, const uint32_t sglId );
int MMUIndication_configResp ( struct PortalInternal *p, const uint32_t sglId );
int MMUIndication_error ( struct PortalInternal *p, const uint32_t code, const uint32_t sglId, const uint64_t offset, const uint64_t extra );
enum { CHAN_NUM_MMUIndication_idResponse,CHAN_NUM_MMUIndication_configResp,CHAN_NUM_MMUIndication_error};
#define MMUIndication_reqinfo 0x3001c

int MMUIndication_handleMessage(struct PortalInternal *p, unsigned int channel, int messageFd);
typedef struct {
    void (*idResponse) (  struct PortalInternal *p, const uint32_t sglId );
    void (*configResp) (  struct PortalInternal *p, const uint32_t sglId );
    void (*error) (  struct PortalInternal *p, const uint32_t code, const uint32_t sglId, const uint64_t offset, const uint64_t extra );
} MMUIndicationCb;
#ifdef __cplusplus
}
#endif
#endif //__GENERATED_TYPES__
