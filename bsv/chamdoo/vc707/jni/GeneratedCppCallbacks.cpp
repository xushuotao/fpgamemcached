#include "GeneratedTypes.h"

#ifndef NO_CPP_PORTAL_CODE

/************** Start of BluecacheRequestWrapper CPP ***********/
#include "BluecacheRequest.h"
void BluecacheRequesteraseBlock_cb (  struct PortalInternal *p, const uint32_t bus, const uint32_t chip, const uint32_t block, const uint32_t tag ) {
    (static_cast<BluecacheRequestWrapper *>(p->parent))->eraseBlock ( bus, chip, block, tag);
};
void BluecacheRequestpopulateMap_cb (  struct PortalInternal *p, const uint32_t idx, const uint32_t data ) {
    (static_cast<BluecacheRequestWrapper *>(p->parent))->populateMap ( idx, data);
};
void BluecacheRequestdumpMap_cb (  struct PortalInternal *p, const uint32_t dummy ) {
    (static_cast<BluecacheRequestWrapper *>(p->parent))->dumpMap ( dummy);
};
void BluecacheRequestinitDMARefs_cb (  struct PortalInternal *p, const uint32_t rp, const uint32_t wp ) {
    (static_cast<BluecacheRequestWrapper *>(p->parent))->initDMARefs ( rp, wp);
};
void BluecacheRequeststartRead_cb (  struct PortalInternal *p, const uint32_t rp, const uint32_t numBytes ) {
    (static_cast<BluecacheRequestWrapper *>(p->parent))->startRead ( rp, numBytes);
};
void BluecacheRequestfreeWriteBufId_cb (  struct PortalInternal *p, const uint32_t wp ) {
    (static_cast<BluecacheRequestWrapper *>(p->parent))->freeWriteBufId ( wp);
};
void BluecacheRequestinitDMABufSz_cb (  struct PortalInternal *p, const uint32_t bufSz ) {
    (static_cast<BluecacheRequestWrapper *>(p->parent))->initDMABufSz ( bufSz);
};
void BluecacheRequestinitTable_cb (  struct PortalInternal *p, const uint64_t lgOffset ) {
    (static_cast<BluecacheRequestWrapper *>(p->parent))->initTable ( lgOffset);
};
void BluecacheRequestinitValDelimit_cb (  struct PortalInternal *p, const uint32_t randMax1, const uint32_t randMax2, const uint32_t randMax3, const uint32_t lgSz1, const uint32_t lgSz2, const uint32_t lgSz3 ) {
    (static_cast<BluecacheRequestWrapper *>(p->parent))->initValDelimit ( randMax1, randMax2, randMax3, lgSz1, lgSz2, lgSz3);
};
void BluecacheRequestinitAddrDelimit_cb (  struct PortalInternal *p, const uint32_t offset1, const uint32_t offset2, const uint32_t offset3 ) {
    (static_cast<BluecacheRequestWrapper *>(p->parent))->initAddrDelimit ( offset1, offset2, offset3);
};
void BluecacheRequestreset_cb (  struct PortalInternal *p, const uint32_t randNum ) {
    (static_cast<BluecacheRequestWrapper *>(p->parent))->reset ( randNum);
};
void BluecacheRequestrecvData_0_cb (  struct PortalInternal *p, const uint32_t v ) {
    (static_cast<BluecacheRequestWrapper *>(p->parent))->recvData_0 ( v);
};
void BluecacheRequestrecvData_1_cb (  struct PortalInternal *p, const uint32_t v ) {
    (static_cast<BluecacheRequestWrapper *>(p->parent))->recvData_1 ( v);
};
void BluecacheRequestrecvData_2_cb (  struct PortalInternal *p, const uint32_t v ) {
    (static_cast<BluecacheRequestWrapper *>(p->parent))->recvData_2 ( v);
};
BluecacheRequestCb BluecacheRequest_cbTable = {
    BluecacheRequesteraseBlock_cb,
    BluecacheRequestpopulateMap_cb,
    BluecacheRequestdumpMap_cb,
    BluecacheRequestinitDMARefs_cb,
    BluecacheRequeststartRead_cb,
    BluecacheRequestfreeWriteBufId_cb,
    BluecacheRequestinitDMABufSz_cb,
    BluecacheRequestinitTable_cb,
    BluecacheRequestinitValDelimit_cb,
    BluecacheRequestinitAddrDelimit_cb,
    BluecacheRequestreset_cb,
    BluecacheRequestrecvData_0_cb,
    BluecacheRequestrecvData_1_cb,
    BluecacheRequestrecvData_2_cb,
};

