class JSONParser {

  // should be the same for all components within JSONParser package
  static version = [1, 0, 0];

  /**
   * Parse JSON string into data structure
   *
   * @param {string} str
   * @param {function({string} value[, "number"|"string"])|null} converter
   * @return {*}
   */
  function parse(str, converter = null) {

    local state;
    local stack = []
    local container;
    local key;
    local value;

    // actions for string tokens
    local string = {
      go = function () {
        state = "ok";
      },
      firstokey = function () {
        key = value;
        state = "colon";
      },
      okey = function () {
        key = value;
        state = "colon";
      },
      ovalue = function () {
        value = this._convert(value, "string", converter);
        state = "ocomma";
      }.bindenv(this),
      firstavalue = function () {
        value = this._convert(value, "string", converter);
        state = "acomma";
      }.bindenv(this),
      avalue = function () {
        value = this._convert(value, "string", converter);
        state = "acomma";
      }.bindenv(this)
    };

    // the actions for number tokens
    local number = {
      go = function () {
        state = "ok";
      },
      ovalue = function () {
        value = this._convert(value, "number", converter);
        state = "ocomma";
      }.bindenv(this),
      firstavalue = function () {
        value = this._convert(value, "number", converter);
        state = "acomma";
      }.bindenv(this),
      avalue = function () {
        value = this._convert(value, "number", converter);
        state = "acomma";
      }.bindenv(this)
    };

    // action table
    // describes where the state machine will go from each given state
    local action = {

      "{": {
        go = function () {
          stack.push({state = "ok"});
          container = {};
          state = "firstokey";
        },
        ovalue = function () {
          stack.push({container = container, state = "ocomma", key = key});
          container = {};
          state = "firstokey";
        },
        firstavalue = function () {
          stack.push({container = container, state = "acomma"});
          container = {};
          state = "firstokey";
        },
        avalue = function () {
          stack.push({container = container, state = "acomma"});
          container = {};
          state = "firstokey";
        }
      },

      "}" : {
        firstokey = function () {
          local pop = stack.pop();
          value = container;
          container = ("container" in pop) ? pop.container : null;
          key = ("key" in pop) ? pop.key : null;
          state = pop.state;
        },
        ocomma = function () {
          local pop = stack.pop();
          container[key] <- value;
          value = container;
          container = ("container" in pop) ? pop.container : null;
          key = ("key" in pop) ? pop.key : null;
          state = pop.state;
        }
      },

      "[" : {
        go = function () {
          stack.push({state = "ok"});
          container = [];
          state = "firstavalue";
        },
        ovalue = function () {
          stack.push({container = container, state = "ocomma", key = key});
          container = [];
          state = "firstavalue";
        },
        firstavalue = function () {
          stack.push({container = container, state = "acomma"});
          container = [];
          state = "firstavalue";
        },
        avalue = function () {
          stack.push({container = container, state = "acomma"});
          container = [];
          state = "firstavalue";
        }
      },

      "]" : {
        firstavalue = function () {
          local pop = stack.pop();
          value = container;
          container = ("container" in pop) ? pop.container : null;
          key = ("key" in pop) ? pop.key : null;
          state = pop.state;
        },
        acomma = function () {
          local pop = stack.pop();
          container.push(value);
          value = container;
          container = ("container" in pop) ? pop.container : null;
          key = ("key" in pop) ? pop.key : null;
          state = pop.state;
        }
      },

      ":" : {
        colon = function () {
          // check if the key already exists
          if (key in container) {
            throw "Duplicate key \"" + key + "\"";
          }
          state = "ovalue";
        }
      },

      "," : {
        ocomma = function () {
          container[key] <- value;
          state = "okey";
        },
        acomma = function () {
          container.push(value);
          state = "avalue";
        }
      },

      "true" : {
        go = function () {
          value = true;
          state = "ok";
        },
        ovalue = function () {
          value = true;
          state = "ocomma";
        },
        firstavalue = function () {
          value = true;
          state = "acomma";
        },
        avalue = function () {
          value = true;
          state = "acomma";
        }
      },

      "false" : {
        go = function () {
          value = false;
          state = "ok";
        },
        ovalue = function () {
          value = false;
          state = "ocomma";
        },
        firstavalue = function () {
          value = false;
          state = "acomma";
        },
        avalue = function () {
          value = false;
          state = "acomma";
        }
      },

      "null" : {
        go = function () {
          value = null;
          state = "ok";
        },
        ovalue = function () {
          value = null;
          state = "ocomma";
        },
        firstavalue = function () {
          value = null;
          state = "acomma";
        },
        avalue = function () {
          value = null;
          state = "acomma";
        }
      }
    };

    //

    state = "go";
    stack = [];

    // current tokenizeing position
    local start = 0;

    try {

      local
        result,
        token,
        tokenizer = _JSONTokenizer();

      while (token = tokenizer.nextToken(str, start)) {

        if ("ptfn" == token.type) {
          // punctuation/true/false/null
          action[token.value][state]();
        } else if ("number" == token.type) {
          // number
          value = token.value;
          number[state]();
        } else if ("string" == token.type) {
          // string
          value = tokenizer.unescape(token.value);
          string[state]();
        }

        start += token.length;
      }

    } catch (e) {
      state = e;
    }

    // check is the final state is not ok
    // or if there is somethign left in the str
    if (state != "ok" || regexp("[^\\s]").capture(str, start)) {
      local min = @(a, b) a < b ? a : b;
      local near = str.slice(start, min(str.len(), start + 10));
      throw "JSON Syntax Error near `" + near + "`";
    }

    return value;
  }

