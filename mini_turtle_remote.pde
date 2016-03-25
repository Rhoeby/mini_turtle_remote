/* =============================================================
 *                      General setup
 * ===========================================================*/

import android.view.MotionEvent;
import android.content.Intent;
import android.os.Bundle;
import ketai.net.bluetooth.*;
import ketai.ui.*;
import ketai.net.*;
import ketai.sensors.*;
import oscP5.*;

KetaiList klist;

//bluetooth-related
KetaiBluetooth bt;

void onCreate(Bundle savedInstanceState) {
    super.onCreate(savedInstanceState);
    bt = new KetaiBluetooth(this);
}

void onActivityResult(int requestCode, int resultCode, Intent data) {
    bt.onActivityResult(requestCode, resultCode, data);
}

boolean connected = false;
String connectedDevice = "";

//general
int mode = 0;
int globalScale;

//colors
color graphBackgroundColor = #9c9b7a;
color graphDotsColor = #405952;
color backgroundColor = #ffe2b5;
color mainColor = #fb6d35;
color highlightColor = #FA8B62;


void setup(){
    size(displayWidth,displayHeight);
    orientation(PORTRAIT);
    globalScale = min(width,height)*4/5;
    textSize(globalScale/10);
    textAlign(CENTER,CENTER);
    imageMode(CENTER);
    
    bt.start();
    bt.discoverDevices();  
    
    graphSetup();
    joystickSetup();
    buttonSetup();
    
}

void draw(){
    if(mode==2){
        background(graphBackgroundColor);
        showGraph();
        joystickControl();
        buttons();
        
    }
    else if(mode==1) resetMode();
    else if(mode==0) startup();
}



void startup(){
    background(150);
    
    bt.discoverDevices();
    if (bt.getDiscoveredDeviceNames().size() > 0){
            klist = new KetaiList(this, bt.getDiscoveredDeviceNames());
            mode = 2;
}

     else if (bt.getPairedDeviceNames().size() > 0){
            klist = new KetaiList(this, bt.getPairedDeviceNames());;
            mode = 2;
     }
     
}

void onKetaiListSelection(KetaiList klist)
{
    String selection = klist.getSelection();
    if(bt.connectDevice(bt.lookupAddressByName(selection)) == false) connected = false;
    else connected = true;
    connectedDevice = bt.lookupAddressByName(selection);

    //dispose of list for now
    klist = null;
}

/* =============================================================
 *    Drawing the Joystick and sending its data to the turtle
 * ===========================================================*/

PVector circlelocation = new PVector(0,0);
PVector position = new PVector();
PVector offset = new PVector();
int radius;
boolean pickedup = false;
PVector joystickLocation;
int joystickScale;
PImage rhoebyLogo;

void joystickSetup(){
    joystickScale = height/3;
    radius = joystickScale/2;
    joystickLocation = new PVector(width - radius, height*5/6);
    position.set(joystickLocation);
    rhoebyLogo = loadImage("rhoeby_alpha_75.png");
}



void joystickControl(){
    //draw joystick background
    noStroke();
    fill(backgroundColor);
    rect(width/2,height*5/6,width,height*2/6);
    fill(mainColor);
    stroke(mainColor);
    noStroke();
    ellipse(joystickLocation.x, joystickLocation.y,joystickScale,joystickScale);
    stroke(backgroundColor);
    strokeWeight(joystickScale/6);
    line(joystickLocation.x, joystickLocation.y + joystickScale * 4 / 10, joystickLocation.x, joystickLocation.y - joystickScale*4/10);
    line(joystickLocation.x + joystickScale * 4 / 10, joystickLocation.y , joystickLocation.x - joystickScale*4/10, joystickLocation.y );
    //calculate joystick position
    if(pickedup){
        position.set(mouseX - offset.x, mouseY - offset.y);
        circlelocation.set(position.x - joystickLocation.x, joystickLocation.y - position.y);
        if (circlelocation.mag() > joystickScale/2 - radius/2)
        {
            circlelocation.setMag(joystickScale/2 - radius/2);
            position.set(circlelocation.x + joystickLocation.x, joystickLocation.y - circlelocation.y);
        }
        fill(highlightColor);
    }
    else{
        circlelocation.set(position.x - joystickLocation.x, joystickLocation.y - position.y);
        fill(mainColor);
    }
    //draw "puck"
    stroke(99);
    strokeWeight(joystickScale/100);
    ellipse(position.x, position.y,radius,radius);
    image(rhoebyLogo, position.x,position.y,radius*2/3,radius*2/3);
    if(!pickedup){
        position.x = position.x - (position.x - joystickLocation.x)/5;
        position.y = position.y - (position.y - joystickLocation.y)/5;
    }
    jdirection();
}

//send directional data to turtle

PVector scalePos = new PVector(0,0);
PVector lastloc = new PVector(0,0);
byte Up = (byte)0x80;
byte Down = (byte) 0x81;
byte Left = (byte) 0x82;
byte Right = (byte)0x83;

