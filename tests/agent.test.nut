class AgentTestCase1 extends ImpTestCase {

    static mfabs = math.fabs;
    
    function setUp() {
         
    }
    
    function floatEquals(a, b) {
        return mfabs(a - b) < 0.1
    }

    function testRequestHandler() {
        local rdata = {"api_key" : "1YJJJR9F1RMXH4JR", "allert" : ""};
        local bdata = {"api_key" : "WRONG_KEY", "allert" : ""};
        local response = {}; 
        response.send <- function() {};
        response.send = function(code, message) { 
            this.assertEqual(200, code, "Awaiting good response");
        }.bindenv(this);
        local request = {};
        request.body <- JSONEncoder.encode(rdata);
        requestHandler(request, response);
        response.send = function(code, message) { 
            this.assertTrue(200 != code, "Awaiting bad response");
        }.bindenv(this); 
        requestHandler(request, response);
    }
    
    
    function testCreateJson() {
        const NUMS = 20; 
        for (local i = 0 ; i < NUMS ; i++) {
            local press = 1.0 * math.rand() % 400;
            local temp = 1.0 * math.rand() % 100;
            local message = {"pressure" : press,
                             "temp" : temp  };
            local json = JSONParser.parse(createDataJson(message)); 
            // server.log("IMPOTANT: " + floatEquals(temp, json.field1) + math.fabs(temp - json.field1));
            assertTrue(floatEquals(temp, json.field1), temp + " != " + json.field1);
            assertTrue(floatEquals(press, json.field2), press + " != " + json.field2);
        }
    }
  
    function tearDown() {
	
    }
}