  /**
   * Convert strings/numbers
   * Uses custom converter function
   *
   * @param {string} value
   * @param {string} type
   * @param {function|null} converter
   */
  function _convert(value, type, converter) {
    if ("function" == typeof converter) {

      // # of params for converter function

      local parametercCount = 2;

      // .getinfos() is missing on ei platform
      if ("getinfos" in converter) {
        parametercCount = converter.getinfos().parameters.len()
          - 1 /* "this" is also included */;
      }

      if (parametercCount == 1) {
        return converter(value);
      } else if (parametercCount == 2) {
        return converter(value, type);
      } else {
        throw "Error: converter function must take 1 or 2 parameters"
      }

    } else if ("number" == type) {
      return (value.find(".") == null && value.find("e") == null && value.find("E") == null) ? value.tointeger() : value.tofloat();
    } else {
      return value;
    }
  }
}

/**
 * JSON Tokenizer
 * @package JSONParser
 */
class _JSONTokenizer {

  _ptfnRegex = null;
  _numberRegex = null;
  _stringRegex = null;
  _ltrimRegex = null;
  _unescapeRegex = null;

  constructor() {
    // punctuation/true/false/null
    this._ptfnRegex = regexp("^(?:\\,|\\:|\\[|\\]|\\{|\\}|true|false|null)");

    // numbers
    this._numberRegex = regexp("^(?:\\-?\\d+(?:\\.\\d*)?(?:[eE][+\\-]?\\d+)?)");

    // strings
    this._stringRegex = regexp("^(?:\\\"((?:[^\\r\\n\\t\\\\\\\"]|\\\\(?:[\"\\\\\\/trnfb]|u[0-9a-fA-F]{4}))*)\\\")");

    // ltrim pattern
    this._ltrimRegex = regexp("^[\\s\\t\\n\\r]*");

    // string unescaper tokenizer pattern
    this._unescapeRegex = regexp("\\\\(?:(?:u\\d{4})|[\\\"\\\\/bfnrt])");
  }

  /**
   * Get next available token
   * @param {string} str
   * @param {integer} start
   * @return {{type,value,length}|null}
   */
  function nextToken(str, start = 0) {

    local
      m,
      type,
      token,
      value,
      length,
      whitespaces;

    // count # of left-side whitespace chars
    whitespaces = this._leadingWhitespaces(str, start);
    start += whitespaces;

    if (m = this._ptfnRegex.capture(str, start)) {
      // punctuation/true/false/null
      value = str.slice(m[0].begin, m[0].end);
      type = "ptfn";
    } else if (m = this._numberRegex.capture(str, start)) {
      // number
      value = str.slice(m[0].begin, m[0].end);
      type = "number";
    } else if (m = this._stringRegex.capture(str, start)) {
      // string
      value = str.slice(m[1].begin, m[1].end);
      type = "string";
    } else {
      return null;
    }

    token = {
      type = type,
      value = value,
      length = m[0].end - m[0].begin + whitespaces
    };

    return token;
  }

