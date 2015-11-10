#include "GeneratedTypes.h"
#ifndef _BLUECACHEINDICATION_H_
#define _BLUECACHEINDICATION_H_
#include "portal.h"

class BluecacheIndicationProxy : public Portal {
public:
    BluecacheIndicationProxy(int id, PortalPoller *poller = 0) : Portal(id, BluecacheIndication_reqinfo, NULL, NULL, poller) {};
    BluecacheIndicationProxy(int id, PortalItemFunctions *item, void *param, PortalPoller *poller = 0) : Portal(id, BluecacheIndication_reqinfo, NULL, NULL, item, param, poller) {};
    int initDone ( const uint32_t dummy ) { return BluecacheIndication_initDone (&pint, dummy); };
    int rdDone ( const uint32_t bufId ) { return BluecacheIndication_rdDone (&pint, bufId); };
    int wrDone ( const uint32_t bufId ) { return BluecacheIndication_wrDone (&pint, bufId); };
    int sendData_0 ( const uint32_t v ) { return BluecacheIndication_sendData_0 (&pint, v); };
    int elementReq_0 ( const uint32_t v ) { return BluecacheIndication_elementReq_0 (&pint, v); };
    int sendData_1 ( const uint32_t v ) { return BluecacheIndication_sendData_1 (&pint, v); };
    int elementReq_1 ( const uint32_t v ) { return BluecacheIndication_elementReq_1 (&pint, v); };
    int sendData_2 ( const uint32_t v ) { return BluecacheIndication_sendData_2 (&pint, v); };
    int elementReq_2 ( const uint32_t v ) { return BluecacheIndication_elementReq_2 (&pint, v); };
};

extern BluecacheIndicationCb BluecacheIndication_cbTable;
class BluecacheIndicationWrapper : public Portal {
public:
    BluecacheIndicationWrapper(int id, PortalPoller *poller = 0) : Portal(id, BluecacheIndication_reqinfo, BluecacheIndication_handleMessage, (void *)&BluecacheIndication_cbTable, poller) {
        pint.parent = static_cast<void *>(this);
    };
    BluecacheIndicationWrapper(int id, PortalItemFunctions *item, void *param, PortalPoller *poller = 0) : Portal(id, BluecacheIndication_reqinfo, BluecacheIndication_handleMessage, (void *)&BluecacheIndication_cbTable, item, param, poller) {
        pint.parent = static_cast<void *>(this);
    };
    virtual void initDone ( const uint32_t dummy ) = 0;
    virtual void rdDone ( const uint32_t bufId ) = 0;
    virtual void wrDone ( const uint32_t bufId ) = 0;
    virtual void sendData_0 ( const uint32_t v ) = 0;
    virtual void elementReq_0 ( const uint32_t v ) = 0;
    virtual void sendData_1 ( const uint32_t v ) = 0;
    virtual void elementReq_1 ( const uint32_t v ) = 0;
    virtual void sendData_2 ( const uint32_t v ) = 0;
    virtual void elementReq_2 ( const uint32_t v ) = 0;
};
#endif // _BLUECACHEINDICATION_H_
