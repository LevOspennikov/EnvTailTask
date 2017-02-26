#require "JSONEncoder.class.nut:1.0.0"
#require "PrettyPrinter.class.nut:1.0.1"
#require "JSONParser.class.nut:1.0.0"

const PORT = "8080";
const HANDSHAKE = "HSH"; 
const _DEV_ = 1; 
const VIS_URL = "https://api.thingspeak.com/update.json";
const API_KEY = "I36F3MDSI00DF4KI";
const RESP_API_KEY = "1YJJJR9F1RMXH4JR";
const UPDATE_TIME = 100;

const ERR_TAG = "ERROR: ";
const DATA_STRUCTURE_ERROR = "Wrong data message structure";
const INV_API_KEY_ERROR = "Invalid api_key"; 
const ALERT_ANS = "Alert recivied"; 

if (_DEV_) {
    pp <- PrettyPrinter(null, false);  
    print <- pp.print.bindenv(pp);
}

function sendMessage(message) {
    device.send(PORT, message);
}

//handle response from 
function handleResponse(responseTable) {
    if (_DEV_) {
        ::print(responseTable);
    }
    if (responseTable.statuscode != 200) {
        server.log(ERR_TAG + "Response " + responseTable.statuscode);
    } else {
       imp.wakeup(UPDATE_TIME, collectDataFromDevice);
    }
}

//wrap request 
function httpPostWrapper (url, headers, string) {
    local request = http.post(url, headers, string);
    local response = request.sendasync(handleResponse);
}

//send json to specific url
function sendDataToUrl(jsonString, url) {
    local headerJson = { "Content-Type" : "application/json" };
    local response = httpPostWrapper(url, headerJson, jsonString); 
}

//callback from device 
function onMessageRecivied(message) {
    if (_DEV_) {
        ::print(message);
    }
    if (("pressure" in message) && ("temp" in message)) {
        
         sendDataToUrl(createDataJson(message), VIS_URL); 
    } else {
        server.log(ERR_TAG + DATA_STRUCTURE_ERROR); 
    }
   
}

//create specific json for thingspeak.com 
function createDataJson(message) { 
    local json = {}
    json.field2 <- message.pressure; 
    json.field1 <- message.temp;
    json.api_key <- API_KEY; 
    local data = JSONEncoder.encode(json);
    return data;
}

//get data request
function collectDataFromDevice() {
    server.log("Ask to collect");
    sendMessage("collect"); 
}

//starting server, when handshake is done
function startServer(message) {
    server.log("Start server"); 
    collectDataFromDevice();
}

//handler for http requests from internet 
function requestHandler(request, response) {
    try {
        server.log("message from server");
        local json = JSONParser.parse(request.body);
        if (("allert" in json) && ("api_key" in json)
             && (json.api_key == RESP_API_KEY)) {
            server.log(ALERT_ANS); 
            response.send(200, ALERT_ANS);
            sendMessage("allert"); 
        } else {
            server.log(INV_API_KEY_ERROR);
            response.send(500, INV_API_KEY_ERROR);
        }
    } catch (error) {
        server.log(ERR_TAG + error);
        response.send(500, error);
    }
}

device.on(HANDSHAKE, startServer);
device.on(PORT, onMessageRecivied); 
http.onrequest(requestHandler);