  /**
   * Count # of left-side whitespace chars
   * @param {string} str
   * @param {integer} start
   * @return {integer} number of leading spaces
   */
  function _leadingWhitespaces(str, start) {
    local r = this._ltrimRegex.capture(str, start);

    if (r) {
      return r[0].end - r[0].begin;
    } else {
      return 0;
    }
  }

  // unesacape() replacements table
  _unescapeReplacements = {
    "b": "\b",
    "f": "\f",
    "n": "\n",
    "r": "\r",
    "t": "\t"
  };

  /**
   * Unesacape string escaped per JSON standard
   * @param {string} str
   * @return {string}
   */
  function unescape(str) {

    local start = 0;
    local res = "";

    while (start < str.len()) {
      local m = this._unescapeRegex.capture(str, start);

      if (m) {
        local token = str.slice(m[0].begin, m[0].end);

        // append chars before match
        local pre = str.slice(start, m[0].begin);
        res += pre;

        if (token.len() == 6) {
          // unicode char in format \uhhhh, where hhhh is hex char code
          // todo: convert \uhhhh chars
          res += token;
        } else {
          // escaped char
          // @see http://www.json.org/
          local char = token.slice(1);

          if (char in this._unescapeReplacements) {
            res += this._unescapeReplacements[char];
          } else {
            res += char;
          }
        }

      } else {
        // append the rest of the source string
        res += str.slice(start);
        break;
      }

      start = m[0].end;
    }

    return res;
  }
}

class JSONEncoder {

  static VERSION = "2.0.0";

  // max structure depth
  // anything above probably has a cyclic ref
  static _maxDepth = 32;

  /**
   * Encode value to JSON
   * @param {table|array|*} value
   * @returns {string}
   */
  function encode(value) {
    return this._encode(value);
  }

  /**
   * @param {table|array} val
   * @param {integer=0} depth – current depth level
   * @private
   */
  function _encode(val, depth = 0) {

    // detect cyclic reference
    if (depth > this._maxDepth) {
      throw "Possible cyclic reference";
    }

    local
      r = "",
      s = "",
      i = 0;

    switch (typeof val) {

      case "table":
      case "class":
        s = "";

        // serialize properties, but not functions
        foreach (k, v in val) {
          if (typeof v != "function") {
            s += ",\"" + k + "\":" + this._encode(v, depth + 1);
          }
        }

        s = s.len() > 0 ? s.slice(1) : s;
        r += "{" + s + "}";
        break;

      case "array":
        s = "";

        for (i = 0; i < val.len(); i++) {
          s += "," + this._encode(val[i], depth + 1);
        }

        s = (i > 0) ? s.slice(1) : s;
        r += "[" + s + "]";
        break;

      case "integer":
      case "float":
      case "bool":
        r += val;
        break;

      case "null":
        r += "null";
        break;

      case "instance":

        if ("_serializeRaw" in val && typeof val._serializeRaw == "function") {

            // include value produced by _serializeRaw()
            r += val._serializeRaw().tostring();

        } else if ("_serialize" in val && typeof val._serialize == "function") {

          // serialize instances by calling _serialize method
          r += this._encode(val._serialize(), depth + 1);

        } else {

          s = "";

          try {

            // iterate through instances which implement _nexti meta-method
            foreach (k, v in val) {
              s += ",\"" + k + "\":" + this._encode(v, depth + 1);
            }

          } catch (e) {

            // iterate through instances w/o _nexti
            // serialize properties, but not functions
            foreach (k, v in val.getclass()) {
              if (typeof v != "function") {
                s += ",\"" + k + "\":" + this._encode(val[k], depth + 1);
              }
            }

          }

          s = s.len() > 0 ? s.slice(1) : s;
          r += "{" + s + "}";
        }

        break;

      case "blob":
        // This is a workaround for a known bug:
        // on device side Blob.tostring() returns null
        // (instaead of an empty string)
        r += "\"" + (val.len() ? this._escape(val.tostring()) : "") + "\"";
        break;

      // strings and all other
      default:
        r += "\"" + this._escape(val.tostring()) + "\"";
        break;
    }

    return r;
  }

