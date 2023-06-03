#include "cuda_runtime.h"
#include "device_launch_parameters.h"
#include "Defines.cuh"
#include "Utils.cuh"
#include "Vec3.cuh"
#include "Ray.cuh"
#include "Color.cuh"
#include "Sphere.cuh"
#include "Hittable.cuh"
#include "Camera.cuh"
#include "Material.cuh"

#include <iostream>
#include <fstream>
#include <stdio.h>
#include <curand.h>
#include <curand_kernel.h>

DEV bool lambertian_scatter(const ray& r_in, const hit_record& rec, color& attenuation, ray& scattered, color albedo, vec3 random) {
    auto scatter_direction = rec.normal + random;
    
    // Catch degenerate scatter direction
    if (scatter_direction.near_zero())
        scatter_direction = rec.normal;
    
    scattered = ray(rec.p, scatter_direction);
    attenuation = albedo;
    return true;
}

DEV bool metal_scatter(const ray& r_in, const hit_record& rec, color& attenuation, ray& scattered, color albedo, double fuzz, vec3 random) {
    vec3 reflected = reflect(unit_vector(r_in.direction()), rec.normal);
    scattered = ray(rec.p, reflected + fuzz * random);
    attenuation = albedo;
    return (dot(scattered.direction(), rec.normal) > 0);
}

DEV bool dielectric_scatter(const ray& r_in, const hit_record& rec, color& attenuation, ray& scattered, double ir, double random) {
    attenuation = color(1.0, 1.0, 1.0);
    double refraction_ratio = rec.front_face ? (1.0 / ir) : ir;

    vec3 unit_direction = unit_vector(r_in.direction());
    double cos_theta = fmin(dot(-unit_direction, rec.normal), 1.0);
    double sin_theta = sqrt(1.0 - cos_theta * cos_theta);

    bool cannot_refract = refraction_ratio * sin_theta > 1.0;
    vec3 direction;

    if (cannot_refract || reflectance(cos_theta, refraction_ratio) > random)
        direction = reflect(unit_direction, rec.normal);
    else
        direction = refract(unit_direction, rec.normal, refraction_ratio);

    scattered = ray(rec.p, direction);
    return true;
}

__global__ void ray_color(vec3* KRNG_Diffuse, ray* r, camera* cam, color* Image, sphere* world, int samples_per_pixel, int image_width, int image_height, int world_size, int max_depth) {

    int j = blockIdx.x * blockDim.x + threadIdx.x;

    hit_record rec;

    ray R = r[j];

    int num_hits = 0;
    color FinalColor = color(0, 0, 0);
    color FinalAttenuation = color(0,0,0);

    int depth = max_depth;
    //printf("Here1\n");

    while (depth > 0) {

        hit_record temp_rec;
        bool hit_anything = false;
        double tmax = infinity;
        double tmin = 0.001;
        double closest_so_far = tmax;

        for (int i = 0; i < world_size; i++) {
            if (world[i].hit(R, tmin, closest_so_far, temp_rec)) {
                hit_anything = true;
                closest_so_far = temp_rec.t;
                rec = temp_rec;
            }
        }

        if (hit_anything) {
            num_hits++;
            ray scattered;
            color attenuation;
            if (rec.Mat.material == 0) {
                if (lambertian_scatter(R, rec, attenuation, scattered, rec.Mat.albedo, KRNG_Diffuse[j * max_depth + (depth-1)])) {
                    if (FinalAttenuation == color(0, 0, 0)) {
                        FinalAttenuation = attenuation;
                    }
                    else {
                        FinalAttenuation = FinalAttenuation * attenuation;
                    }
                }
            }
            else if (rec.Mat.material == 1) {
                if (metal_scatter(R, rec, attenuation, scattered, rec.Mat.albedo, rec.Mat.fuzz, KRNG_Diffuse[j * max_depth + (depth - 1)])) {
                    if (FinalAttenuation == color(0, 0, 0)) {
                        FinalAttenuation = attenuation;
                    }
                    else {
                        FinalAttenuation = FinalAttenuation * attenuation;
                    }
                }
            }
            else if (rec.Mat.material == 2) {
                if (dielectric_scatter(R, rec, attenuation, scattered, rec.Mat.ir, KRNG_Diffuse[j * max_depth + (depth - 1)].x())) {
                    if (FinalAttenuation == color(0, 0, 0)) {
                        FinalAttenuation = attenuation;
                    }
                    else {
                        FinalAttenuation = FinalAttenuation * attenuation;
                    }
                }
            }
            R = scattered;
            depth--;
        }
        else {
            vec3 unit_direction = unit_vector(R.direction());
            auto t = 0.5 * (unit_direction.y() + 1.0);
            FinalColor = (1.0 - t) * color(1.0, 1.0, 1.0) + t * color(0.5, 0.7, 1.0);
            break;
        }

    }

    if (!(FinalAttenuation == color(0, 0, 0))) {
        FinalColor = FinalColor * FinalAttenuation;
    }

    Image[j] = FinalColor;

    //printf("Completed Pixel - %d\n", j);

}

