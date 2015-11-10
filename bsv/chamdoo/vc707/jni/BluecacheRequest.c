#include "GeneratedTypes.h"

int BluecacheRequest_eraseBlock ( struct PortalInternal *p, const uint32_t bus, const uint32_t chip, const uint32_t block, const uint32_t tag )
{
    volatile unsigned int* temp_working_addr_start = p->item->mapchannelReq(p, CHAN_NUM_BluecacheRequest_eraseBlock);
    volatile unsigned int* temp_working_addr = temp_working_addr_start;
    if (p->item->busywait(p, CHAN_NUM_BluecacheRequest_eraseBlock, "BluecacheRequest_eraseBlock")) return 1;
    p->item->write(p, &temp_working_addr, bus);
    p->item->write(p, &temp_working_addr, chip);
    p->item->write(p, &temp_working_addr, block);
    p->item->write(p, &temp_working_addr, tag);
    p->item->send(p, temp_working_addr_start, (CHAN_NUM_BluecacheRequest_eraseBlock << 16) | 5, -1);
    return 0;
};

int BluecacheRequest_populateMap ( struct PortalInternal *p, const uint32_t idx, const uint32_t data )
{
    volatile unsigned int* temp_working_addr_start = p->item->mapchannelReq(p, CHAN_NUM_BluecacheRequest_populateMap);
    volatile unsigned int* temp_working_addr = temp_working_addr_start;
    if (p->item->busywait(p, CHAN_NUM_BluecacheRequest_populateMap, "BluecacheRequest_populateMap")) return 1;
    p->item->write(p, &temp_working_addr, idx);
    p->item->write(p, &temp_working_addr, data);
    p->item->send(p, temp_working_addr_start, (CHAN_NUM_BluecacheRequest_populateMap << 16) | 3, -1);
    return 0;
};

int BluecacheRequest_dumpMap ( struct PortalInternal *p, const uint32_t dummy )
{
    volatile unsigned int* temp_working_addr_start = p->item->mapchannelReq(p, CHAN_NUM_BluecacheRequest_dumpMap);
    volatile unsigned int* temp_working_addr = temp_working_addr_start;
    if (p->item->busywait(p, CHAN_NUM_BluecacheRequest_dumpMap, "BluecacheRequest_dumpMap")) return 1;
    p->item->write(p, &temp_working_addr, dummy);
    p->item->send(p, temp_working_addr_start, (CHAN_NUM_BluecacheRequest_dumpMap << 16) | 2, -1);
    return 0;
};

int BluecacheRequest_initDMARefs ( struct PortalInternal *p, const uint32_t rp, const uint32_t wp )
{
    volatile unsigned int* temp_working_addr_start = p->item->mapchannelReq(p, CHAN_NUM_BluecacheRequest_initDMARefs);
    volatile unsigned int* temp_working_addr = temp_working_addr_start;
    if (p->item->busywait(p, CHAN_NUM_BluecacheRequest_initDMARefs, "BluecacheRequest_initDMARefs")) return 1;
    p->item->write(p, &temp_working_addr, rp);
    p->item->write(p, &temp_working_addr, wp);
    p->item->send(p, temp_working_addr_start, (CHAN_NUM_BluecacheRequest_initDMARefs << 16) | 3, -1);
    return 0;
};

int BluecacheRequest_startRead ( struct PortalInternal *p, const uint32_t rp, const uint32_t numBytes )
{
    volatile unsigned int* temp_working_addr_start = p->item->mapchannelReq(p, CHAN_NUM_BluecacheRequest_startRead);
    volatile unsigned int* temp_working_addr = temp_working_addr_start;
    if (p->item->busywait(p, CHAN_NUM_BluecacheRequest_startRead, "BluecacheRequest_startRead")) return 1;
    p->item->write(p, &temp_working_addr, rp);
    p->item->write(p, &temp_working_addr, numBytes);
    p->item->send(p, temp_working_addr_start, (CHAN_NUM_BluecacheRequest_startRead << 16) | 3, -1);
    return 0;
};