  /**
   * Escape strings according to http://www.json.org/ spec
   * @param {string} str
   */
  function _escape(str) {
    local res = "";

    for (local i = 0; i < str.len(); i++) {

      local ch1 = (str[i] & 0xFF);

      if ((ch1 & 0x80) == 0x00) {
        // 7-bit Ascii

        ch1 = format("%c", ch1);

        if (ch1 == "\"") {
          res += "\\\"";
        } else if (ch1 == "\\") {
          res += "\\\\";
        } else if (ch1 == "/") {
          res += "\\/";
        } else if (ch1 == "\b") {
          res += "\\b";
        } else if (ch1 == "\f") {
          res += "\\f";
        } else if (ch1 == "\n") {
          res += "\\n";
        } else if (ch1 == "\r") {
          res += "\\r";
        } else if (ch1 == "\t") {
          res += "\\t";
        } else if (ch1 == "\0") {
          res += "\\u0000";
        } else {
          res += ch1;
        }

      } else {

        if ((ch1 & 0xE0) == 0xC0) {
          // 110xxxxx = 2-byte unicode
          local ch2 = (str[++i] & 0xFF);
          res += format("%c%c", ch1, ch2);
        } else if ((ch1 & 0xF0) == 0xE0) {
          // 1110xxxx = 3-byte unicode
          local ch2 = (str[++i] & 0xFF);
          local ch3 = (str[++i] & 0xFF);
          res += format("%c%c%c", ch1, ch2, ch3);
        } else if ((ch1 & 0xF8) == 0xF0) {
          // 11110xxx = 4 byte unicode
          local ch2 = (str[++i] & 0xFF);
          local ch3 = (str[++i] & 0xFF);
          local ch4 = (str[++i] & 0xFF);
          res += format("%c%c%c%c", ch1, ch2, ch3, ch4);
        }

      }
    }

    return res;
  }
}

class LPS25H {

    static version = [2,0,1];

    static MAX_MEAS_TIME_SECONDS = 0.5; // seconds; time to complete one-shot pressure conversion

    static REF_P_XL        = 0x08;
    static REF_P_L         = 0X09;
    static REF_P_H         = 0x0A;
    static WHO_AM_I        = 0x0F;
    static RES_CONF        = 0x10;
    static CTRL_REG1       = 0x20;
    static CTRL_REG2       = 0x21;
    static CTRL_REG3       = 0x22;
    static CTRL_REG4       = 0x23;
    static INT_CFG         = 0x24;
    static INT_SOURCE      = 0x25;
    static STATUS_REG      = 0x27;
    static PRESS_OUT_XL    = 0x28;
    static PRESS_OUT_L     = 0x29;
    static PRESS_OUT_H     = 0x2A;
    static TEMP_OUT_L      = 0x2B;
    static TEMP_OUT_H      = 0x2C;
    static FIFO_CTRL       = 0x2E;
    static FIFO_STATUS     = 0x2F;
    static THS_P_L         = 0x30;
    static THS_P_H         = 0x31;
    static RPDS_L          = 0x39;
    static RPDS_H          = 0x3A;

    static PRESSURE_SCALE = 4096.0;
    static REFERENCE_PRESSURE_SCALE = 16.0;
    static MAX_REFERENCE_PRESSURE = 65534;

    // interrupt bitfield
    static INT_HIGH_PRESSURE_ACTIVE = 0x01;
    static INT_LOW_PRESSURE_ACTIVE  = 0x02;
    static INT_ACTIVE               = 0x04;
    static INT_ACTIVELOW            = 0x08;
    static INT_OPENDRAIN            = 0x10;
    static INT_LATCH                = 0x20;
    static INT_LOW_PRESSURE         = 0x40;
    static INT_HIGH_PRESSURE        = 0x80;

    _i2c        = null;
    _addr       = null;

    // -------------------------------------------------------------------------
    constructor(i2c, addr = 0xB8) {
        _i2c = i2c;
        _addr = addr;
    }

    // -------------------------------------------------------------------------
    function getDeviceID() {
        return _readReg(WHO_AM_I, 1);
    }

    // -------------------------------------------------------------------------
    function enable(state) {
        local val = _readReg(CTRL_REG1, 1);
        if (val == null) {
            throw "I2C Error";
        } else {
            val = val[0];
        }
        if (state) {
            val = val | 0x80;
        } else {
            val = val & 0x7F;
        }
        _writeReg(CTRL_REG1, val);
    }

