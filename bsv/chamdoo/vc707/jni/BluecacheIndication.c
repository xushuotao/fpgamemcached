#include "GeneratedTypes.h"

int BluecacheIndication_initDone ( struct PortalInternal *p, const uint32_t dummy )
{
    volatile unsigned int* temp_working_addr_start = p->item->mapchannelReq(p, CHAN_NUM_BluecacheIndication_initDone);
    volatile unsigned int* temp_working_addr = temp_working_addr_start;
    if (p->item->busywait(p, CHAN_NUM_BluecacheIndication_initDone, "BluecacheIndication_initDone")) return 1;
    p->item->write(p, &temp_working_addr, dummy);
    p->item->send(p, temp_working_addr_start, (CHAN_NUM_BluecacheIndication_initDone << 16) | 2, -1);
    return 0;
};

int BluecacheIndication_rdDone ( struct PortalInternal *p, const uint32_t bufId )
{
    volatile unsigned int* temp_working_addr_start = p->item->mapchannelReq(p, CHAN_NUM_BluecacheIndication_rdDone);
    volatile unsigned int* temp_working_addr = temp_working_addr_start;
    if (p->item->busywait(p, CHAN_NUM_BluecacheIndication_rdDone, "BluecacheIndication_rdDone")) return 1;
    p->item->write(p, &temp_working_addr, bufId);
    p->item->send(p, temp_working_addr_start, (CHAN_NUM_BluecacheIndication_rdDone << 16) | 2, -1);
    return 0;
};

int BluecacheIndication_wrDone ( struct PortalInternal *p, const uint32_t bufId )
{
    volatile unsigned int* temp_working_addr_start = p->item->mapchannelReq(p, CHAN_NUM_BluecacheIndication_wrDone);
    volatile unsigned int* temp_working_addr = temp_working_addr_start;
    if (p->item->busywait(p, CHAN_NUM_BluecacheIndication_wrDone, "BluecacheIndication_wrDone")) return 1;
    p->item->write(p, &temp_working_addr, bufId);
    p->item->send(p, temp_working_addr_start, (CHAN_NUM_BluecacheIndication_wrDone << 16) | 2, -1);
    return 0;
};

int BluecacheIndication_sendData_0 ( struct PortalInternal *p, const uint32_t v )
{
    volatile unsigned int* temp_working_addr_start = p->item->mapchannelReq(p, CHAN_NUM_BluecacheIndication_sendData_0);
    volatile unsigned int* temp_working_addr = temp_working_addr_start;
    if (p->item->busywait(p, CHAN_NUM_BluecacheIndication_sendData_0, "BluecacheIndication_sendData_0")) return 1;
    p->item->write(p, &temp_working_addr, v);
    p->item->send(p, temp_working_addr_start, (CHAN_NUM_BluecacheIndication_sendData_0 << 16) | 2, -1);
    return 0;
};

int BluecacheIndication_elementReq_0 ( struct PortalInternal *p, const uint32_t v )
{
    volatile unsigned int* temp_working_addr_start = p->item->mapchannelReq(p, CHAN_NUM_BluecacheIndication_elementReq_0);
    volatile unsigned int* temp_working_addr = temp_working_addr_start;
    if (p->item->busywait(p, CHAN_NUM_BluecacheIndication_elementReq_0, "BluecacheIndication_elementReq_0")) return 1;
    p->item->write(p, &temp_working_addr, v);
    p->item->send(p, temp_working_addr_start, (CHAN_NUM_BluecacheIndication_elementReq_0 << 16) | 2, -1);
    return 0;
};

int BluecacheIndication_sendData_1 ( struct PortalInternal *p, const uint32_t v )
{
    volatile unsigned int* temp_working_addr_start = p->item->mapchannelReq(p, CHAN_NUM_BluecacheIndication_sendData_1);
    volatile unsigned int* temp_working_addr = temp_working_addr_start;
    if (p->item->busywait(p, CHAN_NUM_BluecacheIndication_sendData_1, "BluecacheIndication_sendData_1")) return 1;
    p->item->write(p, &temp_working_addr, v);
    p->item->send(p, temp_working_addr_start, (CHAN_NUM_BluecacheIndication_sendData_1 << 16) | 2, -1);
    return 0;
};

int BluecacheIndication_elementReq_1 ( struct PortalInternal *p, const uint32_t v )
{
    volatile unsigned int* temp_working_addr_start = p->item->mapchannelReq(p, CHAN_NUM_BluecacheIndication_elementReq_1);
    volatile unsigned int* temp_working_addr = temp_working_addr_start;
    if (p->item->busywait(p, CHAN_NUM_BluecacheIndication_elementReq_1, "BluecacheIndication_elementReq_1")) return 1;
    p->item->write(p, &temp_working_addr, v);
    p->item->send(p, temp_working_addr_start, (CHAN_NUM_BluecacheIndication_elementReq_1 << 16) | 2, -1);
    return 0;
};

int BluecacheIndication_sendData_2 ( struct PortalInternal *p, const uint32_t v )
{
    volatile unsigned int* temp_working_addr_start = p->item->mapchannelReq(p, CHAN_NUM_BluecacheIndication_sendData_2);
    volatile unsigned int* temp_working_addr = temp_working_addr_start;
    if (p->item->busywait(p, CHAN_NUM_BluecacheIndication_sendData_2, "BluecacheIndication_sendData_2")) return 1;
    p->item->write(p, &temp_working_addr, v);
    p->item->send(p, temp_working_addr_start, (CHAN_NUM_BluecacheIndication_sendData_2 << 16) | 2, -1);
    return 0;
};

