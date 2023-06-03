#ifndef HITTABLE_LIST_H
#define HITTABLE_LIST_H

#include "Hittable.cuh"
#include <stdio.h>

class hittable_list : public hittable {
public:
    HOD hittable_list() {}
    //HOD hittable_list(shared_ptr<hittable> object) { add(object); }

    //HOD void clear() { objects.clear(); }
    //HOD void add(shared_ptr<hittable> object) { objects.push_back(object); }

    HOD virtual bool hit(const ray& r, double t_min, double t_max, hit_record& rec) const override;

public:
    hittable* objects;
};

HOD bool hittable_list::hit(const ray& r, double t_min, double t_max, hit_record& rec) const {
    hit_record temp_rec;
    bool hit_anything = false;
    auto closest_so_far = t_max;

    int size = sizeof(this) / sizeof(hittable);

    for (int i = 0; i < size; ++i) {
        if (this[i].hit(r, t_min, closest_so_far, temp_rec)) {
            hit_anything = true;
            closest_so_far = temp_rec.t;
            rec = temp_rec;
        }
    }

    return hit_anything;
}

#endif