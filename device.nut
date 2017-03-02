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
    }

    //ServerMessage handler
    function onMessageRecivied(message) {
        switch (message) {
            case "collect":
                _takeData();
                break;
            case "alert":
                _alertSound(); 
                break;
            default:
                _log("Unexpected message " + message)
        }
    }

    //Do some alert when temperature is high
    function _alertSound() { 
        _led.write(1);
        _log("FIRE ALERT!");
        _log("FIRE ALERT!");
        _log("FIRE ALERT!");
        imp.wakeup(1, (@() _led.write(0)).bindenv(this)); 
    }

    //Read data from sensors
    function _takeData(callback = null) {
        local data = {};    
        _humidSensor.read(function(reading) {
            if ("err" in reading) {
                data.temp <- null;
                _err("Error reading temperature: " + reading.err);
            } else {
                data.temp <- reading.temperature;
                _log(format("Current Temperature: %0.1f deg C", data.temp));
            }
            _pressureSensor.read(function(reading) {
                if ("err" in reading) {
                    data.pressure <- null; 
                    _err("Error reading pressure: " + reading.err); 
                } else {
                    data.pressure <- reading.pressure; 
                    _log(format("Current Pressure: %0.2f hPa", reading.pressure));
                }
                agent.send(PORT, data);
                if (callback != null) { 
                    callback();
                }
            }.bindenv(this));
        }.bindenv(this));
    }
    
    function _log(message) {
        if (_DEV_) {
            server.log(message);
        }
    }
    
    function _err(message) {
        server.error(message);
    }
}

local deviceEnvTail = DeviceEnvTail(); 

//Says to to agent, that device is ready to recieve messages
imp.wakeup(0, @() agent.send(HANDSHAKE, hardware.getdeviceid()) );