    // -------------------------------------------------------------------------
    function setDataRate(datarate) {
        local actualRate = 0.0;
        if (datarate <= 0) {
            datarate = 0x00;
        } else if (datarate <= 1) {
            actualRate = 1.0;
            datarate = 0x01;
        } else if (datarate <= 7) {
            actualRate = 7.0;
            datarate = 0x02;
        } else if (datarate <= 12.5) {
            actualRate = 12.5;
            datarate = 0x03;
        } else {
            actualRate = 25.0;
            datarate = 0x04;
        }
        local val = (_readReg(CTRL_REG1, 1)[0] & 0x8F);
        _writeReg(CTRL_REG1, (val | (datarate << 4)));
        return actualRate;
    }

    // -------------------------------------------------------------------------
    function getDataRate() {
        local val = (_readReg(CTRL_REG1, 1)[0] & 0x70) >> 4;
        if (val == 0) {
            return 0.0;
        } else if (val == 0x01) {
            return 1.0;
        } else if (val == 0x02) {
            return 7.0;
        } else if (val == 0x03) {
            return 12.5;
        } else {
            return 25.0;
        }
    }

    // -------------------------------------------------------------------------
    // Set the number of readings taken and internally averaged to give a pressure result
    // Selector field is 2 bits
    function setPressNpts(npts) {
        local actualNpts = 8;
        if (npts <= 8) {
            // Average 8 readings
            npts = 0x00;
        } else if (npts <= 32) {
            // Average 32 readings
            actualNpts = 32;
            npts = 0x01
        } else if (npts <= 128) {
            // Average 128 readings
            actualNpts = 128;
            npts = 0x02;
        } else {
            // Average 512 readings
            actualNpts = 512;
            npts = 0x03;
        }
        local val = _readReg(RES_CONF, 1)[0];
        local res = _writeReg(RES_CONF, (val & 0xFC) | npts);
        return actualNpts;
    }

    // -------------------------------------------------------------------------
    // Set the number of readings taken and internally averaged to give a temperature result
    // Selector field is 2 bits
    function setTempNpts(npts) {
        local actualNpts = 8;
        if (npts <= 8) {
            // Average 8 readings
            npts = 0x00;
        } else if (npts <= 16) {
            // Average 16 readings
            actualNpts = 16;
            npts = 0x01
        } else if (npts <= 32) {
            // Average 32 readings
            actualNpts = 32;
            npts = 0x02;
        } else {
            // Average 64 readings
            actualNpts = 64;
            npts = 0x03;
        }
        local val = _readReg(RES_CONF, 1)[0];
        local res = _writeReg(RES_CONF, (val & 0xF3) | (npts << 2));
        return actualNpts;
    }

    // ------------------------------------ena-------------------------------------
    function configureInterrupt(enable, threshold = null, options = 0) {

        // Datasheet recommends setting threshold before enabling/disabling int gen
        // set the threshold, if it was given ---------------------------------
        if (threshold != null) {
            threshold = threshold * 16;
            _writeReg(THS_P_H, (threshold & 0xFF00) >> 8);
            _writeReg(THS_P_L, threshold & 0xFF);
        }

        // check and set the options ------------------------------------------

        // interrupt pin active-high (active-low by default)
        local val = _readReg(CTRL_REG3, 1)[0];
        if (options & INT_ACTIVELOW) {
            val = val | 0x80;
        } else {
            val = val & 0x7F;
        }
        // interrupt pin push-pull (open drain by default)
        if (options & INT_OPENDRAIN) {
            val = val | 0x40;
        } else {
            val = val & 0xBF;
        }
        // pressure low and pressure high interrupts routed to pin
        if (enable) {
            val = val | 0x03;
        } else {
            val = val & 0xFA;
        }
        _writeReg(CTRL_REG3, val & 0xFF);

        // interrupt latched
        val = _readReg(INT_CFG, 1)[0] & 0xF8;
        if (options & INT_LATCH) {
            val = val | 0x04;
        }
        // interrupt on low differential pressure
        if (options & INT_LOW_PRESSURE) {
            val = val | 0x02;
        }
        // interrupt on high differential pressure
        if (options & INT_HIGH_PRESSURE) {
            val = val | 0x01;
        }
        _writeReg(INT_CFG, val & 0xFF);


        // set the enable -----------------------------------------------------
        val = _readReg(CTRL_REG1, 1)[0];
        if (enable) {
            val = val | 0x08;
        } else {
            val = val & 0xF7;
        }
        _writeReg(CTRL_REG1, val & 0xFF);
    }

