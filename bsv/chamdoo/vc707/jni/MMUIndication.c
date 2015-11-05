#include "GeneratedTypes.h"

int MMUIndication_idResponse ( struct PortalInternal *p, const uint32_t sglId )
{
    volatile unsigned int* temp_working_addr_start = p->item->mapchannelReq(p, CHAN_NUM_MMUIndication_idResponse);
    volatile unsigned int* temp_working_addr = temp_working_addr_start;
    if (p->item->busywait(p, CHAN_NUM_MMUIndication_idResponse, "MMUIndication_idResponse")) return 1;
    p->item->write(p, &temp_working_addr, sglId);
    p->item->send(p, temp_working_addr_start, (CHAN_NUM_MMUIndication_idResponse << 16) | 2, -1);
    return 0;
};

int MMUIndication_configResp ( struct PortalInternal *p, const uint32_t sglId )
{
    volatile unsigned int* temp_working_addr_start = p->item->mapchannelReq(p, CHAN_NUM_MMUIndication_configResp);
    volatile unsigned int* temp_working_addr = temp_working_addr_start;
    if (p->item->busywait(p, CHAN_NUM_MMUIndication_configResp, "MMUIndication_configResp")) return 1;
    p->item->write(p, &temp_working_addr, sglId);
    p->item->send(p, temp_working_addr_start, (CHAN_NUM_MMUIndication_configResp << 16) | 2, -1);
    return 0;
};

int MMUIndication_error ( struct PortalInternal *p, const uint32_t code, const uint32_t sglId, const uint64_t offset, const uint64_t extra )
{
    volatile unsigned int* temp_working_addr_start = p->item->mapchannelReq(p, CHAN_NUM_MMUIndication_error);
    volatile unsigned int* temp_working_addr = temp_working_addr_start;
    if (p->item->busywait(p, CHAN_NUM_MMUIndication_error, "MMUIndication_error")) return 1;
    p->item->write(p, &temp_working_addr, code);
    p->item->write(p, &temp_working_addr, sglId);
    p->item->write(p, &temp_working_addr, (offset>>32));
    p->item->write(p, &temp_working_addr, offset);
    p->item->write(p, &temp_working_addr, (extra>>32));
    p->item->write(p, &temp_working_addr, extra);
    p->item->send(p, temp_working_addr_start, (CHAN_NUM_MMUIndication_error << 16) | 7, -1);
    return 0;
};

int MMUIndication_handleMessage(struct PortalInternal *p, unsigned int channel, int messageFd)
{
    static int runaway = 0;
    int tmpfd;
    unsigned int tmp;
    volatile unsigned int* temp_working_addr = p->item->mapchannelInd(p, channel);
    switch (channel) {
    case CHAN_NUM_MMUIndication_idResponse:
        {
        uint32_t sglId;
        p->item->recv(p, temp_working_addr, 1, &tmpfd);
        tmp = p->item->read(p, &temp_working_addr);
        sglId = (uint32_t)(((tmp)&0xfffffffful));
        ((MMUIndicationCb *)p->cb)->idResponse(p, sglId);
        }
        break;
    case CHAN_NUM_MMUIndication_configResp:
        {
        uint32_t sglId;
        p->item->recv(p, temp_working_addr, 1, &tmpfd);
        tmp = p->item->read(p, &temp_working_addr);
        sglId = (uint32_t)(((tmp)&0xfffffffful));
        ((MMUIndicationCb *)p->cb)->configResp(p, sglId);
        }
        break;
    case CHAN_NUM_MMUIndication_error:
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
        ((MMUIndicationCb *)p->cb)->error(p, code, sglId, offset, extra);
        }
        break;
    default:
        PORTAL_PRINTF("MMUIndication_handleMessage: unknown channel 0x%x\n", channel);
        if (runaway++ > 10) {
            PORTAL_PRINTF("MMUIndication_handleMessage: too many bogus indications, exiting\n");
#ifndef __KERNEL__
            exit(-1);
#endif
        }
        return 0;
    }
    return 0;
}
