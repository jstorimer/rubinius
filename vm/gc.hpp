#ifndef RBX_VM_GC_HPP
#define RBX_VM_GC_HPP

#include "vm/prelude.hpp"

namespace rubinius {

  class ObjectMemory;

  class GarbageCollector {
    public:

    ObjectMemory* object_memory;
    ObjectArray* weak_refs;

    virtual OBJECT saw_object(OBJECT) = 0;
    virtual ~GarbageCollector()  { }
    GarbageCollector(ObjectMemory *om);
    void scan_object(OBJECT obj);
    void delete_object(OBJECT obj);
  };

  class ObjectMark {
  public:
    GarbageCollector* gc;

    ObjectMark(GarbageCollector* gc);
    OBJECT call(OBJECT);
    void set(OBJECT target, OBJECT* pos, OBJECT val);
    void just_set(OBJECT target, OBJECT val);
  };
}

#endif
