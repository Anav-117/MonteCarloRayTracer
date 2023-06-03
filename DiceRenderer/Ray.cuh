#pragma once

#ifndef RAY_H
#define RAY_H

#include "Defines.cuh"
#include "Utils.cuh"
#include "Vec3.cuh"

class ray {
public:
	HOD ray() {}
	HOD ray(const point3& origin, const vec3& direction) : orig(origin), dir(direction) {}

	HOD point3 origin() const { return orig; }
	HOD vec3 direction() const { return dir; }

	HOD point3 at(double t) const {
		return orig + dir * t;
	}

public:
	point3 orig;
	vec3 dir;
};

#endif