    // -------------------------------------------------------------------------
    function getInterruptSrc() {
        local val = _readReg(INT_SOURCE, 1)[0];
        local intSrcTable = {"int_active": false, "high_pressure": false, "low_pressure": false};
        if (val & 0x04) { intSrcTable.int_active = true; }
        if (val & 0x02) { intSrcTable.low_pressure = true; }
        if (val & 0x01) { intSrcTable.high_pressure = true; }
        return intSrcTable;
    }

    // -------------------------------------------------------------------------
    function softReset() {
        _writeReg(CTRL_REG2, 0x84);
    }

    // -------------------------------------------------------------------------
    function getReferencePressure() {
        local low   = _readReg(RPDS_L, 1);
        local high  = _readReg(RPDS_H, 1);
        local val = ((high[0] << 8) | low[0]);
        if (val & 0x8000) { val = _twosComp(val, 0x7FFF); }
        return (val * 1.0) / REFERENCE_PRESSURE_SCALE;
    }

    // -------------------------------------------------------------------------
    function setReferencePressure(val) {
        val = (val * REFERENCE_PRESSURE_SCALE).tointeger();
        if (val < 0) { val = _twosComp(val, 0x7FFF); }
        // server.log(format("ref: 0x%04X", val));
        _writeReg(RPDS_H, (val & 0xFF00) >> 8);
        _writeReg(RPDS_L, (val & 0xFF));
    }

    // -------------------------------------------------------------------------
    function read(cb = null) {
        // try/catch so errors thrown by I2C methods can be handed to the callback
        // instead of just thrown again
        try {
            // if we're not in continuous-conversion mode
            local datarate = getDataRate();
            local meas_time = 0;
            if (datarate == 0) {
                // Start a one-shot measurement
                _writeReg(CTRL_REG2, 0x01);
                meas_time = MAX_MEAS_TIME_SECONDS;
            } else {
                meas_time = 1.0 / datarate;
            }

            // Get pressure in HPa
            if (cb == null) {
                local pressure = _getPressure() + getReferencePressure();
                return {"pressure": pressure};
            } else {
                imp.wakeup(meas_time, function() {
                    local pressure = _getPressure() + getReferencePressure();
                    cb({"pressure": pressure});
                }.bindenv(this));
            }
        } catch (err) {
            if (cb == null) {
                return {"error": err, "pressure": null};
            } else {
                imp.wakeup(0, function() {
                    cb({"error": err, "pressure": null})
                });
            }
        }
    }

    // -------------------------------------------------------------------------
    function getTemp() {
        local temp_l = _readReg(TEMP_OUT_L, 1)[0];
        local temp_h = _readReg(TEMP_OUT_H, 1)[0];

        local temp_raw = (temp_h << 8) | temp_l;
        if (temp_raw & 0x8000) {
            temp_raw = _twosComp(temp_raw, 0x7FFF);
        }
        return (42.5 + (temp_raw / 480.0));
    }

    // ------------------ PRIVATE METHODS -------------------------------------//

    // -------------------------------------------------------------------------
    function _twosComp(value, mask) {
        value = ~(value & mask) + 1;
        return -1 * (value & mask);
    }

    // -------------------------------------------------------------------------
    function _readReg(reg, numBytes) {
        local result = _i2c.read(_addr, reg.tochar(), numBytes);
        if (result == null) {
            throw "I2C read error: " + _i2c.readerror();
        }
        return result;
    }

    // -------------------------------------------------------------------------
    function _writeReg(reg, ...) {
        local s = reg.tochar();
        foreach (b in vargv) {
            s += b.tochar();
        }
        local result = _i2c.write(_addr, s);
        if (result) {
            throw "I2C write error: " + result;
        }
        return result;
    }

    // -------------------------------------------------------------------------
    // Returns raw pressure register values
    function _getPressure() {
        local low   = _readReg(PRESS_OUT_XL, 1);
        local mid   = _readReg(PRESS_OUT_L, 1);
        local high  = _readReg(PRESS_OUT_H, 1);
        local raw = ((high[0] << 16) | (mid[0] << 8) | low[0]);
        if (raw & 0x800000) { raw = _twosComp(raw, 0x7FFFFF); }
        return (raw * 1.0) / PRESSURE_SCALE;
    }
}

