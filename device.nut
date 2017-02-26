#require "LPS25H.class.nut:2.0.1"
#require "Si702x.class.nut:1.0.0"
#require "PrettyPrinter.class.nut:1.0.1"
#require "JSONEncoder.class.nut:1.0.0"

const PORT = "8080"
const HANDSHAKE = "HSH"; 

function sendMessage(message) {
    agent.send(PORT, message);
}
 
//ServerMessage handler
function onMessageRecivied(message) {
    switch (message) {
        case "collect":
            takeData();
            break;
        case "allert":
            allertSound(); 
            break;
        default:
            server.log("Unexpected message " + message)
    }
}

hardware.i2c89.configure(CLOCK_SPEED_400_KHZ);
local pressureSensor = LPS25H(hardware.i2c89);
local humidSensor = Si702x(hardware.i2c89);
local led = hardware.pin2;
led.configure(DIGITAL_OUT, 0);
agent.on(PORT, onMessageRecivied);
data <- {};

//Do some alert when temperature is high
function allertSound() { 
    led.write(1);
    server.log("FIRE ALLERT!");
    server.log("FIRE ALLERT!");
    server.log("FIRE ALLERT!");
    imp.wakeup(1, @() led.write(0)); 
}

//Sends data when both sensonrs collect data
function tryToSendData() {
    if (("temp" in data) && ("pressure" in data)) {
        data.id <- hardware.getdeviceid();
        agent.send(PORT, data);
        data = {}; 
        return true; 
    }
    return false; 
}

//Read data from sensors
function takeData() {
    local isSent = false; 
    humidSensor.read(function(reading) {
        if ("err" in reading) {
            server.error("Error reading temperature: "+reading.err);
        } else {
            data.temp <- reading.temperature;
            server.log(format("Current Temperature: %0.1f deg C", data.temp));
            tryToSendData(); 
        }
    });
    pressureSensor.read(function(reading) {
        if ("err" in reading) {
            server.error("Error reading pressure: " + reading.err); 
        } else {
            data.pressure <- reading.pressure; 
            server.log(format("Current Pressure: %0.2f hPa", reading.pressure));
            pressureSensor.softReset();
            pressureSensor.enable(true);
            tryToSendData();
        }
    });
}

//Says to to agent, that device is ready to recieve messages
agent.send(HANDSHAKE, ""); 