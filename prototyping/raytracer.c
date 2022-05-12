#include <stdio.h>
#include <string.h>
#include <math.h>
#include <time.h>

enum { width = 640, height = 480 };

const int INTENSITY_CALIBRATION = 75;
const int DEROUNDER = 25;
const int ATTENUATION_CUTOFF = 25;
const char ENABLE_OUTPUT = 1;

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
        long T1 = (-b  + ((int) sqrt(b * b - 4 * a * c))) - a/DEROUNDER; // these are 2a times the actual value we need to plug in. A only depends on the focal length though....
        long T2 = (-b  - ((int) sqrt(b * b - 4 * a * c))) - a/DEROUNDER;
        
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
	static unsigned char pixels[width * height * 3];
	static unsigned char tga[18];
	unsigned char *p;

    /* DO NOT SET f > 10k at the risk of overflowing*/
   
    /*
     SCENE INFORMATION
     */
    
    
	int f = 300; // smaller FOV means you can see more, but there will be more distortion
	int camera[3] = {320, 240, 0};
    
    int color_idx[2][3] = {{1, 0, 0}, {0, 1, 0}};
    
	// X, Y, Z, Radius
    const char SPHERE_COUNT = 2;
    int sphere_array[SPHERE_COUNT][4] = {{200, 240, f + 100, 100}, {260, 100, f + 200, 50}};
	// X, Y, Z, Intensity... for a point source
    const char LIGHT_COUNT = 2;
    int light_array[LIGHT_COUNT][4] = {{50, 50, f + 200, 150000}, {0, 350, f + 100, 50000}}; // light from the camera
    
    
    /* END OF SCENE INFORMATION...*/
    
    
	int x, y;

	const int resolution = 1; // used for debugging

    p = pixels;
    clock_t t;
    t = clock();
    for (y = 0; y < height; y+=resolution) {
		for (x = 0; x < width; x+=resolution) {
			unsigned char R = 0, G = 0, B = 0; // Set RGB

			int ix1[3], strike_pt[3], ix3[3];
			int screen_pixel[3] = {x, y, f};
            
            char colors[3][3] = {{1, 0, 0}, {0, 1, 0}, {0, 0, 1}};
            
            char color[3];

            char intersect_sphere = 0;
            
            // Does the pixel hit ANY sphere at all?
            for(int sphere_idx = 0; sphere_idx < SPHERE_COUNT; sphere_idx++){
                int sphere[4];
                sphere[0] = sphere_array[sphere_idx][0];
                sphere[1] = sphere_array[sphere_idx][1];
                sphere[2] = sphere_array[sphere_idx][2];
                sphere[3] = sphere_array[sphere_idx][3];
                if (ray_sphere_intersection(sphere, camera, screen_pixel, ix1, strike_pt, 0, 0) && intersect_sphere == 0){
                    intersect_sphere = 1;
                    color[0] = colors[sphere_idx][0];
                    color[1] = colors[sphere_idx][1];
                    color[2] = colors[sphere_idx][2];
                }
            }
            

			if(intersect_sphere){
                // check for intersection between the collision point and the light source

                for(int light_idx = 0; light_idx < LIGHT_COUNT; light_idx++){
                    
                    int light[4];
                    light[0] = light_array[light_idx][0];
                    light[1] = light_array[light_idx][1];
                    light[2] = light_array[light_idx][2];
                    light[3] = light_array[light_idx][3];
                    
                    // Does ANY sphere block it?
                    intersect_sphere = 0;
                    
                    for(int sphere_idx = 0; sphere_idx < SPHERE_COUNT; sphere_idx++){
                        int sphere[4];
                        sphere[0] = sphere_array[sphere_idx][0];
                        sphere[1] = sphere_array[sphere_idx][1];
                        sphere[2] = sphere_array[sphere_idx][2];
                        sphere[3] = sphere_array[sphere_idx][3];
                        
                        intersect_sphere += ray_sphere_intersection(sphere, strike_pt, light, ix1, ix3, 1, 10); // ix2 is closer than ix1
                    }
                    
                    
                    if(intersect_sphere) {
                        R += 0;
                        G += 0;
                        B += 0;
                    } else {
                        long distance2 = (light[0] - strike_pt[0]) * (light[0] - strike_pt[0]) + (light[1] - strike_pt[1]) * (light[1] - strike_pt[1]) + (light[2] - strike_pt[2]) * (light[2] - strike_pt[2]); // distance to light source
                        
                        int intensity = (INTENSITY_CALIBRATION * light[3])/(distance2); // how much light to add
                        
                        if(intensity * color[0] + R > 255)
                            R = 255;
                        else
                            R += intensity * color[0];
                        if(intensity * color[1] + G > 255)
                            G = 255;
                        else
                            G += intensity * color[1];
                        if(intensity * color[2] + B > 255)
                            B = 255;
                        else
                            B += intensity * color[2];
                    }
                }
                
                B = B > ATTENUATION_CUTOFF ? B : ATTENUATION_CUTOFF;
                G = G > ATTENUATION_CUTOFF ? G : ATTENUATION_CUTOFF;
                R = R > ATTENUATION_CUTOFF ? R : ATTENUATION_CUTOFF;
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
    t = clock() - t;
    double time_taken = ((double)t)/CLOCKS_PER_SEC; // in seconds
    
    
	tga[2] = 2;
	tga[12] = 255 & width;
	tga[13] = 255 & (width >> 8);
	tga[14] = 255 & height;
	tga[15] = 255 & (height >> 8);
	tga[16] = 24;
	tga[17] = 32;
	if(ENABLE_OUTPUT)
		return !((1 == fwrite(tga, sizeof(tga), 1, stdout)) &&  (1 == fwrite(pixels, sizeof(pixels), 1, stdout)));
    else{
        printf("This scene could render at up to %f FPS!\n", 1/time_taken);
        return 0;
    }
        
}


int main(void) {
    return raytracer();
}
