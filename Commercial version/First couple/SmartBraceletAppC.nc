#include "SmartBracelet.h"
#include "printf.h"

configuration SmartBraceletAppC {}

implementation {
    components MainC, SmartBraceletC as App;
    components RandomC;

    components new AMSenderC(AM_RADIO_TYPE);
    components new AMReceiverC(AM_RADIO_TYPE);
    components ActiveMessageC;
    
    components SerialPrintfC;
    components SerialStartC;

    components new TimerMilliC() as Timer ;
    components new TimerMilliC() as Pairtimer;
    components new TimerMilliC() as Waittimer;

    //Boot interface
    App.Boot -> MainC.Boot;

    //Radio interface
    App.AMSend -> AMSenderC;
    App.Receive -> AMReceiverC;
    App.AMControl -> ActiveMessageC;

    App.Packet -> AMSenderC;
    App.AMPacket -> AMSenderC;
    App.PacketAck -> ActiveMessageC;

    App.MilliTimer -> Timer;
    App.PairingTimer -> Pairtimer;
    App.WaitTimer -> Waittimer;
    //timer initialization
    App.Random -> RandomC;
}