/************** Start of BluecacheIndicationWrapper CPP ***********/
#include "BluecacheIndication.h"
void BluecacheIndicationinitDone_cb (  struct PortalInternal *p, const uint32_t dummy ) {
    (static_cast<BluecacheIndicationWrapper *>(p->parent))->initDone ( dummy);
};
void BluecacheIndicationrdDone_cb (  struct PortalInternal *p, const uint32_t bufId ) {
    (static_cast<BluecacheIndicationWrapper *>(p->parent))->rdDone ( bufId);
};
void BluecacheIndicationwrDone_cb (  struct PortalInternal *p, const uint32_t bufId ) {
    (static_cast<BluecacheIndicationWrapper *>(p->parent))->wrDone ( bufId);
};
void BluecacheIndicationsendData_0_cb (  struct PortalInternal *p, const uint32_t v ) {
    (static_cast<BluecacheIndicationWrapper *>(p->parent))->sendData_0 ( v);
};
void BluecacheIndicationelementReq_0_cb (  struct PortalInternal *p, const uint32_t v ) {
    (static_cast<BluecacheIndicationWrapper *>(p->parent))->elementReq_0 ( v);
};
void BluecacheIndicationsendData_1_cb (  struct PortalInternal *p, const uint32_t v ) {
    (static_cast<BluecacheIndicationWrapper *>(p->parent))->sendData_1 ( v);
};
void BluecacheIndicationelementReq_1_cb (  struct PortalInternal *p, const uint32_t v ) {
    (static_cast<BluecacheIndicationWrapper *>(p->parent))->elementReq_1 ( v);
};
void BluecacheIndicationsendData_2_cb (  struct PortalInternal *p, const uint32_t v ) {
    (static_cast<BluecacheIndicationWrapper *>(p->parent))->sendData_2 ( v);
};
void BluecacheIndicationelementReq_2_cb (  struct PortalInternal *p, const uint32_t v ) {
    (static_cast<BluecacheIndicationWrapper *>(p->parent))->elementReq_2 ( v);
};
BluecacheIndicationCb BluecacheIndication_cbTable = {
    BluecacheIndicationinitDone_cb,
    BluecacheIndicationrdDone_cb,
    BluecacheIndicationwrDone_cb,
    BluecacheIndicationsendData_0_cb,
    BluecacheIndicationelementReq_0_cb,
    BluecacheIndicationsendData_1_cb,
    BluecacheIndicationelementReq_1_cb,
    BluecacheIndicationsendData_2_cb,
    BluecacheIndicationelementReq_2_cb,
};

/************** Start of MemServerRequestWrapper CPP ***********/
#include "MemServerRequest.h"
void MemServerRequestaddrTrans_cb (  struct PortalInternal *p, const uint32_t sglId, const uint32_t offset ) {
    (static_cast<MemServerRequestWrapper *>(p->parent))->addrTrans ( sglId, offset);
};
void MemServerRequeststateDbg_cb (  struct PortalInternal *p, const ChannelType rc ) {
    (static_cast<MemServerRequestWrapper *>(p->parent))->stateDbg ( rc);
};
void MemServerRequestmemoryTraffic_cb (  struct PortalInternal *p, const ChannelType rc ) {
    (static_cast<MemServerRequestWrapper *>(p->parent))->memoryTraffic ( rc);
};
MemServerRequestCb MemServerRequest_cbTable = {
    MemServerRequestaddrTrans_cb,
    MemServerRequeststateDbg_cb,
    MemServerRequestmemoryTraffic_cb,
};

