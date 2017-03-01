#require "LPS25H.class.nut:2.0.1"
#require "Si702x.class.nut:1.0.0"
#require "PrettyPrinter.class.nut:1.0.1"
#require "JSONEncoder.class.nut:1.0.0"

const PORT = "8080"
const HANDSHAKE = "HSH"; 
const _DEV_ = 1;

class DeviceEnvTail {

    _i2c89 = null; 
    _pressureSensor = null;
    _humidSensor = null; 
    _led = null;
    
    
    function constructor() { 
        _i2c89 = hardware.i2c89;
        _i2c89.configure(CLOCK_SPEED_400_KHZ);
        _pressureSensor = LPS25H(_i2c89);
        _pressureSensor.softReset();
        _pressureSensor.enable(true);
        _humidSensor = Si702x(_i2c89);
        _led = hardware.pin2;
        _led.configure(DIGITAL_OUT, 0);
        agent.on(PORT, onMessageRecivied.bindenv(this));
        //Says to to agent, that device is ready to recieve messages
        agent.send(HANDSHAKE, hardware.getdeviceid()); 
    }
    
    function debugOutput(message) {
        if (_DEV_) {
            server.log(message);
        }
    }

    //ServerMessage handler
    function onMessageRecivied(message) {
        switch (message) {
            case "collect":
                takeData();
                break;
            case "alert":
                alertSound(); 
                break;
            default:
                debugOutput("Unexpected message " + message)
        }
    }

    //Do some alert when temperature is high
    function alertSound() { 
        _led.write(1);
        debugOutput("FIRE ALERT!");
        debugOutput("FIRE ALERT!");
        debugOutput("FIRE ALERT!");
        imp.wakeup(1, (@() _led.write(0)).bindenv(this)); 
    }

    //Read data from sensors
    function takeData(callback = null) {
        local data = {};    
        _humidSensor.read(function(reading) {
            if ("err" in reading) {
                data.temp <- null;
                debugOutput("Error reading temperature: " + reading.err);
            } else {
                data.temp <- reading.temperature;
                debugOutput(format("Current Temperature: %0.1f deg C", data.temp));
            }
            _pressureSensor.read(function(reading) {
                if ("err" in reading) {
                    debugOutput("Error reading pressure: " + reading.err); 
                } else {
                    data.pressure <- reading.pressure; 
                    debugOutput(format("Current Pressure: %0.2f hPa", reading.pressure));
                }
                agent.send(PORT, data);
                if (callback != null) { 
                    callback();
                }
            }.bindenv(this));
        }.bindenv(this));
    }
}

local deviceEnvTail = DeviceEnvTail(); 