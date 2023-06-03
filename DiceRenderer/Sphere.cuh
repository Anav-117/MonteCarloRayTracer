#pragma once

#ifndef SPHERE_H
#define SPHERE_H

#include "Hittable.cuh"
#include "Vec3.cuh"
#include "Material.cuh"

struct material;

class sphere {
public:
    HOD sphere() {}
    HOD sphere(point3 cen, double r, material m) : center(cen), radius(r), M(m) {};

    HOD bool hit(const ray& r, double t_min, double t_max, hit_record& rec) const;

public:
    point3 center;
    double radius;
    material M;
};

HOD bool sphere::hit(const ray& r, double t_min, double t_max, hit_record& rec) const {
    vec3 oc = r.origin() - center;
    auto a = r.direction().length_squared();
    auto half_b = dot(oc, r.direction());
    auto c = oc.length_squared() - radius * radius;

    auto discriminant = half_b * half_b - a * c;
    if (discriminant < 0) {
        //printf("Fail 1\n");
        return false;
    }
    auto sqrtd = sqrt(discriminant);

    // Find the nearest root that lies in the acceptable range.
    auto root = (-half_b - sqrtd) / a;
    if (root < t_min || t_max < root) {
        root = (-half_b + sqrtd) / a;
        if (root < t_min || t_max < root)
            //printf("Fail 2\n");
            return false;
    }

    rec.t = root;
    rec.p = r.at(rec.t);
    rec.normal = (rec.p - center) / radius;
    vec3 outward_normal = (rec.p - center) / radius;
    rec.set_face_normal(r, outward_normal);
    rec.Mat = M;

    //printf("Pass 1\n");
    return true;
}

#endif