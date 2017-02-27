

class DeviceTestCase1 extends ImpTestCase {

  
    function setUp() {
    }

    function testTakeData() {
        const NUMS = 1;
        
        for (local i = 0 ; i < NUMS ; i++) {
            takeData();
            imp.sleep(1); 
        }
        
        imp.sleep(1); 
        assertEqual(NUMS, count, "Count sent data"); 
    }
    

  
    function tearDown() {
    
    }
}