int BluecacheIndication_elementReq_2 ( struct PortalInternal *p, const uint32_t v )
{
    volatile unsigned int* temp_working_addr_start = p->item->mapchannelReq(p, CHAN_NUM_BluecacheIndication_elementReq_2);
    volatile unsigned int* temp_working_addr = temp_working_addr_start;
    if (p->item->busywait(p, CHAN_NUM_BluecacheIndication_elementReq_2, "BluecacheIndication_elementReq_2")) return 1;
    p->item->write(p, &temp_working_addr, v);
    p->item->send(p, temp_working_addr_start, (CHAN_NUM_BluecacheIndication_elementReq_2 << 16) | 2, -1);
    return 0;
};

int BluecacheIndication_handleMessage(struct PortalInternal *p, unsigned int channel, int messageFd)
{
    static int runaway = 0;
    int tmpfd;
    unsigned int tmp;
    volatile unsigned int* temp_working_addr = p->item->mapchannelInd(p, channel);
    switch (channel) {
    case CHAN_NUM_BluecacheIndication_initDone:
        {
        uint32_t dummy;
        p->item->recv(p, temp_working_addr, 1, &tmpfd);
        tmp = p->item->read(p, &temp_working_addr);
        dummy = (uint32_t)(((tmp)&0xfffffffful));
        ((BluecacheIndicationCb *)p->cb)->initDone(p, dummy);
        }
        break;
    case CHAN_NUM_BluecacheIndication_rdDone:
        {
        uint32_t bufId;
        p->item->recv(p, temp_working_addr, 1, &tmpfd);
        tmp = p->item->read(p, &temp_working_addr);
        bufId = (uint32_t)(((tmp)&0xfffffffful));
        ((BluecacheIndicationCb *)p->cb)->rdDone(p, bufId);
        }
        break;
    case CHAN_NUM_BluecacheIndication_wrDone:
        {
        uint32_t bufId;
        p->item->recv(p, temp_working_addr, 1, &tmpfd);
        tmp = p->item->read(p, &temp_working_addr);
        bufId = (uint32_t)(((tmp)&0xfffffffful));
        ((BluecacheIndicationCb *)p->cb)->wrDone(p, bufId);
        }
        break;
    case CHAN_NUM_BluecacheIndication_sendData_0:
        {
        uint32_t v;
        p->item->recv(p, temp_working_addr, 1, &tmpfd);
        tmp = p->item->read(p, &temp_working_addr);
        v = (uint32_t)(((tmp)&0xfffffffful));
        ((BluecacheIndicationCb *)p->cb)->sendData_0(p, v);
        }
        break;
    case CHAN_NUM_BluecacheIndication_elementReq_0:
        {
        uint32_t v;
        p->item->recv(p, temp_working_addr, 1, &tmpfd);
        tmp = p->item->read(p, &temp_working_addr);
        v = (uint32_t)(((tmp)&0xfffffffful));
        ((BluecacheIndicationCb *)p->cb)->elementReq_0(p, v);
        }
        break;
    case CHAN_NUM_BluecacheIndication_sendData_1:
        {
        uint32_t v;
        p->item->recv(p, temp_working_addr, 1, &tmpfd);
        tmp = p->item->read(p, &temp_working_addr);
        v = (uint32_t)(((tmp)&0xfffffffful));
        ((BluecacheIndicationCb *)p->cb)->sendData_1(p, v);
        }
        break;
    case CHAN_NUM_BluecacheIndication_elementReq_1:
        {
        uint32_t v;
        p->item->recv(p, temp_working_addr, 1, &tmpfd);
        tmp = p->item->read(p, &temp_working_addr);
        v = (uint32_t)(((tmp)&0xfffffffful));
        ((BluecacheIndicationCb *)p->cb)->elementReq_1(p, v);
        }
        break;
    case CHAN_NUM_BluecacheIndication_sendData_2:
        {
        uint32_t v;
        p->item->recv(p, temp_working_addr, 1, &tmpfd);
        tmp = p->item->read(p, &temp_working_addr);
        v = (uint32_t)(((tmp)&0xfffffffful));
        ((BluecacheIndicationCb *)p->cb)->sendData_2(p, v);
        }
        break;
    case CHAN_NUM_BluecacheIndication_elementReq_2:
        {
        uint32_t v;
        p->item->recv(p, temp_working_addr, 1, &tmpfd);
        tmp = p->item->read(p, &temp_working_addr);
        v = (uint32_t)(((tmp)&0xfffffffful));
        ((BluecacheIndicationCb *)p->cb)->elementReq_2(p, v);
        }
        break;
    default:
        PORTAL_PRINTF("BluecacheIndication_handleMessage: unknown channel 0x%x\n", channel);
        if (runaway++ > 10) {
            PORTAL_PRINTF("BluecacheIndication_handleMessage: too many bogus indications, exiting\n");
#ifndef __KERNEL__
            exit(-1);
#endif
        }
        return 0;
    }
    return 0;
}
