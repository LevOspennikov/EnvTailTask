# NoBitLost Test Project
## Overview 
It is TailEnv by ElectricImp Vizualization project. Enviroment has two sensors: pressure sensor and temperature sensor(`LPS25H` and `Si702x`). Agent collect data from this sensors and send them to thingspeak.com channel (https://thingspeak.com/channels/231577), where they are visualized. When the temperature become greater than certain value, thingspeak sends alert signal on agent, then agent sends alert signal on device, which then blinks. 
## Details
When **device** is ready, it sends message to **agent**, and **agent** starts his work. The routine goes this way: **agent** starts with `serverStart` method and pass to device request `"collect"` with port `PORT`. **Device** reads data from two sensors and sends them to **agent**. **Agent** wraps it to `httpRequest` and sends to thingSpeak.com. The site refreshes vizualization and check, is temperature higher than predefined constant. In case of yes, the site sends back to **the agent** request, and `requestMethod()` handle it. If request contains `"alert"`, **the agent** sends `"alert"` command to **device**. 
## thingsspeak.com API 
To send request on thingsspeak.com we need only a couple things. First, is api key, that we store in `API_KEY` constant. Second is body of request, that contain `api_key`, `field1` and `field2` fields in json. `field1` will interpete by the site as a temperature, and `field2` as a pressure. 
## Additional
`RESP_API_KEY` constant contains value of key, that used thingspeak for response.

`UPDATE_TIME` constant is amount of seconds, that **agent** will wait before next `"collect"` request.

`_DEV_` constant is `1` if additional output required, and `0` in the other way.