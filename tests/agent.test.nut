class AgentTestCase1 extends ImpTestCase {

    static mfabs = math.fabs;
    static RESP_API_KEY = "1YJJJR9F1RMXH4JR";
    _AET = null; 
    
    function setUp() {
        _AET = AgentEnvTail(); 
    }
    
    function floatEquals(a, b) {
        return mfabs(a - b) < 0.1
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
    
    
    function testCreateJson() {
        const NUMS = 20; 
        for (local i = 0 ; i < NUMS ; i++) {
            local press = 1.0 * math.rand() % 400;
            local temp = 1.0 * math.rand() % 100;
            local message = {"pressure" : press,
                             "temp" : temp  };
            local json = JSONParser.parse(_AET.createDataString(message)); 
            assertTrue(floatEquals(temp, json.field1), temp + " != " + json.field1);
            assertTrue(floatEquals(press, json.field2), press + " != " + json.field2);
        }
    }
  
    function tearDown() {
	
    }
}
