#pragma once

#include <cstring>
#include <cstdlib>
#include <inttypes.h>

#define FWI_MEM_VAL(type, ptr, offset) *(type *)(ptr + offset)

#define FWI_SET_BIT(expression, bit) (expression |= (1 << bit))
#define FWI_UNSET_BIT(expression, bit) (expression &= ~(1 << bit))
#define FWI_SET_BIT_TO(expression, bit, val) (expression ^= (-(val ? 1 : 0) ^ expression) & (1 << bit))
#define FWI_IS_BIT_SET(expression, bit) ((expression & (1 << bit)) != 0)

namespace FWI {
    struct Block {
        virtual ~Block() {};

        virtual void allocate(bool zero = true) {
            if (zero)   _store = (char *)::calloc(SIZE, 1);
            else        _store = (char *)::malloc(SIZE);
            _update_ptr();
        }
        virtual void free() {
            ::free(_store);
        }
        virtual void map_to(char *memory) {
            _store = memory;
            _update_ptr();
        }
        virtual int copy_to(char *memory) {
            ::memcpy(memory, _store, SIZE);
            return SIZE;
        }
        char *get_store() {
            return _store;
        }
        virtual void _update_ptr() {};

        static const int SIZE = 0;
    protected:
        char *_store;
    };
}