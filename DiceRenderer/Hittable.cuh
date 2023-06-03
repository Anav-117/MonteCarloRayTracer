#pragma once

#ifndef HITTABLE_H
#define HITTABLE_H

#include "Defines.cuh"
#include "Ray.cuh"
#include <stdio.h>
#include "Utils.cuh"
#include "Material.cuh"

struct hit_record {
    point3 p;
    vec3 normal;
    material Mat;
    double t;
    bool front_face;

    HOD inline void set_face_normal(const ray& r, const vec3& outward_normal) {
        front_face = dot(r.direction(), outward_normal) < 0;
        normal = front_face ? outward_normal : -outward_normal;
    }
};

class hittable {
public:
    HOD virtual bool hit(const ray& r, double t_min, double t_max, hit_record& rec) const { 
        return false; 
    };
};

#endif