class Si702x {
	
    static version = [1, 0, 0];
    // Commands
    static RESET            = "\xFE";
    static MEASURE_RH       = "\xF5";
    static MEASURE_TEMP     = "\xF3";
    static READ_PREV_TEMP   = "\xE0";
    // Additional constants
    static RH_MULT      = 125.0/65536.0;    // ------------------------------------------------
    static RH_ADD       = -6;               // These values are used in the conversion equation
    static TEMP_MULT    = 175.72/65536.0;   // from the Si702x datasheet
    static TEMP_ADD     = -46.85;           // ------------------------------------------------
    static TIMEOUT_MS   = 100;

    _i2c  = null;
    _addr = null;

    // Constructor
    // Parameters:
    //      _i2c:     hardware i2c bus, must pre-configured
    //      _addr:    device address (optional)
    // Returns: (None)
    constructor(i2c, addr = 0x80)
    {
        _i2c  = i2c;
        _addr = addr;
    }

    // Resets the sensor to default settings
    function init() {
        _i2c.write(_addr, "", RESET);
    }

    // Polls the sensor for the result of a previously-initiated measurement
    // (gives up after TIMEOUT milliseconds)
    function _pollForResult(startTime, callback) {
        local result = _i2c.read(_addr, "", 2);
        if (result) {
            callback(result);
        } else if (hardware.millis() - startTime < TIMEOUT_MS) {
            imp.wakeup(0, function() {
                _pollForResult(startTime, callback);
            }.bindenv(this));
        } else {
            // Timeout
            callback(null);
        }
    }

    // Starts a relative humidity measurement
    function _readRH(callback=null) {
        _i2c.write(_addr, MEASURE_RH);
        local startTime = hardware.millis();
        if (callback == null) {
            local result = _i2c.read(_addr, "", 2);
            while (result == null && hardware.millis() - startTime < TIMEOUT_MS) {
                result = _i2c.read(_addr, "", 2);
            }
            return result;
        } else {
            _pollForResult(startTime, callback);
        }
    }

    // Reads and returns the temperature value from the previous humidity measurement
    function _readTempFromPrev() {
        local rawTemp = _i2c.read(_addr, READ_PREV_TEMP, 2);
        if (rawTemp) {
            return TEMP_MULT*((rawTemp[0] << 8) + rawTemp[1]) + TEMP_ADD;
        } else {
            server.log("Si702x i2c read error: " + _i2c.readerror());
            return null;
        }
    }

    // Initiates a relative humidity measurement,
    // then passes the humidity and temperature readings as a table to the user-supplied callback, if it exists
    // or returns them to the caller, if it doesn't
    function read(callback=null) {
        if (callback == null) {
            local rawHumidity = _readRH();
            local temp = _readTempFromPrev();
            if (rawHumidity == null || temp == null) {
                return {"err": "error reading temperature", "temperature": null, "humidity": null};
            }
            local humidity = RH_MULT*((rawHumidity[0] << 8) + rawHumidity[1]) + RH_ADD;
            return {"temperature": temp, "humidity": humidity};
        } else {
            // Measure and read the humidity first
            _readRH(function(rawHumidity) {
                // If it failed, return an error
                if (rawHumidity == null) {
                    callback({"err": "reading timed out", "temperature": null, "humidity": null});
                    return;
                }
                // Convert raw humidity value to relative humidity in percent, clamping the value to 0-100%
                local humidity = RH_MULT*((rawHumidity[0] << 8) + rawHumidity[1]) + RH_ADD;
                if (humidity < 0) { humidity = 0.0; }
                else if (humidity > 100) { humidity = 100.0; }
                // Read the temperature reading from the humidity measurement
                local temp = _readTempFromPrev();
                if (temp == null) {
                    callback({"err": "error reading temperature", "temperature": null, "humidity": null});
                    return;
                }
                // And pass it all to the user's callback
                callback({"temperature": temp, "humidity": humidity});
            }.bindenv(this));
        }
    }
}

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
        
        //Says to to agent, that device is ready to recieve messages
        imp.wakeup(0, @() agent.send(HANDSHAKE, hardware.getdeviceid()) );
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