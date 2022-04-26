#include <stdio.h>
#include <string.h>
#include <time.h>
#include <math.h>

enum { width = 640, height = 480 };

int main(void) {
	static unsigned char pixels[width * height * 3];
	static unsigned char tga[18];
	unsigned char *p;

    int f = 50;
    int camera[3] = {320, 240, 0};
	// X, Y, Z, Radius
    int sphere[4] = {320, 200, f + 100, 100};

    int light[3] = {300, 100, f}; // right above sphere, closer to camera
    long intensity = 1000000;
    
	int x, y;

	p = pixels;
    
    clock_t start, end;
    double cpu_time_used;

    start = clock();
	for (y = 0; y < height; y++) {
        for (x = 0; x < width; x++) {
			unsigned char R, G, B; // Set RGB
            
            /*A and C are swapped from standard quadratic!*/
            long a = (camera[0] - sphere[0]) * (camera[0] - sphere[0]) + (camera[1] - sphere[1]) * (camera[1] - sphere[1]) + (camera[2] - sphere[2]) * (camera[2] - sphere[2]) - sphere[3] * sphere[3]; // a is constant per scene
            long c = (x - sphere[0]) * (x - sphere[0]) + (y - sphere[1]) * (y - sphere[1]) + (f - sphere[2]) * (f - sphere[2]);
            long b = (x - camera[0]) * (x - camera[0]) + (y - camera[1]) * (y - camera[1]) + (f - camera[2]) * (f - camera[2]) - a - c - sphere[3] * sphere[3]; // we require 64 bits
            
            // CLK CYCLE 1
            
            char intersect_sphere = b * b > 4 * a * c;
            long t;
            if(intersect_sphere){
                t = (-b - sqrt(b * b - 4 * a * c))/c; // t value
            }
            
            // CLK CYCLE 2
            
            long cx, cy, cz; // positions of collision on sphere surface
            cx = camera[0] * (1 - t) + t * x;
            cy = camera[1] * (1 - t) + t * y;
            cz = camera[2] * (1 - t) + t * f;
            
            
            a = (cx - sphere[0]) * (cx - sphere[0]) + (cy - sphere[1]) * (cy - sphere[1]) + (cz - sphere[2]) * (cz - sphere[2]) - sphere[3] * sphere[3]; // a is constant per scene
            c = (light[0] - sphere[0]) * (light[0] - sphere[0]) + (light[1] - sphere[1]) * (light[1] - sphere[1]) + (light[2] - sphere[2]) * (light[2] - sphere[2]);
            b = (light[0] - cx) * (light[0] - cx) + (light[1] - cy) * (light[1] - cy) + (light[2] - cz) * (light[2] - cz) - a - c - sphere[3] * sphere[3]; // we require 64 bits
            
            int epsilon = 1;
            
            int exposed_light;
            exposed_light = 10;
            
            if(b * b > 4 * a * c){ // there is a collision
                t = (-b - sqrt(b * b - 4 * a * c)); // t*c value
                long source_distance = (light[0] - cx) * (light[0] - cx) + (light[1] - cy) * (light[1] - cy) + (light[2] - cz) * (light[2] - cz);
                if(t > epsilon) { // some epsilon value... if the collision is caused NOT by the first bounce point
                    exposed_light = intensity/source_distance; // no collision should be bright
                }
            }
            else
                exposed_light = 10;
            
            if(exposed_light < 10)
                exposed_light = 10;
            if(exposed_light > 255)
                exposed_light = 255;
            
            if(intersect_sphere){
                R = exposed_light;
                G = R; // draw the realized circle in white
//                B = R;
//                printf("INTERSECT: (%d, %d) -> %d\n", x, y, b * b - 4 * a * c);
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
    
    end = clock();
    
    cpu_time_used = ((double) (end - start)) / CLOCKS_PER_SEC;
    
    printf("%0.2f FPS\n", 1/cpu_time_used, CLOCKS_PER_SEC); //in seconds
    
	tga[2] = 2;
	tga[12] = 255 & width;
	tga[13] = 255 & (width >> 8);
	tga[14] = 255 & height;
	tga[15] = 255 & (height >> 8);
	tga[16] = 24;
	tga[17] = 32;
	return 0;
//	return !((1 == fwrite(tga, sizeof(tga), 1, stdout)) &&  (1 == fwrite(pixels, sizeof(pixels), 1, stdout)));
}
