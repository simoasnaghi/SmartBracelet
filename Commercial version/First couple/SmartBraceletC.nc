#include "Timer.h"
#include "SmartBracelet.h"
#include <stdio.h>

module SmartBraceletC {
    uses{
        //Main interface
        interface Boot;
        //Radio interfaces
        interface Receive;
        interface AMSend;
        interface SplitControl as AMControl;
        interface Packet;
        interface AMPacket;
        interface PacketAcknowledgements as PacketAck;
        //Timer Interface
        interface Timer<TMilli> as MilliTimer;
        interface Timer<TMilli> as PairingTimer;
        interface Timer<TMilli> as WaitTimer;
        //Random number generator Interface
        interface Random;
    }
}

implementation{

    
    message_t packet;
    am_addr_t motepaired;
    uint16_t x_position;
    uint16_t y_position;
    uint8_t type;
    int cs=0;
    int p;
    int i;
    const int px=30;
    const int py=30;
    const int pz=30;
    const int ph=10;
    bool locked = FALSE;
    char key_string[20]="abc1efg2ijk3mnopqrs4";
    void stopPairingPhase();

    //Boot event
    event void Boot.booted()
    {
        if(TOS_NODE_ID%2==1)
        {
            //printf("Parent: radio booted.\n");
            call AMControl.start();
        }
        else if (TOS_NODE_ID%2==0)
        {
            //printf("Child: radio booted.\n");
            call AMControl.start();
        }
        
    }

    //Radio start
    event void AMControl.startDone(error_t err)
    {
        if(TOS_NODE_ID%2==1)
        {
           if (err == SUCCESS)
            {
                //printf("Parent: radio is ready.\n");
                call PairingTimer.startPeriodic(300); //timer is used to avoid problems if parent mote boot before child's one. 
            }
            else
            {
                //printf("Parent: radio not started. Retry in progress.\n");
                call AMControl.start();
            } 
        }
        else if (TOS_NODE_ID%2==0)
        {
            if (err == SUCCESS)
            {
                //printf("Child: radio is ready.\n");
                call PairingTimer.startPeriodic(300); //timer is used to avoid problems if child mote boot before parent's one. 
            }
            else
            {
                //printf("Child: radio not started. Retry in progress.\n");
                call AMControl.start();
            }
        } 
        
    }

    //Radio stop
    event void AMControl.stopDone(error_t err)
    {
        if(TOS_NODE_ID%2==1)
        {
            //printf("Parent: radio stopped.\n");
        }
        else if (TOS_NODE_ID%2==0)
        {
            //printf("Child: radio stopped.\n");
        }
    }

    // Pairing timer fired
    event void PairingTimer.fired()
    {
        my_msg_t* pairing_message = (my_msg_t*) (call Packet.getPayload(&packet, sizeof (my_msg_t)));
        if(TOS_NODE_ID%2==1)
        {
            //printf("Parent: Pairing timer fired.\n");
            if (locked == FALSE)
            {
                pairing_message -> msg_type = 0; // 0 is the code for the pair request message
                type=0;
                strcpy((char*)pairing_message->key,key_string);
                if (call AMSend.send(AM_BROADCAST_ADDR, & packet, sizeof (my_msg_t)) == SUCCESS)
                {
                    locked = TRUE;
                    //printf("Parent: pairing message sent.\n");
                }
            }
        }
        else if (TOS_NODE_ID%2==0)
        {
            //printf("Child: Pairing timer fired.\n");
            if (locked == FALSE)
            {
                strcpy((char*)pairing_message->key,key_string);
                pairing_message -> msg_type = 0; // 0 is the code for the pair request message
                type=0;
                if (call AMSend.send(AM_BROADCAST_ADDR, & packet, sizeof (my_msg_t)) == SUCCESS)
                {
                    locked = TRUE;
                    //printf("Child: pairing message sent.\n");
                }
            }
        }
        
    }

    //Message incoming
    event message_t* Receive.receive(message_t* buf,void* payload,uint8_t len)
    {
        my_msg_t* received_msg = (my_msg_t*)payload;
        if(TOS_NODE_ID%2==1)
        {
            if (len != sizeof(my_msg_t))
            {
                //printf("Parent: wrong message length.Message discarded.\n");
                return buf;
            }
            else
            {
                //check if broadcast message
                if (call AMPacket.destination(buf) == AM_BROADCAST_ADDR && received_msg->msg_type == 0 && strcmp((char*)received_msg->key,key_string)==0)
                {
                    motepaired = call AMPacket.source(buf);
                    stopPairingPhase();   
                }
                // check if message of stop pairing is received
                if (call AMPacket.destination(buf) == TOS_NODE_ID && received_msg->msg_type == 1 )
                {
                    //printf("Parent: pairing timer stopped.\n");
                    call PairingTimer.stop();
                }
                //check if message received is standing
                else if (call AMPacket.destination(buf) == TOS_NODE_ID && received_msg->msg_type == 2)
                {
                    x_position = received_msg->x_pos;
                    y_position = received_msg->y_pos;
                    printf("Parent: CHILD is STANDING. Position X: %d, Y: %d.\n",received_msg->x_pos,received_msg->y_pos);
                    call MilliTimer.startOneShot(60000);
                }

                //check if message received is walking
                else if (call AMPacket.destination(buf) == TOS_NODE_ID && received_msg->msg_type == 3)
                {
                    x_position = received_msg->x_pos;
                    y_position = received_msg->y_pos;
                    printf("Parent: CHILD is WALKING. Position X: %d, Y: %d.\n",received_msg->x_pos,received_msg->y_pos);
                    call MilliTimer.startOneShot(60000);
                }
                //check if message received is running
                else if (call AMPacket.destination(buf) == TOS_NODE_ID && received_msg->msg_type == 4)
                {
                    x_position = received_msg->x_pos;
                    y_position = received_msg->y_pos;                
                    printf("Parent: CHILD is RUNNING. Position X: %d, Y: %d.\n",received_msg->x_pos,received_msg->y_pos);
                    call MilliTimer.startOneShot(60000);
                }
                //check if message received is FALLING
                else if (call AMPacket.destination(buf) == TOS_NODE_ID && received_msg->msg_type == 5)
                {
                    x_position = received_msg->x_pos;
                    y_position = received_msg->y_pos;
                    printf("ALERT: CHILD is FALLING. Position X: %d, Y: %d.\n",received_msg->x_pos,received_msg->y_pos);
                    call MilliTimer.stop();
                    call AMControl.stop();
                }
            }
            return buf;
        }
        else if (TOS_NODE_ID%2==0)
        {
            if (len != sizeof(my_msg_t))
            {
                //printf("Child: wrong message length.Message discarded.\n");
                return buf;
            }
            else
            {
                //check if broadcast message
                if (call AMPacket.destination(buf) == AM_BROADCAST_ADDR && received_msg->msg_type == 0 && strcmp((char*)received_msg->key,key_string)==0)
                {
                    motepaired = call AMPacket.source(buf);
                    stopPairingPhase();
                }
                // check if message of stop pairing is received
                if (call AMPacket.destination(buf) == TOS_NODE_ID && received_msg->msg_type == 1 )
                {
                    //printf("Child: pairing timer stopped.\n");
                    call PairingTimer.stop();
                }
            }
            return buf;
        }
        
        
    }

	event void AMSend.sendDone(message_t* buf, error_t err)
	{
		if(TOS_NODE_ID%2==1)
        {
            if (&packet == buf && err == SUCCESS)
            {
                locked = FALSE;
                //printf("Parent: message acked.\n");
                if (type == 1 && !(call PacketAck.wasAcked(buf)))
                {
                    //printf("Parent: entering stop pairing phase.\n");
                    stopPairingPhase();
                }
            }
            else
            {
                //printf("Parent: message not acked.\n");
            }
        }
        else if (TOS_NODE_ID%2==0)
        {
            if (&packet == buf && err == SUCCESS)
            {
                locked = FALSE;
                if (type == 1 && !(call PacketAck.wasAcked(buf)))
                {
                    //printf("Child: entering stop pairing phase.\n");
                    stopPairingPhase();
                }
                else if (type == 1 && call PacketAck.wasAcked(buf))
                {
                    //printf("Child: start operation mode.\n");
                    call MilliTimer.startPeriodic(10000);
                }
                else if (type == 2 && call PacketAck.wasAcked(buf))
                {
                    //printf("Child: operation message acked.\n");
                }
                else if (type == 3 && call PacketAck.wasAcked(buf))
                {
                    //printf("Child: operation message acked.\n");
                }
                else if (type == 4 && call PacketAck.wasAcked(buf))
                {
                    //printf("Child: operation message acked.\n");
                }
                else if (type == 5 && call PacketAck.wasAcked(buf))
                {
                    //printf("Child: operation message acked.\n");
                }
                else if (!(call PacketAck.wasAcked(buf)) && (type > 1) )
                {
                    //printf("Child: parent device outside range.\n");
                    call WaitTimer.startOneShot(60000);
                }
            }
            else
            {
                //printf("Child: message not acked.\n");
            }
        }
        
	}
	
	event void WaitTimer.fired()
	{
		printf("Child: Lost connection with the parent's bracelet.\n");
		call AMControl.stop();
	}
	
    void stopPairingPhase()
    {
        my_msg_t* stop_pairing_message = (my_msg_t*) (call Packet.getPayload(&packet,sizeof(my_msg_t)));
        if(TOS_NODE_ID%2==1)
        {
            if (locked == FALSE)
            {
                stop_pairing_message->msg_type = 1;
                type=1;
                call PacketAck.requestAck(&packet);
                if (call AMSend.send(motepaired, &packet, sizeof(my_msg_t)) == SUCCESS)
                {
                    //printf("Parent: sending stop pairing message.\n");
                    locked = TRUE;
                    call MilliTimer.startOneShot(60000);
                }
            }
        }
        else if (TOS_NODE_ID%2==0)
        {
            if (locked == FALSE)
            {
                stop_pairing_message->msg_type = 1;
                type=1;
                call PacketAck.requestAck(&packet);
                if (call AMSend.send(motepaired, &packet, sizeof(my_msg_t)) == SUCCESS)
                {
                    //printf("Child: sending stop pairing message.\n");
                    locked = TRUE;
                }
            }
        }
        
    }

    event void MilliTimer.fired()
    {
        my_msg_t* msg_send =(my_msg_t*) (call Packet.getPayload(&packet,sizeof(my_msg_t)));
        if(TOS_NODE_ID%2==1)
        {
            printf("MISSING --> Child is outside range for more than one minute. Last known position: %d,%d.\n",x_position,y_position);
            call AMControl.stop();
        }
        else if (TOS_NODE_ID%2==0)
        {
            p=(call Random.rand16()%101);
            if (p <= px)
            {
                type = 2;
                x_position = (call Random.rand16()%1001);
                y_position = (call Random.rand16()%1001);
            }
            else if (p>px && p <= (px+py))
            {
                type =3;
                x_position = (call Random.rand16()%1001);
                y_position = (call Random.rand16()%1001);
            }
            else if (p > (px+py) && p <= (px+py+pz))
            {
                type = 4;
                x_position = (call Random.rand16()%1001);
                y_position = (call Random.rand16()%1001);
            }
            else if (p > (px+py+pz) && p <= (px+py+pz+ph))
            {
                type = 5;
                x_position = (call Random.rand16()%1001);
                y_position = (call Random.rand16()%1001);
            }
            // Msg send interface
            msg_send -> msg_type = type;
            msg_send -> x_pos = x_position;
            msg_send -> y_pos = y_position;
            if (locked == FALSE)
            {
                if (call AMSend.send(motepaired, &packet, sizeof (my_msg_t)) == SUCCESS)
                {
                    locked = TRUE;
                    //printf("Child radio: message sent.\n");
                    if (type == 5)
                    {
                        
                        call AMControl.stop();
                    }
                
                }
            }
        }
        
    }
    
    
}