void jdirection(){
    
    scalePos.x = round(circlelocation.x * 33 / joystickScale);
    scalePos.y = Math.signum(circlelocation.y)*min(abs(round(circlelocation.y * 33 / joystickScale)), 10 - abs(scalePos.x));
     if( (scalePos.x != lastloc.x | scalePos.y != lastloc.y) && pickedup){
        if(scalePos.x > lastloc.x) spamTurtle(Right, (scalePos.x - lastloc.x));
        if(scalePos.x < lastloc.x) spamTurtle(Left, (lastloc.x - scalePos.x));
        if(scalePos.y > lastloc.y) spamTurtle(Up, (scalePos.y - lastloc.y));
        if(scalePos.y < lastloc.y) spamTurtle(Down, (lastloc.y - scalePos.y));
        print(str(scalePos.x - lastloc.x) + " " + str(scalePos.y - lastloc.y));
    }
    else if(!pickedup){
        scalePos.set(0,0);
        lastloc.set(0,0);
    }
    lastloc.set(scalePos);
    
}

void mousePressed(){
    offset.set(mouseX - position.x,mouseY - position.y);
    if(sq(mouseX - position.x) + sq(mouseY - position.y) < sq(radius/2) && mode==2){
        pickedup = true;
    }
}
void mouseReleased(){
    if (pickedup == true) sendToTurtle(0x84);
    pickedup = false;
}



/* =============================================================
 *                    Drawing the graph
 * ===========================================================*/



PVector graphCenter = new PVector();
PImage graphImage;
float graphZoom;
float graphAngle = 0;
KetaiGesture gesture;

void graphSetup(){
            scannerPayload = new byte[800];
        for(int i = 0; i < 800; i++){
            if(i % 2 == 1) scannerPayload[i] = (byte)9;
            else scannerPayload[i] = (byte)round(125 + 125*sin(i / 100));
        }
    graphCenter.set(width/2, height/3);
    graphImage = createImage(width / 4, height / 6, ARGB);
    graphZoom = width;
    gesture = new KetaiGesture(this);
}

void showGraph(){
    graphData();
    image(graphImage, width/2, height/3, width, height*2/3);
}

void graphData(){
    if (scannerPayload == null) return;
    graphImage = createImage(width / 4, height / 6, ARGB);
    noStroke();
    fill(mainColor);
    ellipse(graphCenter.x, graphCenter.y, width/30, width/30);
    fill(graphDotsColor);
    for(int i = 0; i < scannerPayload.length; i+=2){
        stroke(0);
        int lower = (scannerPayload[i] & 0xFF);
        int upper = ((scannerPayload[i + 1] & 0xFF) << 8);
        int distance = upper + lower;
        float x = distance * cos((i * PI * 2) / (scannerPayload.length) + graphAngle) * (graphZoom/(globalScale*40));
        float y = distance * sin((i * PI * 2) / (scannerPayload.length) + graphAngle) * (graphZoom/(globalScale*40));
        graphImage.set(round(x + graphImage.width/2),round(y + graphImage.height/2),graphDotsColor);
        
    }
}


void onPinch(float x, float y, float d)
{
  graphZoom = constrain(graphZoom + d, width/6, 4*width);
}

void onRotate(float x, float y, float ang)
{
  graphAngle += ang;
}
public boolean surfaceTouchEvent(MotionEvent event) {

  super.surfaceTouchEvent(event);

  return gesture.surfaceTouchEvent(event);
}



/* =============================================================
 *                Interacting with the turtle
 * ===========================================================*/

//process incoming data

void onBluetoothDataEvent(String who, byte[] data){
    processData(data);
}

int ParserState = 0;
byte[] payload = new byte[0];
byte msgtype = 0;
byte temp = 0;
int payloadlength = 0;
int payloadposition = 0;
boolean processDataFinished = false;
byte[] scannerPayload;
void processData(byte[] data){
    if(!processDataFinished){
        ParserState = 0;
        print("Process Data Didn't finish!");
    }
    processDataFinished = false;
    for(byte b : data){
        switch(ParserState){
            case 0:
                temp = 0;
                if (b == (byte)0xff) ParserState = 1;
                break;
            case 1:
                if (b == (byte)0xff) ParserState = 2;
                else ParserState = 0;
                break;
            case 2:
                msgtype = b;
                ParserState = 3;
                break;
            case 3:
                payloadlength = (b & 0xFF) << 8;
                ParserState = 4;
                break;
            case 4:
                payloadlength += (b & 0xFF);
                if (payloadlength < 1025){
                    payloadposition = 0;
                    payload = new byte[payloadlength];
                    ParserState = 5;
                }
                else ParserState = 0;
                break;
            case 5:
                
                if (payloadposition < payloadlength){
                    payload[payloadposition] = b;
                    payloadposition +=1;
                }
                else{
                    if( b != (byte)~temp){
                        print("Checksum Failed!");
                        return;
                    }
                    switch(msgtype){
                        case (byte)0:
                            scannerPayload = payload;
                            break;
                        case (byte)1:
                            updateStatus(payload);
                            break;
                    
                    }
                    ParserState = 0;
                }
                break;
        }       
        temp += b;
    }
    processDataFinished = true;
}

