#include <stdio.h>
#include <string.h>
#include <math.h>

enum { width = 640, height = 480 };

const int INTENSITY_CALIBRATION = 100;

/*
 * Checks if a ray originating at p0 and passing through p1 intersects with a sphere at any point
 * returns 1 if an intersection exists, 0 if no intersections exist.
 * px1 and px2 are the two points of intersection.
 * */
char ray_sphere_intersection(int sphere[4], int p0[3], int p1[3], int px1[3], int px2[3], char BOUNDED, char THRESHOLD) {
    // CLOCK CYCLE 1: purely combinational logic for initial exposure of ray... no division or sqrt
    long a = (p1[0] - p0[0]) * (p1[0] - p0[0]) + (p1[1] - p0[1]) * (p1[1] - p0[1]) + (p1[2] - p0[2]) * (p1[2] - p0[2]); // distance between points
    long b = 2 * (p1[0] - p0[0]) * ( p0[0] - sphere[0]) + 2 * (p1[1] - p0[1]) * ( p0[1] - sphere[1]) + 2 * (p1[2] - p0[2]) * ( p0[2] - sphere[2]);
    long c = ( p0[0] - sphere[0]) * ( p0[0] - sphere[0]) + ( p0[1] - sphere[1]) * ( p0[1] - sphere[1]) + ( p0[2] - sphere[2]) * ( p0[2] - sphere[2]) - sphere[3] * sphere[3];
    
    if(b * b >= 4 * a * c) {
        //CLOCK CYCLE 2: dual square root computation
        long T1 = (-b  + sqrt(b * b - 4 * a * c)) - a/10; // these are 2a times the actual value we need to plug in. A only depends on the focal length though....
        long T2 = (-b  - sqrt(b * b - 4 * a * c)) - a/10;
        
        // CLOCK CYCLE 3
        if(T1 < THRESHOLD && T2 < THRESHOLD)
            return 0;
        if(a == 0)
            return 0;
        if(BOUNDED && (T1 > 2 * a) && (T2 > 2 * a))
            return 0; // collisions which are outside of the range 0 - 1 = t don't count if bounded
        
        px1[0] = (T1 * p1[0] + (2 * a - T1) * p0[0]) / (2 * a);
        px1[1] = (T1 * p1[1] + (2 * a - T1) * p0[1]) / (2 * a);
        px1[2] = (T1 * p1[2] + (2 * a - T1) * p0[2]) / (2 * a);
        
        px2[0] = (T2 * p1[0] + (2 * a - T2) * p0[0]) / (2 * a);
        px2[1] = (T2 * p1[1] + (2 * a - T2) * p0[1]) / (2 * a);
        px2[2] = (T2 * p1[2] + (2 * a - T2) * p0[2]) / (2 * a);
        
        return 1; // there exists some point of collision
    } else
        return 0;
}

int raytracer(void) {
	char ENABLE_OUTPUT = 1;
	static unsigned char pixels[width * height * 3];
	static unsigned char tga[18];
	unsigned char *p;

    /* DO NOT SET f > 10k at the risk of overflowing*/
	int f = 1000; // smaller FOV means you can see more, but there will be more distortion
	int camera[3] = {320, 240, 0};
	// X, Y, Z, Radius
	int sphere[4] = {0, 240, f + 201, 100};

	// X, Y, Z, Intensity... for a point source
	int light[4] = {220, 0, f + 201, 200000}; // light from the camera

	int x, y;

	const int resolution = 1; // used for debugging

	p = pixels;
	for (y = 0; y < height; y+=resolution) {
		for (x = 0; x < width; x+=resolution) {
			unsigned char R, G, B; // Set RGB

			int ix1[3], ix2[3], ix3[3];
			int screen_pixel[3] = {x, y, f};

			char intersect_sphere = ray_sphere_intersection(sphere, camera, screen_pixel, ix1, ix2, 0, 0); // ix2 is closer than ix1

			if(intersect_sphere){
                // check for intersection between the collision point and the light source
                intersect_sphere = ray_sphere_intersection(sphere, ix2, light, ix1, ix3, 1, 10);
                
                if(intersect_sphere) {
                    R = 50;
                    G = 50;
                    B = 0;
                } else {
                    long distance2 = (light[0] - ix2[0]) * (light[0] - ix2[0]) + (light[1] - ix2[1]) * (light[1] - ix2[1]) + (light[2] - ix2[2]) * (light[2] - ix2[2]); // distance to light source
                    
                    int intensity = (INTENSITY_CALIBRATION * light[3])/(distance2);
                    intensity = intensity > 255 ? 255 : intensity;
                    R = intensity > 50 ? intensity : 50;
                    G = intensity > 50 ? intensity : 50;
                    B = 0;
                }
			}
			else {
				R = 0;
				G = 0;
				B = 0; // no sphere should be black
			}

			*p++ = B;
			*p++ = G;
			*p++ = R;
		}
	}
	tga[2] = 2;
	tga[12] = 255 & width;
	tga[13] = 255 & (width >> 8);
	tga[14] = 255 & height;
	tga[15] = 255 & (height >> 8);
	tga[16] = 24;
	tga[17] = 32;
	if(ENABLE_OUTPUT)
		return !((1 == fwrite(tga, sizeof(tga), 1, stdout)) &&  (1 == fwrite(pixels, sizeof(pixels), 1, stdout)));
	else
		return 0;
}


int main(void) {
    return raytracer();
}
