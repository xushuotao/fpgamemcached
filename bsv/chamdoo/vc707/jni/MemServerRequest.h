#include "GeneratedTypes.h"
#ifndef _MEMSERVERREQUEST_H_
#define _MEMSERVERREQUEST_H_
#include "portal.h"

class MemServerRequestProxy : public Portal {
public:
    MemServerRequestProxy(int id, PortalPoller *poller = 0) : Portal(id, MemServerRequest_reqinfo, NULL, NULL, poller) {};
    MemServerRequestProxy(int id, PortalItemFunctions *item, void *param, PortalPoller *poller = 0) : Portal(id, MemServerRequest_reqinfo, NULL, NULL, item, param, poller) {};
    int addrTrans ( const uint32_t sglId, const uint32_t offset ) { return MemServerRequest_addrTrans (&pint, sglId, offset); };
    int stateDbg ( const ChannelType rc ) { return MemServerRequest_stateDbg (&pint, rc); };
    int memoryTraffic ( const ChannelType rc ) { return MemServerRequest_memoryTraffic (&pint, rc); };
};

extern MemServerRequestCb MemServerRequest_cbTable;
class MemServerRequestWrapper : public Portal {
public:
    MemServerRequestWrapper(int id, PortalPoller *poller = 0) : Portal(id, MemServerRequest_reqinfo, MemServerRequest_handleMessage, (void *)&MemServerRequest_cbTable, poller) {
        pint.parent = static_cast<void *>(this);
    };
    MemServerRequestWrapper(int id, PortalItemFunctions *item, void *param, PortalPoller *poller = 0) : Portal(id, MemServerRequest_reqinfo, MemServerRequest_handleMessage, (void *)&MemServerRequest_cbTable, item, param, poller) {
        pint.parent = static_cast<void *>(this);
    };
    virtual void addrTrans ( const uint32_t sglId, const uint32_t offset ) = 0;
    virtual void stateDbg ( const ChannelType rc ) = 0;
    virtual void memoryTraffic ( const ChannelType rc ) = 0;
};
#endif // _MEMSERVERREQUEST_H_
