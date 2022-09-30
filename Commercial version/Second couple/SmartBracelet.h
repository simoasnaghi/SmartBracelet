
#ifndef SMARTBRACELET_H
#define SMARTBRACELET_H

// Message structure definition
typedef nx_struct my_msg
{
    //Field 1
    nx_uint8_t msg_type;
    //Field 2
    nx_uint8_t key[20];
    //Field 3
    nx_uint16_t x_pos;
    //Field 4
    nx_uint16_t y_pos;
} my_msg_t;

enum{
    AM_RADIO_TYPE = 6,
};


#endif
