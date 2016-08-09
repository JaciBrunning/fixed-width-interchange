exports = ->
    return module.exports if typeof module isnt 'undefined' and typeof module.exports isnt 'undefined'
    return window.FWI if typeof window isnt 'undefined'
    return FWI if typeof FWI isnt 'undefined'

window.FWI = {} if typeof window isnt 'undefined'

IEEE754toBytes = (v, bytes, offset, double_precise) ->
    e_width = 8
    m_width = 23

    if double_precise
        e_width = 11
        m_width = 52

    bias = (1 << (e_width - 1)) - 1
    sign; exp; mant

    if isNaN(v)
        exp = (1 << bias) - 1
        mant = 1
        sign = 0
    else if v is Infinity or v is -Infinity
        exp = (1 << bias) - 1
        mant = 0
        sign = if v < 0 then 1 else 0
    else if v is 0
        exp = 0
        mant = 0
        sign = 0
    else
        sign = if v < 0 then 1 else 0
        v = -v if v < 0

        if v >= 2**(1 - bias)
            ln = Math.min(Math.log(v) // Math.LN2, bias)
            exp = ln + bias
            mant = Math.floor(v * 2**(m_width - ln) - 2**(m_width))
        else
            exp = 0
            mant = Math.floor(v / 2**(1 - bias - m_width))

    bytes[offset + n] = 0 for n in [0...(if double_precise then 8 else 4)]

    if double_precise
        bytes[offset + 7] = (1 << 7) if sign is 1

        bytes[offset + 7] |= (exp >> 4)
        bytes[offset + 6] |= (exp & 0xf) << 4

        mant_1 = mant | 0                       # Bottom 32 Bits
        mant_1 += 4294967296 if (mant_1 < 0)
        mant_2 = mant - mant_1                  # Top 20 Bits
        mant_2 /= 4294967296
        
        bytes[offset + 6] |= (mant_2 >> 16) & 0xf
        bytes[offset + 5] |= (mant_2 >> 8) & 0xff
        bytes[offset + 4] |= (mant_2) & 0xff
        bytes[offset + 3] |= (mant_1 >> 24) & 0xff
        bytes[offset + 2] |= (mant_1 >> 16) & 0xff
        bytes[offset + 1] |= (mant_1 >> 8) & 0xff
        bytes[offset] |= mant_1 & 0xff
    else
        bytes[offset + 3] = (1 << 7) if sign is 1

        bytes[offset + 3] |= (exp >> 1)
        bytes[offset + 2] |= (exp & 1) << 7

        bytes[offset + 2] |= (mant >> 16) & 0x7f
        bytes[offset + 1] |= (mant >> 8) & 0xff
        bytes[offset] |= mant & 0xff
    undefined


bytesToIEEE754 = (bytes, offset, double_precise) ->
    a = bytes[offset]
    b = bytes[offset + 1]
    c = bytes[offset + 2]
    d = bytes[offset + 3]
    e; f; g; h

    if double_precise
        e = bytes[offset + 4]
        f = bytes[offset + 5]
        g = bytes[offset + 6]
        h = bytes[offset + 7]

    man_bits = a | b << 8 | c << 16
    man_bits_2 = 0

    sign = 1
    exp_bits = 0
    exp = 1
    m_base = 0
    expoff = 127
    expoff = 1023 if double_precise

    if double_precise
        exp_bits = (g | h << 8)
        sign = if (h & (1 << 7)) != 0 then -1 else 1
        exp = ( exp_bits >> 4 & 0x7ff ) - expoff
        man_bits_2 = d | e << 8 | f << 16 | g << 24
        m_base = 52
    else
        exp_bits = (c | d << 8)
        sign = if (d & (1 << 7)) != 0 then -1 else 1
        exp = ( exp_bits >> 7 & 0xff ) - expoff
        m_base = 23

    mant = 1.0

    if exp is -127
        mant = 0.0
        exp = -126

    for n in [1..m_base]
        i = 2**(-n)
        byt = m_base - n
        push = false
        if byt >= 24
            push = (man_bits_2 & (1 << byt - 24)) != 0
        else
            push = (man_bits & (1 << byt)) != 0

        mant += i if push

    return sign * Infinity if exp is 128 and mant is 1.0
    return NaN if exp is 128 and mant > 1
    return 0 if exp + expoff is 0 and mant == 1.0
    sign * 2**exp * mant

toFloat = (bytes, offset) => bytesToIEEE754(bytes, offset, false)
toDouble = (bytes, offset) => bytesToIEEE754(bytes, offset, true)
fromFloat = (bytes, offset, value) => IEEE754toBytes(value, bytes, offset, false)
fromDouble = (bytes, offset, value) => IEEE754toBytes(value, bytes, offset, true)

FWI = {}
FWI.util = {}

FWI.util.exports = exports

FWI.util.extend = (child, parent) ->
    for key of parent
        child[key] = parent[key] if {}.hasOwnProperty.call(parent, key)
    ctor = ->
        this.constructor = child
        this
    ctor.prototype = parent.prototype
    child.prototype = new ctor
    child.__super__ = parent.prototype
    child

FWI.create_block_type = (name, size) ->
    placeholder = {}
    placeholder[name] = () ->
        placeholder[name].__super__.constructor.call(this, size)
    
    FWI.util.extend(placeholder[name], FWI.Block)

    placeholder[name]

class FWI.ByteBuffer
    constructor: ->
        @bytes = null
        @length = 0
    
    allocate: (size) ->
        @bytes = []
        @length = size
        @bytes[num] = 0 for num in [0...@length]
        undefined
    
    map_to_string: (string) ->
        for num in [0...@length]
            cc = string.charCodeAt(num)
            cc = 0 if cc == NaN
            @bytes[num] = cc

    free: ->
        @bytes = null
        @length = 0
        undefined

class FWI.Block
    constructor: (size) ->
        @size = size
        @buf = null
        @children = {}
        @off = 0
    
    update_children: ->
        for child_i of @children
            child = @children[child_i]
            bindex = Number(child_i) + @off
            child.map_to(@buf, bindex)
        undefined

    allocate: ->
        @buf = new FWI.ByteBuffer
        @buf.allocate(@size)
        @off = 0
        this.update_children()
        undefined

    from_string: (string) ->
        @buf.map_to_string(string)
        undefined

    map_to: (buffer, offset) ->
        @buf = buffer
        @off = offset
        this.update_children()
        undefined
    
    get_bytes: ->
        tmpbuf = []
        tmpbuf[i] = @buf.bytes[@off + i] for i in [0...@size]
        tmpbuf
    
    free: ->
        @buf = null
        @off = 0
        undefined
    
    get_child: (type, index) ->
        bindex = index + @off
        if @children[index]?
            return @children[index]
        else
            child = new type
            child.map_to(@buf, bindex)
            @children[index] = child
            return child

    set_bool: (byte, bit, value) ->
        byte += @off
        (@buf.bytes[byte] ^= (-(if value then 1 else 0) ^ @buf.bytes[byte]) & (1 << bit))
        undefined

    get_bool: (byte, bit) ->
        (@buf.bytes[byte + @off] & (1 << bit)) != 0;

    set_u8: (byte, val) ->
        @buf.bytes[byte + @off] = val & 0xff
        undefined
    
    get_u8: (byte) ->
        @buf.bytes[byte + @off]

    set_i8: (byte, val) ->
        @buf.bytes[byte + @off] = val & 0xff
        undefined

    get_i8: (byte) ->
        byt = @buf.bytes[byte + @off]
        byt -= 256 if byt > 127
        byt
    
    set_u16: (index, val) ->
        val &= 0xffff
        bindex = index + @off
        @buf.bytes[bindex + 1] = (val >> 8) & 0xff
        @buf.bytes[bindex] = val & 0xff
        undefined

    get_u16: (index) ->
        bindex = index + @off
        @buf.bytes[bindex] | (@buf.bytes[bindex + 1] << 8)

    set_i16: (index, val) ->
        val &= 0xffff
        bindex = index + @off
        @buf.bytes[bindex + 1] = (val >> 8) & 0xff
        @buf.bytes[bindex] = val & 0xff
        undefined
    
    get_i16: (index) ->
        bindex = index + @off
        u16_val = @buf.bytes[bindex] | (@buf.bytes[bindex + 1] << 8)
        u16_val -= 65536 if u16_val > 32767
        u16_val
    
    set_u32: (index, val) ->
        val &=0xffffffff
        bindex = index + @off
        @buf.bytes[bindex + 3] = (val >> 24) & 0xff
        @buf.bytes[bindex + 2] = (val >> 16) & 0xff
        @buf.bytes[bindex + 1] = (val >> 8) & 0xff
        @buf.bytes[bindex] = val & 0xff
        undefined
    
    get_u32: (index) ->
        bindex = index + @off
        @buf.bytes[bindex] | (@buf.bytes[bindex + 1] << 8) | (@buf.bytes[bindex + 2] << 16) | (@buf.bytes[bindex + 3] << 24)

    set_i32: (index, val) ->
        val &=0xffffffff
        bindex = index + @off
        @buf.bytes[bindex + 3] = (val >> 24) & 0xff
        @buf.bytes[bindex + 2] = (val >> 16) & 0xff
        @buf.bytes[bindex + 1] = (val >> 8) & 0xff
        @buf.bytes[bindex] = val & 0xff
        undefined

    get_i32: (index) ->
        bindex = index + @off
        u32_val = @buf.bytes[bindex] | (@buf.bytes[bindex + 1] << 8) | (@buf.bytes[bindex + 2] << 16) | (@buf.bytes[bindex + 3] << 24)
        u32_val -= 4294967296 if u32_val > 2147483647
        u32_val

    # JavaScript doesn't support 64 bit wide integers, so we'll just limit it to 32 bit.
    set_u64: (index, val) => @set_u32(index, val)
    get_u64: (index) => @get_u32(index)
    set_i64: (index, val) => @set_i32(index, val)
    get_i64: (index) => @get_i32(index)

    set_string: (index, val, length) ->
        @buf.bytes[@off + index + i] = val.charCodeAt(i) for i in [0...Math.min(val.length, length)]
        @buf.bytes[@off + index + val.length + i] = 0 for i in [0...(length - val.length)] if val.length < length
        undefined

    get_string: (index, length) ->
        res = ""
        res += String.fromCharCode(@buf.bytes[@off + index + i]) for i in [0...length]
        res

    get_float32: (index) ->
        toFloat(@buf.bytes, index + @off)

    get_float64: (index) ->
        toDouble(@buf.bytes, index + @off)

    set_float32: (index, value) ->
        fromFloat(@buf.bytes, index + @off, value)

    set_float64: (index, value) ->
        fromDouble(@buf.bytes, index + @off, value)

exports().ByteBuffer = FWI.ByteBuffer
exports().Block = FWI.Block
exports().util = FWI.util
exports().block = FWI.create_block_type