int main() {
	// Image
	const auto aspect_ratio = 16.0 / 9.0;
	const int image_width = 400;
    const int image_height = static_cast<int>(image_width / aspect_ratio);
    const int samples_per_pixel = 500;
    const int max_depth = 50;

    // Image File

    std::ofstream ImageFile;
    ImageFile.open("Image.ppm");

    // World
    int world_size = 4;

    sphere* world = new sphere[world_size];

    material ground_material = { 0, color(0.5, 0.5, 0.5), 0, 0 }; //lambertian
    world[0] = sphere(point3(0, -1000, 0), 1000, ground_material);

    material material1 = { 2, color(0,0,0), 0, 1.5 };
    world[1] = sphere(point3(0, 1, 0), -1.0, material1);

    material material2 = { 0, color(0.4, 0.2, 0.1), 0, 0 };
    world[2] = sphere(point3(-1, 1, 0), 1.0, material2);

    material material3 = { 1, color(0.7, 0.6, 0.5), 0.0, 0 };
    world[3] = sphere(point3(1, 1, 0), 1.0, material3);
    
    // Camera

    point3 lookfrom(-5, 5, 1);
    point3 lookat(0, 1, 0);
    vec3 vup(0, 1, 0);
    auto dist_to_focus = (lookfrom - lookat).length();
    auto aperture = 0.3;

    camera cam(lookfrom, lookat, vup, 50, aspect_ratio, aperture, dist_to_focus);

    // Generate Rays

    ImageFile << "P3\n" << image_width << " " << image_height << "\n255\n";

    for (int j = image_height - 1; j >= 0; --j) {
        std::cout << "\rScanlines remaining: " << j << ' ' << std::flush;
        for (int i = 0; i < image_width; ++i) {
            ray* Ray_Mat = new ray[samples_per_pixel];
            color* Image = new color[samples_per_pixel];

            for (int s = 0; s < samples_per_pixel; ++s) {
                auto u = (i + random_double()) / (image_width - 1);
                auto v = (j + random_double()) / (image_height - 1);

                ray R = cam.get_ray(u, v);

                Ray_Mat[s] = R;

                Image[s] = color(0.0, 0.0, 0.0);
            }

            vec3* RNG_Diffuse = new vec3[samples_per_pixel * max_depth];
            for (int i = 0; i < samples_per_pixel * max_depth; i++) {
                RNG_Diffuse[i] = random_in_unit_sphere();
            }

            color PixelColor = color(0, 0, 0);

            ray* KRay_Mat = NULL;
            color* KImage = NULL;
            sphere* KWorld = NULL;
            camera* KCam = NULL;
            vec3* KRNG_Diffuse = NULL;
            cudaMalloc(&KRNG_Diffuse, samples_per_pixel * max_depth * sizeof(vec3));
            cudaMalloc(&KRay_Mat, samples_per_pixel * sizeof(ray));
            cudaMalloc(&KImage, samples_per_pixel * sizeof(color));
            cudaMalloc(&KWorld, world_size * sizeof(sphere));
            cudaMalloc(&KCam, sizeof(camera));
            cudaMemcpy(KRNG_Diffuse, RNG_Diffuse, samples_per_pixel * max_depth * sizeof(vec3), cudaMemcpyHostToDevice);
            cudaMemcpy(KRay_Mat, Ray_Mat, samples_per_pixel * sizeof(ray), cudaMemcpyHostToDevice);
            cudaMemcpy(KImage, Image, samples_per_pixel * sizeof(color), cudaMemcpyHostToDevice);
            cudaMemcpy(KWorld, world, world_size * sizeof(sphere), cudaMemcpyHostToDevice);
            cudaMemcpy(KCam, &cam, sizeof(camera), cudaMemcpyHostToDevice);

            ray_color <<<1, samples_per_pixel>>> (KRNG_Diffuse, KRay_Mat, KCam, KImage, KWorld, samples_per_pixel, image_width, image_height, world_size, max_depth);
            cudaDeviceSynchronize();

            cudaMemcpy(Image, KImage, samples_per_pixel * sizeof(color), cudaMemcpyDeviceToHost);

            //HandleCudaKernelError(cudaGetLastError());

            for (int s = 0; s < samples_per_pixel; ++s) {
                PixelColor += Image[s];
            }

            write_color(ImageFile, PixelColor, samples_per_pixel);

            delete[] Ray_Mat;
            delete[] Image;
            delete[] RNG_Diffuse;

            cudaFree(KRay_Mat);
            cudaFree(KImage);
            cudaFree(KWorld);
            cudaFree(KCam);
            cudaFree(KRNG_Diffuse);
        }
    }

    ImageFile.close();

	return 0;
}