int BluecacheRequest_freeWriteBufId ( struct PortalInternal *p, const uint32_t wp )
{
    volatile unsigned int* temp_working_addr_start = p->item->mapchannelReq(p, CHAN_NUM_BluecacheRequest_freeWriteBufId);
    volatile unsigned int* temp_working_addr = temp_working_addr_start;
    if (p->item->busywait(p, CHAN_NUM_BluecacheRequest_freeWriteBufId, "BluecacheRequest_freeWriteBufId")) return 1;
    p->item->write(p, &temp_working_addr, wp);
    p->item->send(p, temp_working_addr_start, (CHAN_NUM_BluecacheRequest_freeWriteBufId << 16) | 2, -1);
    return 0;
};

int BluecacheRequest_initDMABufSz ( struct PortalInternal *p, const uint32_t bufSz )
{
    volatile unsigned int* temp_working_addr_start = p->item->mapchannelReq(p, CHAN_NUM_BluecacheRequest_initDMABufSz);
    volatile unsigned int* temp_working_addr = temp_working_addr_start;
    if (p->item->busywait(p, CHAN_NUM_BluecacheRequest_initDMABufSz, "BluecacheRequest_initDMABufSz")) return 1;
    p->item->write(p, &temp_working_addr, bufSz);
    p->item->send(p, temp_working_addr_start, (CHAN_NUM_BluecacheRequest_initDMABufSz << 16) | 2, -1);
    return 0;
};

int BluecacheRequest_initTable ( struct PortalInternal *p, const uint64_t lgOffset )
{
    volatile unsigned int* temp_working_addr_start = p->item->mapchannelReq(p, CHAN_NUM_BluecacheRequest_initTable);
    volatile unsigned int* temp_working_addr = temp_working_addr_start;
    if (p->item->busywait(p, CHAN_NUM_BluecacheRequest_initTable, "BluecacheRequest_initTable")) return 1;
    p->item->write(p, &temp_working_addr, (lgOffset>>32));
    p->item->write(p, &temp_working_addr, lgOffset);
    p->item->send(p, temp_working_addr_start, (CHAN_NUM_BluecacheRequest_initTable << 16) | 3, -1);
    return 0;
};

int BluecacheRequest_initValDelimit ( struct PortalInternal *p, const uint32_t randMax1, const uint32_t randMax2, const uint32_t randMax3, const uint32_t lgSz1, const uint32_t lgSz2, const uint32_t lgSz3 )
{
    volatile unsigned int* temp_working_addr_start = p->item->mapchannelReq(p, CHAN_NUM_BluecacheRequest_initValDelimit);
    volatile unsigned int* temp_working_addr = temp_working_addr_start;
    if (p->item->busywait(p, CHAN_NUM_BluecacheRequest_initValDelimit, "BluecacheRequest_initValDelimit")) return 1;
    p->item->write(p, &temp_working_addr, randMax1);
    p->item->write(p, &temp_working_addr, randMax2);
    p->item->write(p, &temp_working_addr, randMax3);
    p->item->write(p, &temp_working_addr, lgSz1);
    p->item->write(p, &temp_working_addr, lgSz2);
    p->item->write(p, &temp_working_addr, lgSz3);
    p->item->send(p, temp_working_addr_start, (CHAN_NUM_BluecacheRequest_initValDelimit << 16) | 7, -1);
    return 0;
};

int BluecacheRequest_initAddrDelimit ( struct PortalInternal *p, const uint32_t offset1, const uint32_t offset2, const uint32_t offset3 )
{
    volatile unsigned int* temp_working_addr_start = p->item->mapchannelReq(p, CHAN_NUM_BluecacheRequest_initAddrDelimit);
    volatile unsigned int* temp_working_addr = temp_working_addr_start;
    if (p->item->busywait(p, CHAN_NUM_BluecacheRequest_initAddrDelimit, "BluecacheRequest_initAddrDelimit")) return 1;
    p->item->write(p, &temp_working_addr, offset1);
    p->item->write(p, &temp_working_addr, offset2);
    p->item->write(p, &temp_working_addr, offset3);
    p->item->send(p, temp_working_addr_start, (CHAN_NUM_BluecacheRequest_initAddrDelimit << 16) | 4, -1);
    return 0;
};

