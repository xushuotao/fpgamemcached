#include "GeneratedTypes.h"

int MemServerIndication_addrResponse ( struct PortalInternal *p, const uint64_t physAddr )
{
    volatile unsigned int* temp_working_addr_start = p->item->mapchannelReq(p, CHAN_NUM_MemServerIndication_addrResponse);
    volatile unsigned int* temp_working_addr = temp_working_addr_start;
    if (p->item->busywait(p, CHAN_NUM_MemServerIndication_addrResponse, "MemServerIndication_addrResponse")) return 1;
    p->item->write(p, &temp_working_addr, (physAddr>>32));
    p->item->write(p, &temp_working_addr, physAddr);
    p->item->send(p, temp_working_addr_start, (CHAN_NUM_MemServerIndication_addrResponse << 16) | 3, -1);
    return 0;
};

int MemServerIndication_reportStateDbg ( struct PortalInternal *p, const DmaDbgRec rec )
{
    volatile unsigned int* temp_working_addr_start = p->item->mapchannelReq(p, CHAN_NUM_MemServerIndication_reportStateDbg);
    volatile unsigned int* temp_working_addr = temp_working_addr_start;
    if (p->item->busywait(p, CHAN_NUM_MemServerIndication_reportStateDbg, "MemServerIndication_reportStateDbg")) return 1;
    p->item->write(p, &temp_working_addr, rec.x);
    p->item->write(p, &temp_working_addr, rec.y);
    p->item->write(p, &temp_working_addr, rec.z);
    p->item->write(p, &temp_working_addr, rec.w);
    p->item->send(p, temp_working_addr_start, (CHAN_NUM_MemServerIndication_reportStateDbg << 16) | 5, -1);
    return 0;
};

int MemServerIndication_reportMemoryTraffic ( struct PortalInternal *p, const uint64_t words )
{
    volatile unsigned int* temp_working_addr_start = p->item->mapchannelReq(p, CHAN_NUM_MemServerIndication_reportMemoryTraffic);
    volatile unsigned int* temp_working_addr = temp_working_addr_start;
    if (p->item->busywait(p, CHAN_NUM_MemServerIndication_reportMemoryTraffic, "MemServerIndication_reportMemoryTraffic")) return 1;
    p->item->write(p, &temp_working_addr, (words>>32));
    p->item->write(p, &temp_working_addr, words);
    p->item->send(p, temp_working_addr_start, (CHAN_NUM_MemServerIndication_reportMemoryTraffic << 16) | 3, -1);
    return 0;
};

int MemServerIndication_error ( struct PortalInternal *p, const uint32_t code, const uint32_t sglId, const uint64_t offset, const uint64_t extra )
{
    volatile unsigned int* temp_working_addr_start = p->item->mapchannelReq(p, CHAN_NUM_MemServerIndication_error);
    volatile unsigned int* temp_working_addr = temp_working_addr_start;
    if (p->item->busywait(p, CHAN_NUM_MemServerIndication_error, "MemServerIndication_error")) return 1;
    p->item->write(p, &temp_working_addr, code);
    p->item->write(p, &temp_working_addr, sglId);
    p->item->write(p, &temp_working_addr, (offset>>32));
    p->item->write(p, &temp_working_addr, offset);
    p->item->write(p, &temp_working_addr, (extra>>32));
    p->item->write(p, &temp_working_addr, extra);
    p->item->send(p, temp_working_addr_start, (CHAN_NUM_MemServerIndication_error << 16) | 7, -1);
    return 0;
};

int MemServerIndication_handleMessage(struct PortalInternal *p, unsigned int channel, int messageFd)
{
    static int runaway = 0;
    int tmpfd;
    unsigned int tmp;
    volatile unsigned int* temp_working_addr = p->item->mapchannelInd(p, channel);
    switch (channel) {
    case CHAN_NUM_MemServerIndication_addrResponse:
        {
        uint64_t physAddr;
        p->item->recv(p, temp_working_addr, 2, &tmpfd);
        tmp = p->item->read(p, &temp_working_addr);
        physAddr = (uint64_t)(((uint64_t)(((tmp)&0xfffffffful))<<32));
        tmp = p->item->read(p, &temp_working_addr);
        physAddr |= (uint64_t)(((tmp)&0xfffffffffffffffful));
        ((MemServerIndicationCb *)p->cb)->addrResponse(p, physAddr);
        }
        break;
    case CHAN_NUM_MemServerIndication_reportStateDbg:
        {
        DmaDbgRec rec;
        p->item->recv(p, temp_working_addr, 4, &tmpfd);
        tmp = p->item->read(p, &temp_working_addr);
        rec.x = (uint32_t)(((tmp)&0xfffffffful));
        tmp = p->item->read(p, &temp_working_addr);
        rec.y = (uint32_t)(((tmp)&0xfffffffful));
        tmp = p->item->read(p, &temp_working_addr);
        rec.z = (uint32_t)(((tmp)&0xfffffffful));
        tmp = p->item->read(p, &temp_working_addr);
        rec.w = (uint32_t)(((tmp)&0xfffffffful));
        ((MemServerIndicationCb *)p->cb)->reportStateDbg(p, rec);
        }
        break;
    case CHAN_NUM_MemServerIndication_reportMemoryTraffic:
        {
        uint64_t words;
        p->item->recv(p, temp_working_addr, 2, &tmpfd);
        tmp = p->item->read(p, &temp_working_addr);
        words = (uint64_t)(((uint64_t)(((tmp)&0xfffffffful))<<32));
        tmp = p->item->read(p, &temp_working_addr);
        words |= (uint64_t)(((tmp)&0xfffffffffffffffful));
        ((MemServerIndicationCb *)p->cb)->reportMemoryTraffic(p, words);
        }
        break;
    case CHAN_NUM_MemServerIndication_error:
        {
        uint32_t code;
        uint32_t sglId;
        uint64_t offset;
        uint64_t extra;
        p->item->recv(p, temp_working_addr, 6, &tmpfd);
        tmp = p->item->read(p, &temp_working_addr);
        code = (uint32_t)(((tmp)&0xfffffffful));
        tmp = p->item->read(p, &temp_working_addr);
        sglId = (uint32_t)(((tmp)&0xfffffffful));
        tmp = p->item->read(p, &temp_working_addr);
        offset = (uint64_t)(((uint64_t)(((tmp)&0xfffffffful))<<32));
        tmp = p->item->read(p, &temp_working_addr);
        offset |= (uint64_t)(((tmp)&0xfffffffffffffffful));
        tmp = p->item->read(p, &temp_working_addr);
        extra = (uint64_t)(((uint64_t)(((tmp)&0xfffffffful))<<32));
        tmp = p->item->read(p, &temp_working_addr);
        extra |= (uint64_t)(((tmp)&0xfffffffffffffffful));
        ((MemServerIndicationCb *)p->cb)->error(p, code, sglId, offset, extra);
        }
        break;
    default:
        PORTAL_PRINTF("MemServerIndication_handleMessage: unknown channel 0x%x\n", channel);
        if (runaway++ > 10) {
            PORTAL_PRINTF("MemServerIndication_handleMessage: too many bogus indications, exiting\n");
#ifndef __KERNEL__
            exit(-1);
#endif
        }
        return 0;
    }
    return 0;
}
