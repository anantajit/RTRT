#include <stdio.h>
#include <string.h>
#include <math.h>

enum { width = 640, height = 480 };

/*
 * Checks if a ray originating at p0 and passing through p1 intersects with a sphere at any point
 * */
char ray_sphere_intersection(int sphere[4], int p0[3], int p1[3], int px1[3], int px2[3]) {
	/*A and C are swapped from standard quadratic!*/
	long a = (p0[0] - sphere[0]) * (p0[0] - sphere[0]) + (p0[1] - sphere[1]) * (p0[1] - sphere[1]) + (p0[2] - sphere[2]) * (p0[2] - sphere[2]) - sphere[3] * sphere[3]; // a is constant per scene
	long c = (p1[0] - sphere[0]) * (p1[0] - sphere[0]) + (p1[1] - sphere[1]) * (p1[1] - sphere[1]) + (p1[2] - sphere[2]) * (p1[2] - sphere[2]);
	long b = (p1[0] - p0[0]) * (p1[0] - p0[0]) + (p1[1] - p0[1]) * (p1[1] - p0[1]) + (p1[2] - p0[2]) * (p1[2] - p0[2]) - a - c - sphere[3] * sphere[3]; // we require 64 bits
	// CLK CYCLE 1
	char intersect_sphere = b * b > 4 * a * c;
	long t1, t2;
	if(intersect_sphere){
		t1 = (-b - sqrt(b * b - 4 * a * c)); // tc value
		t2 = (-b + sqrt(b * b - 4 * a * c)); // tc value
	}
	// CLK CYCLE 2
	// These values are the intersection point IF the intersection occurs... otherwise they are nonsense values
	if(c != 0) {
		px1[0] = (p0[0] * (c - t1) + (t1 * p1[0])) / c;
		px1[1] = (p0[1] * (c - t1) + (t1 * p1[1])) / c;
		px1[2] = (p0[2] * (c - t1) + (t1 * p1[2])) / c;
		
        px2[0] = (p0[0] * (c - t2) + (t2 * p1[0])) / c; // division by c was removed from the calculation of t
        px2[1] = (p0[1] * (c - t2) + (t2 * p1[1])) / c;
        px2[2] = (p0[2] * (c - t2) + (t2 * p1[2])) / c;
        

		if(t1 < 0 && t2 < 0) // if we are either behind the ray or very close to the start point, we don't count this as a collision
			intersect_sphere = 0; // collision behind doesn't count
	} else {
		intersect_sphere = 0; // infinite t value... or very large
	}

	return intersect_sphere;
}	

int main(void) {
	char ENABLE_OUTPUT = 1;
	static unsigned char pixels[width * height * 3];
	static unsigned char tga[18];
	unsigned char *p;

	int f = 500;
	int camera[3] = {320, 240, 0};
	// X, Y, Z, Radius
	int sphere[4] = {0, 0, f + 100, 200};

	// X, Y, Z, Intensity... for a point source
	int light[4] = {320, 100, f + 100, 1000000};

	int x, y;

	const int resolution = 1;

	p = pixels;
	for (y = 0; y < height; y+=resolution) {
		for (x = 0; x < width; x+=resolution) {
			unsigned char R, G, B; // Set RGB

			int ix1[3], ix2[3], ix3[3];
			int screen_pixel[3] = {x, y, f};

			char intersect_sphere = ray_sphere_intersection(sphere, camera, screen_pixel, ix1, ix2);

			if(intersect_sphere){
                R = 200;
                G = R;
                B = 0;
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
