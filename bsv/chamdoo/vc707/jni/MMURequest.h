#include "GeneratedTypes.h"
#ifndef _MMUREQUEST_H_
#define _MMUREQUEST_H_
#include "portal.h"

class MMURequestProxy : public Portal {
public:
    MMURequestProxy(int id, PortalPoller *poller = 0) : Portal(id, MMURequest_reqinfo, NULL, NULL, poller) {};
    MMURequestProxy(int id, PortalItemFunctions *item, void *param, PortalPoller *poller = 0) : Portal(id, MMURequest_reqinfo, NULL, NULL, item, param, poller) {};
    int sglist ( const uint32_t sglId, const uint32_t sglIndex, const uint64_t addr, const uint32_t len ) { return MMURequest_sglist (&pint, sglId, sglIndex, addr, len); };
    int region ( const uint32_t sglId, const uint64_t barr8, const uint32_t index8, const uint64_t barr4, const uint32_t index4, const uint64_t barr0, const uint32_t index0 ) { return MMURequest_region (&pint, sglId, barr8, index8, barr4, index4, barr0, index0); };
    int idRequest ( const SpecialTypeForSendingFd fd ) { return MMURequest_idRequest (&pint, fd); };
    int idReturn ( const uint32_t sglId ) { return MMURequest_idReturn (&pint, sglId); };
    int setInterface ( const uint32_t interfaceId, const uint32_t sglId ) { return MMURequest_setInterface (&pint, interfaceId, sglId); };
};

extern MMURequestCb MMURequest_cbTable;
class MMURequestWrapper : public Portal {
public:
    MMURequestWrapper(int id, PortalPoller *poller = 0) : Portal(id, MMURequest_reqinfo, MMURequest_handleMessage, (void *)&MMURequest_cbTable, poller) {
        pint.parent = static_cast<void *>(this);
    };
    MMURequestWrapper(int id, PortalItemFunctions *item, void *param, PortalPoller *poller = 0) : Portal(id, MMURequest_reqinfo, MMURequest_handleMessage, (void *)&MMURequest_cbTable, item, param, poller) {
        pint.parent = static_cast<void *>(this);
    };
    virtual void sglist ( const uint32_t sglId, const uint32_t sglIndex, const uint64_t addr, const uint32_t len ) = 0;
    virtual void region ( const uint32_t sglId, const uint64_t barr8, const uint32_t index8, const uint64_t barr4, const uint32_t index4, const uint64_t barr0, const uint32_t index0 ) = 0;
    virtual void idRequest ( const SpecialTypeForSendingFd fd ) = 0;
    virtual void idReturn ( const uint32_t sglId ) = 0;
    virtual void setInterface ( const uint32_t interfaceId, const uint32_t sglId ) = 0;
};
#endif // _MMUREQUEST_H_
