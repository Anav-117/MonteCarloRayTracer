#pragma once

#ifndef MATERIAL_H
#define MATERIAL_H

#include "Utils.cuh"
#include "Vec3.cuh"
#include "Ray.cuh"
#include "hittable.cuh"
#include <stdio.h>

//struct hit_record; 

struct material {
    int material;// = "lambertian";
    color albedo;// = color(0, 0, 0);
    double fuzz;
    double ir;
};

//class material {
//public: 
//	HOD virtual bool scatter (const ray& r_in, const hit_record& rec, color& attenuation, ray& scattered) const = 0;
//};
//
//class lambertian : public material {
//public:
//    lambertian(const color& a) : albedo(a) {}
//
//    HOD virtual bool scatter(const ray& r_in, const hit_record& rec, color& attenuation, ray& scattered) const override {
//        return true;
//        auto scatter_direction = rec.normal + random_unit_vector();
//
//        // Catch degenerate scatter direction
//        if (scatter_direction.near_zero())
//            scatter_direction = rec.normal;
//
//        scattered = ray(rec.p, scatter_direction);
//        attenuation = albedo;
//        return true;
//    }
//
//public:
//    color albedo;
//};
//
//class metal : public material {
//public:
//    metal(const color& a) : albedo(a) {}
//
//    HOD virtual bool scatter(const ray& r_in, const hit_record& rec, color& attenuation, ray& scattered) const override {
//        printf("IN METAL\n");
//        return true;
//        vec3 reflected = reflect(unit_vector(r_in.direction()), rec.normal);
//        scattered = ray(rec.p, reflected);
//        attenuation = albedo;
//        return (dot(scattered.direction(), rec.normal) > 0);
//    }
//
//public:
//    color albedo;
//};

#endif