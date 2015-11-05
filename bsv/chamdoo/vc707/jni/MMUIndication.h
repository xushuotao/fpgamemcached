#include "GeneratedTypes.h"
#ifndef _MMUINDICATION_H_
#define _MMUINDICATION_H_
#include "portal.h"

class MMUIndicationProxy : public Portal {
public:
    MMUIndicationProxy(int id, PortalPoller *poller = 0) : Portal(id, MMUIndication_reqinfo, NULL, NULL, poller) {};
    MMUIndicationProxy(int id, PortalItemFunctions *item, void *param, PortalPoller *poller = 0) : Portal(id, MMUIndication_reqinfo, NULL, NULL, item, param, poller) {};
    int idResponse ( const uint32_t sglId ) { return MMUIndication_idResponse (&pint, sglId); };
    int configResp ( const uint32_t sglId ) { return MMUIndication_configResp (&pint, sglId); };
    int error ( const uint32_t code, const uint32_t sglId, const uint64_t offset, const uint64_t extra ) { return MMUIndication_error (&pint, code, sglId, offset, extra); };
};

extern MMUIndicationCb MMUIndication_cbTable;
class MMUIndicationWrapper : public Portal {
public:
    MMUIndicationWrapper(int id, PortalPoller *poller = 0) : Portal(id, MMUIndication_reqinfo, MMUIndication_handleMessage, (void *)&MMUIndication_cbTable, poller) {
        pint.parent = static_cast<void *>(this);
    };
    MMUIndicationWrapper(int id, PortalItemFunctions *item, void *param, PortalPoller *poller = 0) : Portal(id, MMUIndication_reqinfo, MMUIndication_handleMessage, (void *)&MMUIndication_cbTable, item, param, poller) {
        pint.parent = static_cast<void *>(this);
    };
    virtual void idResponse ( const uint32_t sglId ) = 0;
    virtual void configResp ( const uint32_t sglId ) = 0;
    virtual void error ( const uint32_t code, const uint32_t sglId, const uint64_t offset, const uint64_t extra ) = 0;
};
#endif // _MMUINDICATION_H_