int BluecacheRequest_reset ( struct PortalInternal *p, const uint32_t randNum )
{
    volatile unsigned int* temp_working_addr_start = p->item->mapchannelReq(p, CHAN_NUM_BluecacheRequest_reset);
    volatile unsigned int* temp_working_addr = temp_working_addr_start;
    if (p->item->busywait(p, CHAN_NUM_BluecacheRequest_reset, "BluecacheRequest_reset")) return 1;
    p->item->write(p, &temp_working_addr, randNum);
    p->item->send(p, temp_working_addr_start, (CHAN_NUM_BluecacheRequest_reset << 16) | 2, -1);
    return 0;
};

int BluecacheRequest_recvData_0 ( struct PortalInternal *p, const uint32_t v )
{
    volatile unsigned int* temp_working_addr_start = p->item->mapchannelReq(p, CHAN_NUM_BluecacheRequest_recvData_0);
    volatile unsigned int* temp_working_addr = temp_working_addr_start;
    if (p->item->busywait(p, CHAN_NUM_BluecacheRequest_recvData_0, "BluecacheRequest_recvData_0")) return 1;
    p->item->write(p, &temp_working_addr, v);
    p->item->send(p, temp_working_addr_start, (CHAN_NUM_BluecacheRequest_recvData_0 << 16) | 2, -1);
    return 0;
};

int BluecacheRequest_recvData_1 ( struct PortalInternal *p, const uint32_t v )
{
    volatile unsigned int* temp_working_addr_start = p->item->mapchannelReq(p, CHAN_NUM_BluecacheRequest_recvData_1);
    volatile unsigned int* temp_working_addr = temp_working_addr_start;
    if (p->item->busywait(p, CHAN_NUM_BluecacheRequest_recvData_1, "BluecacheRequest_recvData_1")) return 1;
    p->item->write(p, &temp_working_addr, v);
    p->item->send(p, temp_working_addr_start, (CHAN_NUM_BluecacheRequest_recvData_1 << 16) | 2, -1);
    return 0;
};

int BluecacheRequest_recvData_2 ( struct PortalInternal *p, const uint32_t v )
{
    volatile unsigned int* temp_working_addr_start = p->item->mapchannelReq(p, CHAN_NUM_BluecacheRequest_recvData_2);
    volatile unsigned int* temp_working_addr = temp_working_addr_start;
    if (p->item->busywait(p, CHAN_NUM_BluecacheRequest_recvData_2, "BluecacheRequest_recvData_2")) return 1;
    p->item->write(p, &temp_working_addr, v);
    p->item->send(p, temp_working_addr_start, (CHAN_NUM_BluecacheRequest_recvData_2 << 16) | 2, -1);
    return 0;
};

