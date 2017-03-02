class AgentTestCase1 extends ImpTestCase {

    static RESP_API_KEY = "1YJJJR9F1RMXH4JR";
    _AET = null; 
    
    function setUp() {
        _AET = AgentEnvTail(); 
    }
    
    function testRequestHandler() {
        local rdata = {"api_key" : this.RESP_API_KEY, "alert" : ""};
        local bdata = {"api_key" : "WRONG_KEY", "alert" : ""};
        local response = {}; 
        response.send <- function(code, message) { 
            this.assertEqual(200, code, "Awaiting good response");
        }.bindenv(this);
        local request = {};
        request.body <- JSONEncoder.encode(rdata);
        _AET.requestHandler(request, response);
        request.body <- JSONEncoder.encode(bdata);
        response.send = function(code, message) { 
            this.assertTrue(200 != code, "Awaiting bad response");
        }.bindenv(this); 
        _AET.requestHandler(request, response);
    }
    
    function testVerifyJson() {
        local press = 250.356;
        local temp = 27.3435;
        local message = {"pressure" : press,
                         "temp" : temp  };
        local json = JSONParser.parse(_AET._createDataString(message)); 
        assertEqual(temp.tostring(), json.field1.tostring(), temp + " != " + json.field1);
        assertEqual(press.tostring(), json.field2.tostring(), press + " != " + json.field2);
    }
  
    function tearDown() {
	
    }
}
