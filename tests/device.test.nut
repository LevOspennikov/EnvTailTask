

class DeviceTestCase1 extends ImpTestCase {

    _DET = null;
    
    function setUp() {
        _DET = DeviceEnvTail(); 
    }
    
    function checkCount() {
        assertEqual(NUMS, count, "Counting sent data" + count + "!= " + NUMS);
    }
    
    function testTakeData() {
        const NUMS = 4;
        local count = 0;
        local callback = function() {
            count++;
        }.bindenv(this); 
        for (local i = 0 ; i < NUMS ; i++) { 
            _DET._takeData(callback);
            
        }
        
        imp.wakeup(4, checkCount.bindenv(this)); 
    }
    
    function tearDown() {
        _DET = null; 
    }
}
