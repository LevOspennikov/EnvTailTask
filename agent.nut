#require "JSONEncoder.class.nut:1.0.0"
#require "PrettyPrinter.class.nut:1.0.1"
#require "JSONParser.class.nut:1.0.0"

const PORT = "8080";
const HANDSHAKE = "HSH"; 
const _DEV_ = 0; 
const VIS_URL = "https://api.thingspeak.com/update.json";
const API_KEY = "I36F3MDSI00DF4KI";
const RESP_API_KEY = "1YJJJR9F1RMXH4JR";
const UPDATE_TIME = 10;

const ERR_TAG = "ERROR: ";
const DATA_STRUCTURE_ERROR = "Wrong data message structure";
const INV_API_KEY_ERROR = "Invalid api_key"; 
const ALERT_ANS = "Alert recivied"; 


class AgentEnvTail { 
    
    _pp = null; 
    print = null
   
    function constructor() { 
        if (_DEV_) {
            _pp = PrettyPrinter(null, false);  
            print = _pp.print.bindenv(_pp);
        }
        device.on(HANDSHAKE, startServer.bindenv(this));
        device.on(PORT, onMessageRecivied.bindenv(this)); 
        http.onrequest(requestHandler.bindenv(this));
    }

    //callback from device 
    function onMessageRecivied(message) {
        if (("pressure" in message) && ("temp" in message)) {
             _sendDataToUrl(_createDataString(message), VIS_URL); 
        } else {
            _log(ERR_TAG + DATA_STRUCTURE_ERROR); 
        }
    }
    
     //starting server, when handshake is done
    function startServer(message) {
        _log("Device Id: " + message); 
        _log("Start server"); 
        this.collectDataFromDevice();
    }

    //get data request
    function collectDataFromDevice() {
        _log("Ask to collect");
        device.send(PORT, "collect");
    }

    //handler for http requests from internet 
    function requestHandler(request, response) {
        try {
            _log("message from server");
            local json = JSONParser.parse(request.body);
            if (("api_key" in json) && (json.api_key == RESP_API_KEY)) {
                if ("alert" in json) {
                    _log(ALERT_ANS); 
                    response.send(200, ALERT_ANS);
                    device.send(PORT, "alert"); 
                }
            } else {
                _log(INV_API_KEY_ERROR);
                response.send(500, INV_API_KEY_ERROR);
            }
        } catch (error) {
            _log(ERR_TAG + error);
            response.send(500, error);
        }
    }
    
    //create specific string json for thingspeak.com 
    function _createDataString(message) { 
        local json = {  "field1" : message.temp,
                        "field2" : message.pressure,
                        "api_key" : API_KEY };
        return JSONEncoder.encode(json);
    }
    
    //handle response from 
    function _handleResponse(responseTable) {
        _log(responseTable); 
        if (responseTable.statuscode != 200) {
            _log(ERR_TAG + "Response " + responseTable.statuscode);
        }
        imp.wakeup(UPDATE_TIME, collectDataFromDevice.bindenv(this));
    }

    //send json to specific url
    function _sendDataToUrl(jsonString, url) {
        local headerJson = { "Content-Type" : "application/json" };
        local request = http.post(url, headerJson, jsonString);
        request.sendasync(_handleResponse.bindenv(this));    
    }
    
    function _log(message) {
        if (_DEV_) {
            print(message);
        }
    }
}

local agentEnv = AgentEnvTail(); 