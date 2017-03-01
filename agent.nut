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
    
    function debugOutput(message) {
        if (_DEV_) {
            print(message);
        }
    }
   
    function constructor() { 
        if (_DEV_) {
            _pp = PrettyPrinter(null, false);  
            print = _pp.print.bindenv(_pp);
        }
        device.on(HANDSHAKE, startServer.bindenv(this));
        device.on(PORT, onMessageRecivied.bindenv(this)); 
        http.onrequest(requestHandler.bindenv(this));
    }
    
    //handle response from 
    function handleResponse(responseTable) {
        debugOutput(responseTable); 
        if (responseTable.statuscode != 200) {
            debugOutput(ERR_TAG + "Response " + responseTable.statuscode);
        }
        imp.wakeup(UPDATE_TIME, collectDataFromDevice.bindenv(this));
    }

    //send json to specific url
    function sendDataToUrl(jsonString, url) {
        local headerJson = { "Content-Type" : "application/json" };
        local request = http.post(url, headerJson, jsonString);
        request.sendasync(handleResponse.bindenv(this));    
    }

    //callback from device 
    function onMessageRecivied(message) {
        if (("pressure" in message) && ("temp" in message)) {
             sendDataToUrl(createDataString(message), VIS_URL); 
        } else {
            debugOutput(ERR_TAG + DATA_STRUCTURE_ERROR); 
        }
    }

    //create specific string json for thingspeak.com 
    function createDataString(message) { 
        local json = {  "field1" : message.temp,
                        "field2" : message.pressure,
                        "api_key" : API_KEY };
        return JSONEncoder.encode(json);
    }
    
     //starting server, when handshake is done
    function startServer(message) {
        debugOutput("Device Id: " + message); 
        debugOutput("Start server"); 
        this.collectDataFromDevice();
    }

    //get data request
    function collectDataFromDevice() {
        debugOutput("Ask to collect");
        device.send(PORT, "collect");
    }

    //handler for http requests from internet 
    function requestHandler(request, response) {
        try {
            debugOutput("message from server");
            local json = JSONParser.parse(request.body);
            if (("api_key" in json) && (json.api_key == RESP_API_KEY)) {
                if ("alert" in json) {
                    debugOutput(ALERT_ANS); 
                    response.send(200, ALERT_ANS);
                    device.send(PORT, "alert"); 
                }
            } else {
                debugOutput(INV_API_KEY_ERROR);
                response.send(500, INV_API_KEY_ERROR);
            }
        } catch (error) {
            debugOutput(ERR_TAG + error);
            response.send(500, error);
        }
    }
}

local agentEnv = AgentEnvTail(); 