void updateStatus(byte[] data){
    if((data[4] & 1) == 1) resetFlag = true;
    else resetFlag = false;    
}

//send to turtle

void sendToTurtle(int cmd){
    byte[] data = {(byte)0xFF, (byte)0xFF, (byte) cmd, 0, 0};
    data[4] = checksum(data);
    bt.write(connectedDevice, data);
}

void sendToTurtle(int cmd, byte[] payload){
    byte[] data = new byte[payload.length + 5];
    data[0] = (byte)0xFF;
    data[1] = (byte)0xFF;
    data[2] = (byte)cmd;
    data[3] = (byte)payload.length;
    for(int i = 0; i < payload.length; i++){
        data[i + 4] = payload[i];
    }
    data[data.length - 1] = checksum(data);
    bt.write(connectedDevice, data);
}


void spamTurtle(int cmd, float times){
    byte[] data = {(byte)0xFF, (byte)0xFF, (byte) cmd, 0, 0};
    data[4] = checksum(data);
    for(int i = 0; i < times; i++) bt.write(connectedDevice, data);
}

void setScanPeriod(int period){
    int topbyte = period & 0xFF;
    int bottombyte = (period & 0xFF00) >> 8;
    byte[] tosend = {(byte)topbyte, (byte)bottombyte};
    sendToTurtle(2, tosend);
}

byte checksum(byte[] data){
    byte temp = byte(0);
    for(byte b : data){
        temp += b;
    }
    return (byte)~temp;
}

//process for resetting the scanner

Boolean resetFlag = true;
int resetStage = 0;
void resetMode(){
    background(backgroundColor);
    cancelbutton.Draw();
    if(cancelbutton.clicked) {
        resetStage = 0;
        mode = 2;
    }
    switch(resetStage){
        case 0:
            sendToTurtle(4);
            resetStage = 1;
            break;
        case 1:
            text("sending reset code",width/2, height/2);
            if(!resetFlag){
                sendToTurtle(3);
                resetStage = 2;
            }
            break;
        case 2:
            text("Reset recieved!\nSending reset request", width/2, 2*height/3);
            if(resetFlag) resetStage = 3;
            
            break;
        case 3:
            text("Fully reset", width/2, 4*height/5);
            resetStage = 0;
            mode = 2;
            break;

    }
}


/* =============================================================
 *                           Buttons
 * ===========================================================*/


button resetbutton;
button startscannerbutton;
button stopscannerbutton;
button cancelbutton;
void buttonSetup(){
    resetbutton = new button("Reset",width/4,height*13/18,globalScale/2,globalScale/6);
    startscannerbutton = new button("Set rate", width/4,height*15/18,globalScale/2,globalScale/6);
    stopscannerbutton = new button("Stop", width/4,height*17/18,globalScale/2,globalScale/6);
    cancelbutton = new button("cancel", width/2,height/5,globalScale/3,globalScale/6); 
}

void buttons(){
    
    resetbutton.Draw();
    startscannerbutton.Draw();
    stopscannerbutton.Draw();
    
    if(resetbutton.clicked){
        resetStage = 0;
        mode = 1;
    }
    if(startscannerbutton.clicked){
        setScanPeriod(333);
    }
    if(stopscannerbutton.clicked){
        sendToTurtle(1);
    }
}

class button {
        String label;
        float x;        // center x position
        float y;        // center y position
        float w;        // width of button
        float h;        // height of button
        boolean clicked = false;
        boolean pressed = false;
        boolean mouseAlreadyWasPressed = false;
        button(String labelB, float xpos, float ypos, float Width, float Height) {
                label = labelB;
                x = xpos;
                y = ypos;
                w = Width;
                h = Height;
                rectMode(CENTER);
                textAlign(CENTER,CENTER);
        }
        void Draw() {
                if(clicked==true) clicked=false;
                mouse();
                if(pressed) fill(highlightColor);
                else fill(mainColor);
                noStroke();
                rect(x,y,w,h,width/70);
                fill(50);
                text(label,x,y);
        }
        void mouse(){
            if(!mousePressed) mouseAlreadyWasPressed = false;
            if (mousePressed && pressed==false && abs(mouseX - x) < w/2 && abs(mouseY - y) < h/2 && !pickedup && !mouseAlreadyWasPressed){
                pressed = true;
                clicked = true;
            }
         else if(!mousePressed) pressed=false;
         if(mousePressed && !mouseAlreadyWasPressed) mouseAlreadyWasPressed = true;
         
        }
}