/************** Start of MMURequestWrapper CPP ***********/
#include "MMURequest.h"
void MMURequestsglist_cb (  struct PortalInternal *p, const uint32_t sglId, const uint32_t sglIndex, const uint64_t addr, const uint32_t len ) {
    (static_cast<MMURequestWrapper *>(p->parent))->sglist ( sglId, sglIndex, addr, len);
};
void MMURequestregion_cb (  struct PortalInternal *p, const uint32_t sglId, const uint64_t barr8, const uint32_t index8, const uint64_t barr4, const uint32_t index4, const uint64_t barr0, const uint32_t index0 ) {
    (static_cast<MMURequestWrapper *>(p->parent))->region ( sglId, barr8, index8, barr4, index4, barr0, index0);
};
void MMURequestidRequest_cb (  struct PortalInternal *p, const SpecialTypeForSendingFd fd ) {
    (static_cast<MMURequestWrapper *>(p->parent))->idRequest ( fd);
};
void MMURequestidReturn_cb (  struct PortalInternal *p, const uint32_t sglId ) {
    (static_cast<MMURequestWrapper *>(p->parent))->idReturn ( sglId);
};
void MMURequestsetInterface_cb (  struct PortalInternal *p, const uint32_t interfaceId, const uint32_t sglId ) {
    (static_cast<MMURequestWrapper *>(p->parent))->setInterface ( interfaceId, sglId);
};
MMURequestCb MMURequest_cbTable = {
    MMURequestsglist_cb,
    MMURequestregion_cb,
    MMURequestidRequest_cb,
    MMURequestidReturn_cb,
    MMURequestsetInterface_cb,
};

/************** Start of MemServerIndicationWrapper CPP ***********/
#include "MemServerIndication.h"
void MemServerIndicationaddrResponse_cb (  struct PortalInternal *p, const uint64_t physAddr ) {
    (static_cast<MemServerIndicationWrapper *>(p->parent))->addrResponse ( physAddr);
};
void MemServerIndicationreportStateDbg_cb (  struct PortalInternal *p, const DmaDbgRec rec ) {
    (static_cast<MemServerIndicationWrapper *>(p->parent))->reportStateDbg ( rec);
};
void MemServerIndicationreportMemoryTraffic_cb (  struct PortalInternal *p, const uint64_t words ) {
    (static_cast<MemServerIndicationWrapper *>(p->parent))->reportMemoryTraffic ( words);
};
void MemServerIndicationerror_cb (  struct PortalInternal *p, const uint32_t code, const uint32_t sglId, const uint64_t offset, const uint64_t extra ) {
    (static_cast<MemServerIndicationWrapper *>(p->parent))->error ( code, sglId, offset, extra);
};
MemServerIndicationCb MemServerIndication_cbTable = {
    MemServerIndicationaddrResponse_cb,
    MemServerIndicationreportStateDbg_cb,
    MemServerIndicationreportMemoryTraffic_cb,
    MemServerIndicationerror_cb,
};

/************** Start of MMUIndicationWrapper CPP ***********/
#include "MMUIndication.h"
void MMUIndicationidResponse_cb (  struct PortalInternal *p, const uint32_t sglId ) {
    (static_cast<MMUIndicationWrapper *>(p->parent))->idResponse ( sglId);
};
void MMUIndicationconfigResp_cb (  struct PortalInternal *p, const uint32_t sglId ) {
    (static_cast<MMUIndicationWrapper *>(p->parent))->configResp ( sglId);
};
void MMUIndicationerror_cb (  struct PortalInternal *p, const uint32_t code, const uint32_t sglId, const uint64_t offset, const uint64_t extra ) {
    (static_cast<MMUIndicationWrapper *>(p->parent))->error ( code, sglId, offset, extra);
};
MMUIndicationCb MMUIndication_cbTable = {
    MMUIndicationidResponse_cb,
    MMUIndicationconfigResp_cb,
    MMUIndicationerror_cb,
};
#endif //NO_CPP_PORTAL_CODE
