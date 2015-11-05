#include "GeneratedTypes.h"

int MemServerRequest_addrTrans ( struct PortalInternal *p, const uint32_t sglId, const uint32_t offset )
{
    volatile unsigned int* temp_working_addr_start = p->item->mapchannelReq(p, CHAN_NUM_MemServerRequest_addrTrans);
    volatile unsigned int* temp_working_addr = temp_working_addr_start;
    if (p->item->busywait(p, CHAN_NUM_MemServerRequest_addrTrans, "MemServerRequest_addrTrans")) return 1;
    p->item->write(p, &temp_working_addr, sglId);
    p->item->write(p, &temp_working_addr, offset);
    p->item->send(p, temp_working_addr_start, (CHAN_NUM_MemServerRequest_addrTrans << 16) | 3, -1);
    return 0;
};

int MemServerRequest_stateDbg ( struct PortalInternal *p, const ChannelType rc )
{
    volatile unsigned int* temp_working_addr_start = p->item->mapchannelReq(p, CHAN_NUM_MemServerRequest_stateDbg);
    volatile unsigned int* temp_working_addr = temp_working_addr_start;
    if (p->item->busywait(p, CHAN_NUM_MemServerRequest_stateDbg, "MemServerRequest_stateDbg")) return 1;
    p->item->write(p, &temp_working_addr, rc);
    p->item->send(p, temp_working_addr_start, (CHAN_NUM_MemServerRequest_stateDbg << 16) | 2, -1);
    return 0;
};

int MemServerRequest_memoryTraffic ( struct PortalInternal *p, const ChannelType rc )
{
    volatile unsigned int* temp_working_addr_start = p->item->mapchannelReq(p, CHAN_NUM_MemServerRequest_memoryTraffic);
    volatile unsigned int* temp_working_addr = temp_working_addr_start;
    if (p->item->busywait(p, CHAN_NUM_MemServerRequest_memoryTraffic, "MemServerRequest_memoryTraffic")) return 1;
    p->item->write(p, &temp_working_addr, rc);
    p->item->send(p, temp_working_addr_start, (CHAN_NUM_MemServerRequest_memoryTraffic << 16) | 2, -1);
    return 0;
};

int MemServerRequest_handleMessage(struct PortalInternal *p, unsigned int channel, int messageFd)
{
    static int runaway = 0;
    int tmpfd;
    unsigned int tmp;
    volatile unsigned int* temp_working_addr = p->item->mapchannelInd(p, channel);
    switch (channel) {
    case CHAN_NUM_MemServerRequest_addrTrans:
        {
        uint32_t sglId;
        uint32_t offset;
        p->item->recv(p, temp_working_addr, 2, &tmpfd);
        tmp = p->item->read(p, &temp_working_addr);
        sglId = (uint32_t)(((tmp)&0xfffffffful));
        tmp = p->item->read(p, &temp_working_addr);
        offset = (uint32_t)(((tmp)&0xfffffffful));
        ((MemServerRequestCb *)p->cb)->addrTrans(p, sglId, offset);
        }
        break;
    case CHAN_NUM_MemServerRequest_stateDbg:
        {
        ChannelType rc;
        p->item->recv(p, temp_working_addr, 1, &tmpfd);
        tmp = p->item->read(p, &temp_working_addr);
        rc = (ChannelType)(((tmp)&0x1ul));
        ((MemServerRequestCb *)p->cb)->stateDbg(p, rc);
        }
        break;
    case CHAN_NUM_MemServerRequest_memoryTraffic:
        {
        ChannelType rc;
        p->item->recv(p, temp_working_addr, 1, &tmpfd);
        tmp = p->item->read(p, &temp_working_addr);
        rc = (ChannelType)(((tmp)&0x1ul));
        ((MemServerRequestCb *)p->cb)->memoryTraffic(p, rc);
        }
        break;
    default:
        PORTAL_PRINTF("MemServerRequest_handleMessage: unknown channel 0x%x\n", channel);
        if (runaway++ > 10) {
            PORTAL_PRINTF("MemServerRequest_handleMessage: too many bogus indications, exiting\n");
#ifndef __KERNEL__
            exit(-1);
#endif
        }
        return 0;
    }
    return 0;
}