int BluecacheRequest_handleMessage(struct PortalInternal *p, unsigned int channel, int messageFd)
{
    static int runaway = 0;
    int tmpfd;
    unsigned int tmp;
    volatile unsigned int* temp_working_addr = p->item->mapchannelInd(p, channel);
    switch (channel) {
    case CHAN_NUM_BluecacheRequest_eraseBlock:
        {
        uint32_t bus;
        uint32_t chip;
        uint32_t block;
        uint32_t tag;
        p->item->recv(p, temp_working_addr, 4, &tmpfd);
        tmp = p->item->read(p, &temp_working_addr);
        bus = (uint32_t)(((tmp)&0xfffffffful));
        tmp = p->item->read(p, &temp_working_addr);
        chip = (uint32_t)(((tmp)&0xfffffffful));
        tmp = p->item->read(p, &temp_working_addr);
        block = (uint32_t)(((tmp)&0xfffffffful));
        tmp = p->item->read(p, &temp_working_addr);
        tag = (uint32_t)(((tmp)&0xfffffffful));
        ((BluecacheRequestCb *)p->cb)->eraseBlock(p, bus, chip, block, tag);
        }
        break;
    case CHAN_NUM_BluecacheRequest_populateMap:
        {
        uint32_t idx;
        uint32_t data;
        p->item->recv(p, temp_working_addr, 2, &tmpfd);
        tmp = p->item->read(p, &temp_working_addr);
        idx = (uint32_t)(((tmp)&0xfffffffful));
        tmp = p->item->read(p, &temp_working_addr);
        data = (uint32_t)(((tmp)&0xfffffffful));
        ((BluecacheRequestCb *)p->cb)->populateMap(p, idx, data);
        }
        break;
    case CHAN_NUM_BluecacheRequest_dumpMap:
        {
        uint32_t dummy;
        p->item->recv(p, temp_working_addr, 1, &tmpfd);
        tmp = p->item->read(p, &temp_working_addr);
        dummy = (uint32_t)(((tmp)&0xfffffffful));
        ((BluecacheRequestCb *)p->cb)->dumpMap(p, dummy);
        }
        break;
    case CHAN_NUM_BluecacheRequest_initDMARefs:
        {
        uint32_t rp;
        uint32_t wp;
        p->item->recv(p, temp_working_addr, 2, &tmpfd);
        tmp = p->item->read(p, &temp_working_addr);
        rp = (uint32_t)(((tmp)&0xfffffffful));
        tmp = p->item->read(p, &temp_working_addr);
        wp = (uint32_t)(((tmp)&0xfffffffful));
        ((BluecacheRequestCb *)p->cb)->initDMARefs(p, rp, wp);
        }
        break;
    case CHAN_NUM_BluecacheRequest_startRead:
        {
        uint32_t rp;
        uint32_t numBytes;
        p->item->recv(p, temp_working_addr, 2, &tmpfd);
        tmp = p->item->read(p, &temp_working_addr);
        rp = (uint32_t)(((tmp)&0xfffffffful));
        tmp = p->item->read(p, &temp_working_addr);
        numBytes = (uint32_t)(((tmp)&0xfffffffful));
        ((BluecacheRequestCb *)p->cb)->startRead(p, rp, numBytes);
        }
        break;
    case CHAN_NUM_BluecacheRequest_freeWriteBufId:
        {
        uint32_t wp;
        p->item->recv(p, temp_working_addr, 1, &tmpfd);
        tmp = p->item->read(p, &temp_working_addr);
        wp = (uint32_t)(((tmp)&0xfffffffful));
        ((BluecacheRequestCb *)p->cb)->freeWriteBufId(p, wp);
        }
        break;
    case CHAN_NUM_BluecacheRequest_initDMABufSz:
        {
        uint32_t bufSz;
        p->item->recv(p, temp_working_addr, 1, &tmpfd);
        tmp = p->item->read(p, &temp_working_addr);
        bufSz = (uint32_t)(((tmp)&0xfffffffful));
        ((BluecacheRequestCb *)p->cb)->initDMABufSz(p, bufSz);
        }
        break;
    case CHAN_NUM_BluecacheRequest_initTable:
        {
        uint64_t lgOffset;
        p->item->recv(p, temp_working_addr, 2, &tmpfd);
        tmp = p->item->read(p, &temp_working_addr);
        lgOffset = (uint64_t)(((uint64_t)(((tmp)&0xfffffffful))<<32));
        tmp = p->item->read(p, &temp_working_addr);
        lgOffset |= (uint64_t)(((tmp)&0xfffffffffffffffful));
        ((BluecacheRequestCb *)p->cb)->initTable(p, lgOffset);
        }
        break;
    case CHAN_NUM_BluecacheRequest_initValDelimit:
        {
        uint32_t randMax1;
        uint32_t randMax2;
        uint32_t randMax3;
        uint32_t lgSz1;
        uint32_t lgSz2;
        uint32_t lgSz3;
        p->item->recv(p, temp_working_addr, 6, &tmpfd);
        tmp = p->item->read(p, &temp_working_addr);
        randMax1 = (uint32_t)(((tmp)&0xfffffffful));
        tmp = p->item->read(p, &temp_working_addr);
        randMax2 = (uint32_t)(((tmp)&0xfffffffful));
        tmp = p->item->read(p, &temp_working_addr);
        randMax3 = (uint32_t)(((tmp)&0xfffffffful));
        tmp = p->item->read(p, &temp_working_addr);
        lgSz1 = (uint32_t)(((tmp)&0xfffffffful));
        tmp = p->item->read(p, &temp_working_addr);
        lgSz2 = (uint32_t)(((tmp)&0xfffffffful));
        tmp = p->item->read(p, &temp_working_addr);
        lgSz3 = (uint32_t)(((tmp)&0xfffffffful));
        ((BluecacheRequestCb *)p->cb)->initValDelimit(p, randMax1, randMax2, randMax3, lgSz1, lgSz2, lgSz3);
        }
        break;
    case CHAN_NUM_BluecacheRequest_initAddrDelimit:
        {
        uint32_t offset1;
        uint32_t offset2;
        uint32_t offset3;
        p->item->recv(p, temp_working_addr, 3, &tmpfd);
        tmp = p->item->read(p, &temp_working_addr);
        offset1 = (uint32_t)(((tmp)&0xfffffffful));
        tmp = p->item->read(p, &temp_working_addr);
        offset2 = (uint32_t)(((tmp)&0xfffffffful));
        tmp = p->item->read(p, &temp_working_addr);
        offset3 = (uint32_t)(((tmp)&0xfffffffful));
        ((BluecacheRequestCb *)p->cb)->initAddrDelimit(p, offset1, offset2, offset3);
        }
        break;
    case CHAN_NUM_BluecacheRequest_reset:
        {
        uint32_t randNum;
        p->item->recv(p, temp_working_addr, 1, &tmpfd);
        tmp = p->item->read(p, &temp_working_addr);
        randNum = (uint32_t)(((tmp)&0xfffffffful));
        ((BluecacheRequestCb *)p->cb)->reset(p, randNum);
        }
        break;
    case CHAN_NUM_BluecacheRequest_recvData_0:
        {
        uint32_t v;
        p->item->recv(p, temp_working_addr, 1, &tmpfd);
        tmp = p->item->read(p, &temp_working_addr);
        v = (uint32_t)(((tmp)&0xfffffffful));
        ((BluecacheRequestCb *)p->cb)->recvData_0(p, v);
        }
        break;
    case CHAN_NUM_BluecacheRequest_recvData_1:
        {
        uint32_t v;
        p->item->recv(p, temp_working_addr, 1, &tmpfd);
        tmp = p->item->read(p, &temp_working_addr);
        v = (uint32_t)(((tmp)&0xfffffffful));
        ((BluecacheRequestCb *)p->cb)->recvData_1(p, v);
        }
        break;
    case CHAN_NUM_BluecacheRequest_recvData_2:
        {
        uint32_t v;
        p->item->recv(p, temp_working_addr, 1, &tmpfd);
        tmp = p->item->read(p, &temp_working_addr);
        v = (uint32_t)(((tmp)&0xfffffffful));
        ((BluecacheRequestCb *)p->cb)->recvData_2(p, v);
        }
        break;
    default:
        PORTAL_PRINTF("BluecacheRequest_handleMessage: unknown channel 0x%x\n", channel);
        if (runaway++ > 10) {
            PORTAL_PRINTF("BluecacheRequest_handleMessage: too many bogus indications, exiting\n");
#ifndef __KERNEL__
            exit(-1);
#endif
        }
        return 0;
    }
    return 0;
}
