#include "GeneratedTypes.h"
#ifndef _MEMSERVERINDICATION_H_
#define _MEMSERVERINDICATION_H_
#include "portal.h"

class MemServerIndicationProxy : public Portal {
public:
    MemServerIndicationProxy(int id, PortalPoller *poller = 0) : Portal(id, MemServerIndication_reqinfo, NULL, NULL, poller) {};
    MemServerIndicationProxy(int id, PortalItemFunctions *item, void *param, PortalPoller *poller = 0) : Portal(id, MemServerIndication_reqinfo, NULL, NULL, item, param, poller) {};
    int addrResponse ( const uint64_t physAddr ) { return MemServerIndication_addrResponse (&pint, physAddr); };
    int reportStateDbg ( const DmaDbgRec rec ) { return MemServerIndication_reportStateDbg (&pint, rec); };
    int reportMemoryTraffic ( const uint64_t words ) { return MemServerIndication_reportMemoryTraffic (&pint, words); };
    int error ( const uint32_t code, const uint32_t sglId, const uint64_t offset, const uint64_t extra ) { return MemServerIndication_error (&pint, code, sglId, offset, extra); };
};

extern MemServerIndicationCb MemServerIndication_cbTable;
class MemServerIndicationWrapper : public Portal {
public:
    MemServerIndicationWrapper(int id, PortalPoller *poller = 0) : Portal(id, MemServerIndication_reqinfo, MemServerIndication_handleMessage, (void *)&MemServerIndication_cbTable, poller) {
        pint.parent = static_cast<void *>(this);
    };
    MemServerIndicationWrapper(int id, PortalItemFunctions *item, void *param, PortalPoller *poller = 0) : Portal(id, MemServerIndication_reqinfo, MemServerIndication_handleMessage, (void *)&MemServerIndication_cbTable, item, param, poller) {
        pint.parent = static_cast<void *>(this);
    };
    virtual void addrResponse ( const uint64_t physAddr ) = 0;
    virtual void reportStateDbg ( const DmaDbgRec rec ) = 0;
    virtual void reportMemoryTraffic ( const uint64_t words ) = 0;
    virtual void error ( const uint32_t code, const uint32_t sglId, const uint64_t offset, const uint64_t extra ) = 0;
};
#endif // _MEMSERVERINDICATION_H_
