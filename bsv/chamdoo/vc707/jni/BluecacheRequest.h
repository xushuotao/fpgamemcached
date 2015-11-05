#include "GeneratedTypes.h"
#ifndef _BLUECACHEREQUEST_H_
#define _BLUECACHEREQUEST_H_
#include "portal.h"

class BluecacheRequestProxy : public Portal {
public:
    BluecacheRequestProxy(int id, PortalPoller *poller = 0) : Portal(id, BluecacheRequest_reqinfo, NULL, NULL, poller) {};
    BluecacheRequestProxy(int id, PortalItemFunctions *item, void *param, PortalPoller *poller = 0) : Portal(id, BluecacheRequest_reqinfo, NULL, NULL, item, param, poller) {};
    int eraseBlock ( const uint32_t bus, const uint32_t chip, const uint32_t block, const uint32_t tag ) { return BluecacheRequest_eraseBlock (&pint, bus, chip, block, tag); };
    int populateMap ( const uint32_t idx, const uint32_t data ) { return BluecacheRequest_populateMap (&pint, idx, data); };
    int dumpMap ( const uint32_t dummy ) { return BluecacheRequest_dumpMap (&pint, dummy); };
    int initDMARefs ( const uint32_t rp, const uint32_t wp ) { return BluecacheRequest_initDMARefs (&pint, rp, wp); };
    int startRead ( const uint32_t rp, const uint32_t numBytes ) { return BluecacheRequest_startRead (&pint, rp, numBytes); };
    int freeWriteBufId ( const uint32_t wp ) { return BluecacheRequest_freeWriteBufId (&pint, wp); };
    int initDMABufSz ( const uint32_t bufSz ) { return BluecacheRequest_initDMABufSz (&pint, bufSz); };
    int initTable ( const uint64_t lgOffset ) { return BluecacheRequest_initTable (&pint, lgOffset); };
    int initValDelimit ( const uint32_t randMax1, const uint32_t randMax2, const uint32_t randMax3, const uint32_t lgSz1, const uint32_t lgSz2, const uint32_t lgSz3 ) { return BluecacheRequest_initValDelimit (&pint, randMax1, randMax2, randMax3, lgSz1, lgSz2, lgSz3); };
    int initAddrDelimit ( const uint32_t offset1, const uint32_t offset2, const uint32_t offset3 ) { return BluecacheRequest_initAddrDelimit (&pint, offset1, offset2, offset3); };
    int reset ( const uint32_t randNum ) { return BluecacheRequest_reset (&pint, randNum); };
    int recvData_0 ( const uint32_t v ) { return BluecacheRequest_recvData_0 (&pint, v); };
    int recvData_1 ( const uint32_t v ) { return BluecacheRequest_recvData_1 (&pint, v); };
    int recvData_2 ( const uint32_t v ) { return BluecacheRequest_recvData_2 (&pint, v); };
};

extern BluecacheRequestCb BluecacheRequest_cbTable;
class BluecacheRequestWrapper : public Portal {
public:
    BluecacheRequestWrapper(int id, PortalPoller *poller = 0) : Portal(id, BluecacheRequest_reqinfo, BluecacheRequest_handleMessage, (void *)&BluecacheRequest_cbTable, poller) {
        pint.parent = static_cast<void *>(this);
    };
    BluecacheRequestWrapper(int id, PortalItemFunctions *item, void *param, PortalPoller *poller = 0) : Portal(id, BluecacheRequest_reqinfo, BluecacheRequest_handleMessage, (void *)&BluecacheRequest_cbTable, item, param, poller) {
        pint.parent = static_cast<void *>(this);
    };
    virtual void eraseBlock ( const uint32_t bus, const uint32_t chip, const uint32_t block, const uint32_t tag ) = 0;
    virtual void populateMap ( const uint32_t idx, const uint32_t data ) = 0;
    virtual void dumpMap ( const uint32_t dummy ) = 0;
    virtual void initDMARefs ( const uint32_t rp, const uint32_t wp ) = 0;
    virtual void startRead ( const uint32_t rp, const uint32_t numBytes ) = 0;
    virtual void freeWriteBufId ( const uint32_t wp ) = 0;
    virtual void initDMABufSz ( const uint32_t bufSz ) = 0;
    virtual void initTable ( const uint64_t lgOffset ) = 0;
    virtual void initValDelimit ( const uint32_t randMax1, const uint32_t randMax2, const uint32_t randMax3, const uint32_t lgSz1, const uint32_t lgSz2, const uint32_t lgSz3 ) = 0;
    virtual void initAddrDelimit ( const uint32_t offset1, const uint32_t offset2, const uint32_t offset3 ) = 0;
    virtual void reset ( const uint32_t randNum ) = 0;
    virtual void recvData_0 ( const uint32_t v ) = 0;
    virtual void recvData_1 ( const uint32_t v ) = 0;
    virtual void recvData_2 ( const uint32_t v ) = 0;
};
#endif // _BLUECACHEREQUEST_H_
