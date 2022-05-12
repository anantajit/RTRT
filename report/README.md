# Real Time Ray Tracing

**Anantajit Subrahmanya**

## Introduction
The purpose of this project was to create hardware capable of rendering a 3D scene in real-time using a ray tracing method. Since the project was meant to be hardware-heavy, the additional requirement was that the image should be generated purely in hardware; that is, synthesizing any soft-core CPU or running any software for the final result was strictly prohibited. Upon rendering a frame, the result would be drawn in color onto a 640 x 480 monitor through a VGA interface.

### Feature Overview
The final version of this project was able to render scenes with a single sphere object and single light source in a variety of configurations. The sphere and light source could be positioned anywhere in the scene, as long as they were in-front of the camera. The radius of the sphere and illumination intensity of the light source are also tunable parameters, as was the Field of View (FOV) of the camera. Furthermore, the frame rate of the raytracer was variable, meaning that black regions are rendered fast (improving the framerate of the animation).

Spheres were rendered with appropriate light exposure and shading consistent with the laws of physics. The only exception to this rule was the areas of the sphere which were not illuminated by light. To make sure these areas were still visible, these areas were shaded with a dull grey color.

### Ray Tracing 
![[image.png]]Ray Ray tracing is a method of simulating light to render out realistic scenes. The above example is a simple application of ray-tracing in Python. 

![[traditional_model.svg]]

Traditional models of light have light source emitting photons. The photons bounce of objects in the scene, with varying levels of absorption, until some of the photons enter the camera. Depending on earlier collisions, photons arriving at the camera may carry different wavelengths. For instance, if a series of photons collide with a blue object, photons corresponding to a "blue" wavelength would be absorbed while other photons would arrive at the eye. The issue with implementing this model is that many of the collisions are computationally expensive but add nothing to the scene. These are the photons which do not arrive at the camera. 

![[traditional_model.svg]]

An alternate model is to treat the eye as an emission point. The camera sends out a series of "absorption photons", one from each pixel. These photons collide with various objects in the scene. At each point of collision, the exposure to light for the photon is checked. If there is direct line of sight to a light source, it is highly likely that a photon from that light source would follow the same path as the emitted absorption photon. These absorption photons can bounce, just like regular photons, and these bounces are potential paths that the light could have taken from the sources. 

How are each of the absorption paths computed? We model the camera itself as a pyramid-like structure. The source point is called the "camera," while the plane is the "virtual screen." Note that the virtual screen in this implementation matched the resolution of the final image, but this does not necessarily have to always be the case. In this implementation, each absorption photon collided with a pixel on this "virtual screen," and continued its path in a straight line as described above. This means that for a 640 x 480 screen, a total of 307,200 absorption photons are simulated per frame, which is computationally taxing on the FPGA. By adjusting the distance between the camera and the screen, the FOV of the camera can be adjusted. A large FOV can capture more elements in the scene, but exhibits significant "distortion". On the other hand, there is little distortion for a small FOV, but the resulting image captures a very small portion of the scene. 

![[Screen Shot 2022-05-11 at 23.04.35.png]]

This was a single bounce implementation of ray-tracing. This means that the light source emits photons and the photons only bounce one time before they "decay" and are no longer simulated. In the absorption photon implementation for this project, the absorption photons only can bounce once before colliding with a light source. This means that the point of collision with the object in the scene is required. 

See that in the high level diagram above, a single photon has been emitted and has collided with the sphere in the scene. The path between the photon collision point and the light source is then computed. If this path is obstructed, then this point is "shadowed" by other objects. Note that this includes collision with itself! On the other hand, if the path is unobstructed, then the intensity of light depends on the distance between the absorption point and the point source. Light follows an inverse-square law, which means that the intensity of light grows weaker at a rate proportional to the distance squared. This means that we need to compute the distance between the light source and the absorption point, and square it. Note that for this simulation we do not compute the intensity attenuation between the camera and object in the scenes.

## Technical Description 
### High-Level Design
This is the top-most module in RTL view. Any further inspection into smaller modules becomes a convoluted mess, due to the high datawidth of each value. This is especially true in ray_sphere_intersection. As it is, the block diagram is a better representation. 
![[RTL1.PNG]]
![[RTL2.PNG]]
![[RTL3.PNG]]
The output mode of this device was a VGA monitor. The built-in controller for VGA supports up to 640 x 480 at 60 frames per second. Thus, a new pixel is sent to the monitor at a rate of 25MHz. However, the mathematics behind raytracing are computationally expensive, and photon simulation cannot be processed with such speed. A frame buffer is therefore necessary. 

![[block_diagram.png]]

For this design, On Chip Memory (OCM) was used as the frame buffer. The frame buffer allocated a total of 4 bits for each pixel for a full-greyscale image, but in future revisions this design is capable of extension to 12 bits per pixel (full color). Despite the relatively-low bit count per pixel, there was barely enough memory to store a single frame. This meant that dual-ported memory was not an option, as dual port RAM could potentially need to double memory locations which are being written to simultaneously. Furthermore, opting for single port memory allows for a second pair of ports to be used for transfer between On Chip Memory and SDRAM future revisions of the project. 

Modules were used to poll OCM and read a pixel value at 25MHz. For this project, a 100MHz clock was used. This speed was achieved by feeding the interal oscillator through a Phase Locked Loop on the board. See that there are 4 clock cycles per pixel. Once of these clock cycles was used for reading from OCM to transmit through the VGA interface. Another clock cycle was used by a ray tracing module to compute the value of a pixel on the screen. This module is explained in later sections of the report. The remaining two clock cycles are reserved for additional parallelism. In revisions of this project, ray tracing logic would be able to compute many pixels in parallel, making use of the FPGA's parallel computing power. This would increase the frame rate significantly. 

A RTCore is a ray tracing module. Given an X, Y coordinate, this module uses hundreds of clock cycles to simulate the path of light through the scene and computes the color of the pixel. See that in the time that a single pixel is computed by the RTcore, many pixels would have been written to the screen. The robust memory controlling logic for this project ensured that the variable speed of operation of the RTcore was functional. 

### Algorithms 
One issue with conventional ray tracing algorithms is that they work using floating point operations. These arise from the multiplications, divisions and magnitude calculations that are used. However, the MAX10 FPGA provided to us does not have dedicated floating point hardware, meaning that floating point computations would be very expensive. The workaround for this project was to use fixed point, and rederive the algorithms necessary to make it functional. 

#### Ray-Sphere Collision Algorithm
<!-- ray-sphere intersection diagram with labels -->
One integral piece of the raytracer is the ability to compute collisions between the rays and spheres in the scene. The rays were expressed with an initial point and slope, while spheres are described with position and radius. 

It became useful to express rays in point-slope form, where the slope was rational. This is because lacking floating point, computing the slope immediately can result in a loss of precision. 

$$y = y_0 + \frac{p}{q} (x - x_0) $$
The sphere's equation was expressed with the equation:
$$(x - x_s)^2 + (y - y_s)^2 + (z - z_s)^2 = R^2$$
The equations were then parameterized. This was useful as it resulted in relatively simple quadratics for which the number of intersection points could be quickly determined. 

$$ x(t) = x_1 t + (1 - t)x_0 $$
$$ y(t) = y_1 t + (1 - t)y_0 $$
$$ z(t) = z_1 t + (1 - t)z_0 $$

Performing our substitution, we will find the following expressions 
$$ \implies (x_1 t + (1 - t)x_0 - x_s)^2 + (y_1 t + (1 - t)y_0 - y_s)^2 + (z_1 t + (1 - t)z_0 - z_s)^2 = R^2 $$

If we expand this out, then we get the following quadratic equation: 
$$ a t^2 + bt + c = 0 $$ where 
$$a = (x_1 - x_0)^2 + (y_1 - y_0)^2 + (z_1 - z_0)^2$$
$$ b = 2 (x_1 - x_0)(x_0 - s_x) + 2 (y_1 - y_0)(y_0 - s_y) + 2 (z_1 - z_0)(z_0 - s_z)$$
$$ c = (x_0 - s_x)^2 + (y_0 - s_y)^2 + (z_0 - s_z)^2 - R^2 $$
We can then check if there is a collision, i.e if there is a valid solution to this equation. To do this, we check if $b^2 - 4ac >= 0$. 

If it is less than zero, then we can return that there is no collision. If it is greater than or equal to zero, then we use the quadratic formula to solve for parameters. 

$$ t = \frac{-b \pm \sqrt{b^2 - 4 a c}}{2a} $$
Note that the case where $t$ has one solution is highly unlikely, and in any case we don't actually care about the number of solutions for this application. 

If $t < 0$, this means that the ray intersection is "behind" the starting point. This is because our equation actually solves for a line-sphere intersection. Thus, any negative solutions for $t$ are ignored, and not registered as a valid collision. 

If $t > 1$, then this means that our collision is beyond $(x_1, y_1, z_1)$. This isn't always a problem, but there may be cases where we want to bound our collision points for whatever reason. 

This does bring up another issue though. We want many of our t values to be relatively small, or even between 0 and 1, but in this project we want to use fixed point notation. To achieve this result, we can spare the division for a later stage. 

$$ T = -b \pm \sqrt{b^2 - 4ac}$$
Now, we are checking if $T > 2a$ for bounding checks. 

Once we have everything put together, we can compute the actual intersection points. Note that there will be two values of $T$ that are computed, but their treatment is the same. 

$$x(T) = x_1 T + (1-T) x_0 = \boxed{\frac{T x_1 + (2a - T)x_0}{2a}}$$
$$ y(T) = \boxed{\frac{T y_1 + (2a - T)y_0}{2a}}$$
$$ z(T) = \boxed{\frac{T z_1 + (2a - T)z_0}{2a}}$$

We also may want to add a feature where our initial point of our ray actually starts on the sphere. *Theoretically*, this would register as a collision, because there would be a point on the ray which does intersect with the sphere, even if we may not care about that particular intersection. 

<!-- Threshold diagram -->

To solve this, we insert a lower bound. This is achieved by including a THRESHOLD variable, which we can call $\tau$ for now. We will check if $T > \tau$ instead of performing a comparison of $T > 0$ to check the validity of the ray-sphere intersection. This way, points which are very close to the source of the ray will be ignored. 

#### Pixel Processing Algorithm

The scene itself contains many parameters. For the most basic version of the raytracer, we require a sphere with position and radius as parameters, a light source with position and intensity as parameters, and a FOV variable $f$. 

<!-- Raytracing diagram, at a high level -->

The behavior is exactly the same for each pixel. Suppose we have pixels X and Y on the screen. For simplicity, our ray-source (camera) is centered with the screen at (320, 240, 0). We then set the end point of the ray to be on the screen. In this case, the coordinate would be $(X, Y, f)$. These are used as our $p_1$ and $p_2$ arguments for the ray-sphere intersect algorithm. 

If intersection does occur, then we continue with our algorithm. If there is no intersection, then we return the color "black" and move on. 

In multi-object versions of this algorithm, we would typically loop through multiple spheres to see if **any** of them intersect with the ray. If multiple intersections exist, then we use the closest intersection point. 

<!-- two intersection case -->

Of course, there may be two intersection points. We only care about the "first" intersection. Thanks to the parameterization, we actually find the intersection points in order! In this case, we would use the computation $T = \frac{-b - \sqrt{b^2 - 4ac}}{1}$ because it will yield a smaller T value. 

Let's say that in this particular case, intersection does occur. How do we know if the point on the sphere is shadowed or not? 

<!-- Shadow diagram -->

If the sphere is under a shadow, then there will be a sphere that is blocking it. We once again compute the ray sphere intersection, but this time use $p_1$ as the point of intersection on the sphere (the smallest T value) and the light source for $p_2$. We will supply our same sphere arguments, but this time we will add a threshold and request only bounded collisions be counted. 

If there is a collision, then the pixel is under a shadow. This means there is no direct exposure to light, but there is a sphere present at this pixel. In our implementation, we chose a very dark grey to represent this. 

If there isn't a collision, then we need to use the inverse square law. Light attenuates at a rate proportional to the distance squared, so the intensity at any given point is modeled as 

$$ I = \frac{I_{\text{calibration}} \times I_{\text{light source}}}{d^2} $$
We can easily compute the Euclidean distance between the source and the intersection point. In fact, distance squared happens to be easier than computing the distance due to removing the square root operator. 

Once we get the intensity, we will check if it exceeds any maximal values. In the VGA monitor, the "brightness" of any given pixel is only given 4 bits. If our intensity exceeds 255, then we will set it to be 255 to avoid artifacts due to overflow. On the other hand, if the intensity is darker than the shadowed region, we will set the brightness to whatever that lower bound may be. Finally, if the brightness is in-between, then we will set it to whatever the value of I is. One issue with this method is that significant calibration is required. Since light cannot diffuse with this design, we see that it is difficult to get tangible results without changing the calibration parameter. Further research is required. 

![[Screen Shot 2022-05-11 at 18.36.15.png]] *An example of an intensity calibration value that is too high. See that there are no gradients near the sources, and the colors are washed out.*
![[Screen Shot 2022-05-11 at 18.37.15.png]] *Same scene, but with an intensity value which is way too low. Notice that everything is colored in the shadow color!*
#### Sizing and Bit Widths
How many bits do we need for each of these computations? From experimentation above, we saw that focal lengths exceeding $f = 1000$ are required to get any reasonable looking images without distortion. To store $f$ alone, we require 10 bits, which we will round to 16 bits. Let us assume that any point within our scene can be stored with 16 bits, as anything more would be excessive, and may not even appear on the screen. 

We have differences of points, which will be 16 bits, but we also square these differences. To store these squares, we will need at least 32 bits, and if many of these squares are multiplied and added together, we should have around 64 bits just to be safe. This allows us to make our scene really hit the limits of the 16 bits (unsigned), and ensures that we could potentially have an even larger focal length if we really wanted. These multiplications and additions are required *just* to compute the values of a, b, and c for the above equations.

We then have a $b^2$ and a $4ac$. These together drive us to 128 bits. This is actually an upper-bound, but allows us flexibility to trust that bugs that appear aren't due to overflow. 

It may have been a better idea to just keep values under 64 bits, but these issues are shown in later sections. 

### Framebuffer Design 
It is important to realize that the algorithms above are relatively expensive. Even running the clock at 100MHz, computing these pixel values without a frame buffer would require each computation to be done in 4 clock cycles. Given the high complexity of the algorithms, especially using features such as the square root and division operator, this is not possible. 

The alternate approach would be to compute the individual pixel values at a slower rate, but to buffer each frame in memory. Buffering each frame in memory requires the storage of 640 x 480 pixels. 

$$ \frac{200 * 10^3 * 8}{640 * 480} = 5.2 \text{ bits per pixel}$$
We will thus be using 4 bits in on-chip memory per pixel. Even while only using greyscale values to store color, this design still uses around 75% of the memory available on the MAX10 FPGA. Thus, dual porting is risky as it could potentially increase the memory footprint to the point that the design may not fit (in certain configurations) on the FPGA. For this design, we were restricted to a single port RAM design. 

Another requirement was that the reading and writing from memory should only take a single clock cycle. While the number of LUTs on the board ultimately ended up constraining the design, this design would have allowed for processing certain pixels in parallel. 

The issue was that the built-in megafunction restricts our implementations to including input registers. This increases the latency of our read and write operations, which we cannot afford if we want to maximize the frame rate of our system. 

![[286441490789129172.jpg]]The following timing diagram shows the issue with registered inputs. See that it is important that the write enable is switched from low to high AFTER the data and write address have been set. However, the default behavior of the FPGA's M2K IP ensures that these are set at the same time, on the rising clock edge. If the data is then modified one clock cycle later, the behavior of the memory block is indeterminate. That is to say, adding registers leads to the behavior becomming undefined for our FPGA. Pipelining is not the desired effect. 

Instead, the approach is to infer RAM in a carefully crafted method. We need the write enable to be FORCED to synthesize as a wire; the other data, write address and data can be set to any (wire, register) as long as timing is followed. Thus, single_port_ocm was a module which was created for this very purpose. The module infers memory by treating a register block as a single-clock-cycle access, and quartus is able to infer this while explicitly keeping the wire input valid. 

An added benefit of this speed is that in theory, three writes can take place in the same time as a single read. This means that with sufficient pipelining, memory would no longer be the bottleneck. The single ported nature of this memory means that when SDRAM is eventually added to the system, we will have two ports which can be used purely for moving data from the OCM to SDRAM and back. That is, extension to dual-ported memory is not difficult. 

### Renderer and RTCore Interaction
The Renderer is a module that exclusively reads from the memory (framebuffer), while the RTCore exclusively writes to it. Recall that both of these modules share the same single-port memory, which means that we need some sort of protocol. To achieve this, we have the OCM state machine, which is a four state machine that resets at the beginning of every pixel clock's falling edge. Achieving this synchronization was difficult because a synchronizer was required (the desire was for the design to function without pressing the RESET manually). 

The OCM state machine is rather simple in design. 
![[OCM_state_machine.svg]]

The OCM state machine has one read state and three write states. Extension of the write states is trivial, however for fitting the design onto the FPGA parallelism was disabled because of running out of LUTs. 

So, in the final version of the state machine, the breakdown is as follows:
| State | Blocked Actions |
| --- | --- |
| 00 | Initiate read into OCM | 
| 01 | Get data from OCM output port (read data), initiate write) | 
| 10 | Do nothing (for now) |
| 11 | Do nothing (for now) | 

Thus, the state machine only uses the first read state and the first write state. The remaining two states are left unused, effectively cutting the frame rate by a factor of three. Given additional time, it may have been possible to increase the frame rate by freeing up LUTs, but given that a single RTcore uses 40k LUTs, this would have been considerably difficult for little return. 

Note that the RTCore only writes to memory when ready! This means that our design works for arbitrarily slow operation of the RTCore; the FPS is thus **dynamic**, and the rendering is able to function as fast as our RTCore is able to operate on each pixel! 

### Renderer
The renderer is not a module on its own, but contains elements within RTRT. The renderer component includes a VGA controller module, which handles the control signals for the VGA interface. In addition to the VGA signals, the controller also generates DrawX and DrawY signals. These correspond to the X and Y position of the pixel currently being drawn. 

The OCM module was carefully designed to ensure that each "virtual address" corresponds to a 4 bit value. Thus, the position in memory of a given pixel can be found with 
$$ DrawX + 640 * DrawY $$
This was read within a single clock cycle, and in the second state of the OCM state machine this data is read. The data is then written to the outputs of RTRT, which are pin mapped to a VGA controlling chip on the DE-10 lite. Depending on the configuration, these may be written to VGA_R, VGA_G, or VGA_B (or some combination of the three). 

### RTCore Setup
The RTCore (singular, in this case) is a module which given an X,Y position on the screen, computes the color for that pixel. While the complexity of the scene and the activity at any given pixel is what determines the time that the RTcore takes to compute a single pixel, the worst case estimate of the RTcore's performance is around 7000 clock cycles (0.05FPS). Many of these clock cycles are safety measures, the current design could likely function with around 0.7 FPS, a significant speedup. Note that this is the **worst case** scenario, and most scenes should take significantly less time to render. For instance, a sphere that only covers 3% of the screen (approximately 141 pixels in diameter) would be rendered at 5FPS in the optimized design, and 0.7FPS in the current design (assuming a single light source). 

Within RTRT module, two variables RTX and RTY store the XY position of the pixel that is currently being drawn. Each time the RTcore is finished rendering a particular pixel, the RTX and RTY values are updated to reflect the new values. There is no "proper" way to choose the next RTX and RTY values. This implementation simply increments RTX and RTY, constraining them to the screen of course. This visually appears like a wipe across the screen, updating the pixels as it goes along. 

However, the other approach would be to update every nth value, and fill in the values in-between. The benefit of such an approach would be a more natural looking animation for the viewer, where they see an approximate (but incorrect) image initially, but the image becomes more accurate with time. This may have been a better approach, but would have been much harder to debug. 

### RTCore Function
The RTCore really only has two inputs: an X position and Y position. For now, the RTCore has been combined with a scene manager, so the entire scene is stored within the RTCore. However, it may have been better to store the scene in memory and simply fetch it with the RTCore. The implementation for this would have been much more complex though, so for now the RTCore uses registers instead. 

In addition to the inputs above, which are each 10 bit numbers, an ENABLE input is also given. This allows the RTRT top level module to control the RTCore, and update the X-Y values in a controlled manner. There is also an input for switches which is temporarily used to manipulate the scene (in the future, an ISA should probably be used). 

Due to the complex nature of this state machine, we will use a table to handle the states instead of a state diagram. 

| State | Functions | 
| --- | --- |
| 0 | Reset State |
| 1 | Initiate: if outgoing ray collides with object | 
| 3 | Wait until collision is stable | 
| 4 | Read result of collision. If collision does not occur, then set pixel to black | 
| 5 | If collision occurs, then initiate check if the collision point is obstructed | 
| 7 | Wait until the check is stable |
 | 9 | If obstructed, draw in dark grey, Otherwise, compute the distance between the collision point and the light source | 
 | 41 | The distance computation will be stable at this state. Divide the light intensity by the distance squared | 
 | 105 | The division computation will be stable. Set the pixel to correspond to the intensity, and flag the computation as complete | 

The RTCore begins in the reset state. It remains in this state until the ready signal is set to high. This does a couple of things. First, it copies the X, Y values into local registers. This is necessary to shield the RTcore from whatever non-sense is occuring outside in RTRT. If RTRT wishes to enable the RTCore's operation and immediately change the X and Y values, this is ok. This also enables parallelism, as the RTCores could each be working with their individual XY values. 

Upon enabling, the RTCore also sets its output to LOW, signaling that it is working on something at the current moment. This output will remain LOW until the output is stable. Finally, there is some additional temporary logic here to handle animation. At the beginning of each frame, the scene objects are modified in their position. Once again, storing the scene elsewhere would move this logic. 

Once these values are initialized and copied, the RTcore uses the ray_sphere_intersect module to check if the ray formed from the camera to the pixel on the virtual screen collides with the sphere in the scene. This takes a long time (in the debug version, around 3500 clock cycles worst case). While the ray-sphere intersect is working, the RTCore enters a wait state where is sits until the ray-sphere-intersect module is done with its computation. It then transitions into the next state. 

Once it reaches the next state, there will be a single one bit value which says if the ray collided with a sphere or not. If no collision occured, then the behavior is simple. The pixel is drawn as black, and the state machine returns to the reset state. The ready flag is set to high, and the computation is complete. 

In the case that collision DOES occur, things are not so simple. The system will then use the point at which the ray intersected with the sphere. It will then draw a ray from that point to the light source (there is currently only one) and check if that ray intersects any objects. Note that this is a bounded ray, that is only intersections between the two points are included. 

Once again, this could take another 3500 clock cycles. This means that our state machine enters yet another wait state. It will remain in this wait state until the computation completes. Then, it will see the one bit result returned by the intersection to see if it is obstructed or not. 

If the object was obstructed, then the behavior is simple. The area will be shaded with a dark grey, so the sphere is still visible. See that the RTCore doesn't actually care about color, since the light is seen as a monochrome source. It is the renderer that actually interprets the colors in the scene, and draws the appropriate result. 

If the object is unobstructed though, we enter a miserable divider and multiplier stage of the RTCore. This is arguably the least refined component, as we have still not figured out how to create variable clock cycle multiplication yet. To compute the distance between the light source and the point on the sphere, "slow multipliers" are used. This is because in theory, these values could be up to 64 bits in size, and such a multiply won't satisfy timing on this FPGA. The hard multiplication blocks in-fact only work with 9 bits! This means that the result will take multiple clocks to compute. An excessive 32 cycles are given just to ensure timing is followed, but it is likely that we could satisfy timing with only 9 clock cycles or less. 

Once this result is stable, the distance squared divides the intensity of the light source. To show that this is being done on the FPGA, the intensity is given as an input to the switches. This division is also quite expensive, as the intensity is a very large number. The calibration value is hardcoded to produce results that look somewhat nice in most cases, but often the light source blows certain values out of proportion while making others seem nearly dark. This is an issue which requires further experimentation. In my c-based work below, see that there is no shading on the green ball because the magnitude of the light intensity is so high that it just blows up all the screen pixel values to saturation. 
![[Screen Shot 2022-05-11 at 18.47.38.png]]
Finally, after around 64 clock cycles for this division, the output is stable. We then return to the reset state, updating the pixel value output with the results of the quotient and setting the ready flag to HIGH. 

### Ray-Sphere Intersection
The heart of this entire project is the 3500 state ray-sphere-intersection module. This is also the source of the slow-down, and the most computationally expensive megaoperation in the entire project. 

The inputs to this are numerous. As with the RTCore, we have an ENABLE and CLK input, to drive our logic. We also have the sphere which we wish to check for intersection, two points defining a ray that we wish to check intersection, and a bounded flag. There is also a THRESHOLD variable, which is explained later. 

We also have many "slow operators" within this machine. Slow operators compute multiplication, division, square root and square. These take anywhere from 32 clock cycles to 64 clock cycles to compute, EACH. Note that the biggest slowdown reason is because we have 128 bit values, which were justified in the algorithms section above. These slow operators also required a considerable amount of work to get working, but are explained later. 

| State | Actions/Operations/Purpose | 
| --- | --- |
| 0 | Reset State | 
| 1 | Initiate the computation of A, B, and C as defined in algorithms section above | 
| 32 | Further computations for A, B and C | 
| 64 | A, B, and C are now stable values | 
| 500 | Compute B squared and 4AC | 
| 532 | B squared is now stable | 
| 564 | 4AC is now stable | 
| 1000 | Compare B squared with 4AC. If the discriminant is positive, then there is a collision. If not, then return to reset | 
| 1500 | Compute SQRT(B * B - 4AC) |
| 2000 | Compute the two solutions T1 and T2 for the quadratic equation | 
| 2500 | See if the ray-sphere-intersection is bounded. If it is bounded, then both T1 and T2 should lie between 0 and 1. Otherwise, T1 and T2 must be strictly positive | 
| 2900 | Compute the appropriate X, Y, and Z coordinates of the two points of intersection. Our original derivation used parameterized variables. |
| 3000 | Additional computations (addition) for our parameters | 
| 3200 | Finally, apply division to compute X, Y, Z | 
| 3500 | Our intersection points are stable. Return collision occurs, and the two points at which collision occured. | 

This is our massive state machine. Note that wait states have been noted in large blocks, since there are hundreds of wait states between action states. 

The 3500 states would be quite busy to show in a diagram, so the table above was provided.

We can start, as we did with the RTcore, at the reset state. The reset state is held until the ready signal is set to high. According to our "spec," this signal should be set to high for at least 1 clock cycle, but should be set to low as soon as possible afterwards. This prevents inefficiency of the machine, as leaving the signal at high for an entire computation cycle can cause the state machine to trigger twice, halving the FPS and causing many glitches. 

Upon leaving the reset state, the state machine also copies. This way, the other modules are free to change them in an way that they please during the computation cycle, which does wonders for timing. It also isolates the module to improve debugging. Finally, the ready signal is immediately taken down. One current "issue" with this implementation is that the ready signal only goes down two cycles after the initial enable signal is set to high. A solution would be to make this asynchronous, but this one clock cycle wouldn't save much time in the grand scheme of things anyway. 

The default behavior of the state machine is to go to the next state. The only time that this rule is ever broken is in cases where the state is changed to state 0, the reset state. 

State 1 is where real computations are set up. The current interface with the slow multipliers and adder blocks is that they require inputs, and these inputs stablize after sometime later. In retrospect, it may have been a good idea to use chip enable and ready signals, as are used with ray-sphere-intersect and RTcore, as the state machines would become more robust. For now, though, you have to know whether a operator takes 16 clock cycles, 32 clock cycles or 64 clock cycles. 

We first want to compute the coefficients of the parametric quadratic equation from the earlier sections. To do this, we use our square and slow-multiplier modules (which are the same thing, see explanation later). 

```SystemVerilog
// A
SQUARE_IN[0] <= p1[0] - p0[0];
SQUARE_IN[1] <= p1[1] - p0[1];
SQUARE_IN[2] <= p1[2] - p0[2];
// B computation requires another multiplication by two later on
MULT_A[0] <= p1[0] - p0[0];
MULT_B[0] <= p0[0] - sphere[0];
MULT_A[1] <= p1[1] - p0[1];
MULT_B[1] <= p0[1] - sphere[1];
MULT_A[2] <= p1[2] - p0[2];
MULT_B[2] <= p0[2] - sphere[2];
// C
SQUARE_IN[3] <= p0[0] - sphere[0];
SQUARE_IN[4] <= p0[1] - sphere[1];
SQUARE_IN[5] <= p0[2] - sphere[2];
SQUARE_IN[6] <= sphere[3];
```

Here we can see the structure of our blocks. The multiplier blocks each have two inputs, which are named A and B. Squaring blocks only have one input, which is internally duplicated and multiplied using a regular multiplier element. 

Notice that we use a total of 6 squaring blocks for this computation. While we only have inputs which are 16 bits in length, the square blocks actually support squaring values up to 64 bits in length. This is useful for quickly squaring $b^2$ later on. Similarly, the multipliers have 64 bit inputs and 128 bit outputs supported, but the actual datawidths are all 128 bits for ease of casting and working with signed representations. 

32 clock cycles later, we expect to have a stable result. This corresponds to state 32 (recall that we simply transition to the next state as the default behavior). While the complex computations for A and C have been successfully done, you will recall that B actually requires terms of the form $2 (p_1 - p_0) (p_0 - s_0)$ for each dimension. Our solution to this issue is to do a multiply by two of the sum. 

```SystemVerilog
a <= SQUARE_OUT[0] + SQUARE_OUT[1] + SQUARE_OUT[2];
c <= SQUARE_OUT[3] + SQUARE_OUT[4] + SQUARE_OUT[5] - SQUARE_OUT[6];
MULT_A[0] <= PRODUCT[0] + PRODUCT[1] + PRODUCT[2];
MULT_B[0] <= 2'd2; // multiply by two
```
At this point, we should also analyze our outputs of our computation blocks. The square modules output `SQUARE_OUT` while the multipliers output `PRODUCT`. Since we are using registers everywhere, we can reuse our old multipliers and save on LUTs (more on this later).

32 more states later, we have a stable value for B. This is written to a register, and we move on. 

Up to this point, we have been relatively careful about allocating clock cycles. While this works well in the final design, it was difficult to insert operations and distribute workloads across multiple states without renaming the whole state machine. Furthermore, the number of states in the state machine made it somewhat difficult to name individual states to solve this issue. The hope is that when the project is truly finalized, we will have more conservative distribution of "states" and clock cycles within this module. Either that, or we may use the ready signal and enable signals on the computation blocks to have optimal timing. 

We thus jump to state 500, where our A, B and C values are stable. We now need to compute $B^2$ and $4AC$. To do this, we place $b$ into our SQUARE block, and multiply A and C in the multiplier. After 32 states (clock cycles), we have a stable product. We keep the result of $B^2$ in a temp variable, while we perform another multiply with $4$ and $AC$ to get the last piece of the descriminant. Finally, we store $4AC$ in a second temp variable, and we transition to state 1000. 

At state 1000, we want to do a comparison. It turns out that while comparison is generally considered a cheap operation, this particular comparison is very expensive. So expensive, that it is the top failing path in timing analysis. Since we give a large number of buffer states in-between, the timing barely fails and doesn't reflect in the final result. However, fixing this timing with a "slow comparison" block would be the right thing to do. 

If there is no collision, we reset to state 0. The co lision flag is low, and the ready flag goes up. 
```SystemVerilog
reg_COLLIDE <= 1'b0;
reg_READY <= 1'b1;
state <= 0;
```
This, in general, will be our return behavior. We reset the state, set the ready bit, and set the collision bit. From this point forward, we simply refer to these three operations collectively as "returning." See that it only took us 1000 clock cycles to process a pixel though, best case. If we added further optimizations with the state machine, we could likely get this number down to under 128 clock cycles. A black screen could thus be rendered at 2.5 FPS, without further optimizing the arithmetic operations.

But what of the more interesting case, where a collision does occur? This begins at state 1500 (nothing occurs for 500 clock cycles). At this point, we compute the square root $\sqrt{b^2 - 4ac}$. The interface for the slow square root module is similar to that of the square module, where we simply write to a particular register and wait for the result to stablize. We also use this time to pre-compute a quotient $\frac{a}{\text{DEROUNDER}}$. This will be used later on. 

200 states later, the quotient is stable. We store this in a temporary variable. 

Now, we can find the value of $T_1$ and $T_2$. As mentioned in the algorithms section, we are not performing the divison by $2a$ as we would in the traditional quadratic formula because any integer division rounding would throw out any accuracy that we had. Instead, our formula becomes
```SystemVerilog
T1 <= -b + SQRT[B^2 - 4AC] - (a/DEROUNDER);
```
What does the derounder achieve? It makes it more difficult for collisions to occur. This piece of the algorithm needs to be better understood in the future, but the core idea is that we want to make the value of T1 lower proportional to $a$. Recall that $a$ is computed using a combination of the distance between the two points that define the ray. This means that the further apart these are, the less likely they are to collide. This relation was found mostly experimentally, but it did help smooth out results. ![[Screen Shot 2022-05-11 at 20.07.50.png]] *An example render with the derounder value high (very little smoothing occurs)*
![[Screen Shot 2022-05-11 at 20.08.28.png]] *An example render with a low derounder value (lots of smoothing)*

The reader may notice that having a low derounder value leads to pleasing but inaccurate results. The high value meanwhile is technically more pleasing, but is filled with artifacts. The reason for this is that our points are technically not exactly on the surface of the sphere, but only close as a consequence of our floating point operations being done with fixed point instead. 

![[rounder_motivation.png]]

This often means that our intersection point is inside the sphere, so any ray leaving from the intersection point on the so-called surface would guaranteed have an intersection. By increasing the range for which this doesn't count, we are able to get more aesthetically pleasing results. Experimental testing shows that the best derounder value for most scenes is around 75. 

Thus, this clock cycle sets up the values of the two intersection points $T_1$ and $T_2$, with smoothing applied. 

We then transition to state 2500. The extra states in the middle are meant to handle any timing issues that were not resolved, since this design *technically* runs at 92MHz. This timing issue is something that requires future fixing, but deadlines prevented this from getting patched for the final submission. Excessive intermediate states attempt to fix this instead. 

At this state, we perform a series of checks. First, we check if $T_1$ and $T_2$ are both positive by checking them against the threshold. This is because the threshold controls the lower bound of our intersection point. Note that we have not yet normalized the $T$ values to reflect the actual position from 0 to 1 on our parameterized versions of our functions. 

Our second check is that the value of $a$ should be non-zero. This is because we want to perform a division by $2a$ at the end to "normalize" our $T$ values, and this should be well defined. Note that in most cases, this is going to be the case, but in the rare case that $2a$ is very small, we will treat this as a collision that is not visible. to the viewer. Finally, if our input argument requested a bounded output and our $T$ values exceed $2a$ (that is, $t > 1$), we will treat this as a non-collision since it occurs out of bounds. In all three of these case, we return that no collision occurs. 

Finally, we reach the state where a collision has indeed occured. We use all twelve of our multipliers in this particular case to compute the value of x, y, and z for two intersection points, both of which will be returned. Recall the formula is $z(T) = \frac{T z_1 + (2a - T)z_0}{2a}$, with similar formulas for x and y. A total of two multiplies are used per coordinate, and there are three coordinates per intersection for a total of 12 multiplication operations. These use the in-built multiplier blocks. 

Finally, on cycle 3000, the multipliers are stable. We perform the division by 2a for all 6 cases (X, Y and Z for two collision points). The result is stable before state 3200, when we copy the result into our output buffers. Finally, on state 3500, we can return that a collision did occur, and we return to state 0.

#### Slow Computation Blocks
There are four different types of slow computation blocks.
##### Multiplication
Multiplication traditionally uses the 9 bit multipliers, but when we are multiplying 64 bit numbers together, this computation becomes expensive and can no longer be done using hard blocks alone. Still, the system still uses the built-in blocks for some acceleration, and this can typically be done in just under 8 clock cycles. 

When the multiplication is done initially, the system will infer an ALTERA megafunction. The internal implementation of this is unknown, but we can assume that the timing should be consistent. Just to be safe, we give the system an additional 8 clock cycles to ensure stability, since multiplication is not the main FPS pain point anyway. 

To ensure timing is followed, we **could** use false paths, but instead we opted to put in a slow counter. This is interpreted by the compiler as a slower clock speed, so it will pass the timing analysis, and is relatively easy to see in SystemVerilog. However, moving this to a multicycle path in a future revision of the project would not be a bad idea. 

##### Division
Division was the main reason why the slow computation blocks were created in the first place. The naive approach to this would be to match our multiply operation by infering a higher order division megafunction and timing it to take many clock cycles. However, this causes a particular error:
```error
Error (272006): In lpm_divide megafunction, LPM_WIDTHN must be less than or equals to 64 Error (12154): Can't elaborate inferred hierarchy
```
In other words, the division cannot have a numerator of 128 bits. One solution would simply be to introduce some combinational logic, which would convert this into two 64 bit divisions. 

A 128 bit value can be rewritten as $u \times 2^{64} + l$, where $u$ and $l$ are 64 bit values. A division by a 64 bit value (which is always the case, the largest division factor is 2a after all) can be written as:
$$\frac{u \times 2^{64} + l}{d} = \frac{u}{d} \times 2^{64} + \frac{l}{d}$$This does lose us some higher order accuracy, as this division implementation always floors the quotient. However, for our purposes, this should be good enough. 

The division operation takes around one clock cycle to reduce the place value by one. Thus, a division by a 64 bit value would take 64 clock cycles, which is what we allocate. Once again, to be extra safe, we often pad this up to 100 clock cycles in the state machine. 

It may be better to implement a "fastest possible" module for division. In this case, depending on the number of bits in $d$, the division may take less time than 64 clock cycles (since in most cases, $a$ is the distance between the screen and the camera). This computation would take only the number of bits in the FOV length (approximately) squared, so the division could be done in less than 20 clock cycles in the worst case with a $f = 1000$. We could also start operations early and let more things occur in parallel.

To achieve this, using just the megafunction inference would not be sufficient. Instead, coming up with a division algorithm would be best. We could also probably free up some LUTs by only working on small parts of the division at a time, with rippling effects (bad for speed, but good for clock speed). Of course, to take advantage of this, we would also want a ready signal of sorts and a chip enable. This could improve the timing for ray-sphere-intersect from 3500 cycles worst case to only 400 worst case, giving us a worst case FPS of 0.5 frames per second. A simple sphere test (one object, one light source) would run at 3FPS, which is a significant speedup from previous tests which are around a quarter as fast. 

#### Square
The square is the lamest of the block operations. The main purpose was to cut down on boilerplate code, but this is really just a rebranded multiplication. Just like multiplication, this takes a total of 8 clock cycles to stablize, but is generally given 32 to be extra safe. 

#### Square Root 
This would have been the most expensive operation, if not for an ALTERA megafunction which does most of the heavy lifting. The current configuration of square root takes 32 clock cycles to perform the computation, although this was an arbitrary number that was chosen to be extra safe. The input datawidth is 128 bits, although the megafunction supports up to 256. 

Much like my own modules, the square root megafunction does not have a ready bit or chip enable. Instead, it just takes its time to stablize the result, and the modules interfacing with it must take this into account. A wrapper of this module may have been a good idea to add chip enable and ready communications.

## Modular Design
There were two components of this project. The first is a C-based prototype of the final project, which is currently more capable than the hardware-accelerated version. The other is a System-Verilog implementation which was the final "demo" version. We will discuss the components of both of these. 

### Software
For the software, all of the logic lies in raytracer.c. Within raytracer.c, there are two functions in addition to the main. The raytracer queries each pixel, and writes the appropriate pixels to standard output. This design is capable for rendering spheres in multiple colors (as seen throughout this report) and can have multiple sources of light. The spheres have some basic color separation, but this is not to be confused with through raytracing of colors which is done by diffusion and absorption of light coefficients. Such an implementation would require three rays (although the path of the rays is similar) to be traced instead of a single greyscale intensity variable. 

| Function | Purpose |
| --- | --- |
| main () | Main function. Calls the raytracer program | 
| raytracer () | This function contains the logic analogous to the RTCore and parts of the scene manager. It achieves this by looping through each pixel, computing the intensity/color of that pixel, and writing the result into memory | 
| ray_sphere_intersect() | This function is used by the raytracer function to check if a ray and a sphere intersect. The arguments are nearly identical to the hardware implementation, as is the flow. However, this function does not have any of the slow computation modes enabled. |

The main function simply calls raytracer(), which requires no arguments. This function loops through each XY coordinate in 640 x 480 space. It then uses the algorithms mentioned above to compute the color of each pixel. The color logic is quite basic, it simply detects which color the sphere of intersection is, and multiplies that by the intensity of light entering the camera (shone on the sphere, explained in the sections above). This function also calls the ray_sphere_intersect function, which provides an abstract way of checking whether a given ray intersects with objects within the scene. 

The main difference between this version and the hardware version is the support for multiple objects. At a high level, the pseudo-code for this looks something like the following:

```pseudocode
for each X in [0, 640):
	for each Y in [0, 480):
		for each sphere in the scene:
			check if the camera-screen ray intersects that sphere
		if no sphere intersected the ray:
			return no collision, black color
		otherwise, get the sphere closest to the screen that collided.
		note down the color of the sphere and the first intersection point
		for each light source in the scene:
			for each sphere in the scene:
				check sphere intersects path from light source to the intersection
			if no sphere blocks the path, then increase intensity
				(intensity is increased by I/d^2 as before, with calibration)
			otherwise set the intensity to "shadow"
		Set the pixel color to intensity * color (color has three values)
		Ensure shadow color < pixel color < max brightness (255)
```
The pseudocode should be quite self-explanatory, given the algorithm explanations and derivations in the above sections. 

It was mentioned that the output of this software is sent to standard output. Thus, to run it, compilation and special logic is necessary to write to a file. In unix systems, this would be: 

```bash
./raytracer > traced_result.tga
```

Opening the tga file would result in seeing the rendered scene. 

### Hardware Portion
We have already discussed many of the modules in great detail. Here is an breakdown of the latest release's modules and their parameters. Keep in mind that the descriptions will be brief as many thousands of words provide detail on the operation of this section.

| Module 	| HexDriver | 
| ------ 	| --- | 
| Inputs 	| [3:0] In0 | 
| Outputs 	| [6:0] Out0 |
| Description | This module provides an interface to convert a 4 bit value into a displayable result on HexDisplays |
| Purpose 	| This module was used to drive three hex displays. The hex displays were used to display the X and Y position of the current pixel being drawn, as well as the color of that pixel (for debugging and FPS estimation purposes)|

| Module 	| RTRT | 
| ------ 	| --- | 
| Inputs 	| CLK, [1: 0] KEY, [9: 0] SW| 
| Outputs 	| VGA_HS, VGA_VS, [9: 0] LEDR, [7: 0] HEX0, [7: 0] HEX1, [7: 0] HEX2, [7: 0] HEX3, [7: 0] HEX4, [7: 0] HEX5, [3: 0] VGA_R, VGA_G, VGA_B |
| Description | This module contains a VGA interface and interfaces with the RTCore and OCM to handle the dispatching of rendering particular pixels (and filling the frame buffer) and also reading from the frame buffer to display the output through VGA. |
| Purpose 	| This module serves as a combination of rendering logic and is also the top level module for this project. Future iterations will remove most of this logic and replace it with a dedicated rendering and scene manager module.|

| Module 	| RTCore | 
| ------ 	| --- | 
| Inputs 	| CLK, ENABLE, [9:0] X_in, [8:0] Y_in, [9:0] SW| 
| Outputs 	| OUTPUT_READY, [3:0] OUTPUT_PIXEL |
| Description | Given a single X, Y coordinate, this module uses a ray-sphere intersection module to compute the color of that particular pixel. It uses ENABLE and OUTPUT_READY signals to communicate with an upper level entity. The switches are used to control the intensity of the scene, and the other elements of the scene are also stored within this module as registers (spheres, lights and camera) |
| Purpose 	| This module is used by RTRT to compute the color of a particular XY coordinate. RTRT handles the writing of the pixel into the frame buffer |


| Module 	| vga_controller | 
| ------ 	| --- | 
| Inputs 	| Clk, Reset| 
| Outputs 	| hs, vs, pixel_clk, blank, sync, [9:0] DrawX, DrawY |
| Description | This module generates a 25MHz signal given a **100 MHz** signal as input (pixel clock). It also generates the appropriate control signals for output to a VGA monitor, and provides insights to the state of the VGA monitor to other modules. |
| Purpose 	| This module is used by RTRT to generate DrawX and DrawY signals to decide which pixel to fetch from the framebuffer. It also is used to generate VGA control signals for output. |

| Module 	| divider | 
| ------ 	| --- | 
| Inputs 	| CLK, signed [127:0] numerator, signed [63:0] denominator| 
| Outputs 	| signed [127:0] quotient |
| Description | This module computes the quotient of a 128 bit numerator divided by a 64 bit denominator in 64 clock cycles while satisfying th 100MHz timing requirement. This was achieved using a slow clock to drive the input-output registers. |
| Purpose 	| This module is used by the RTCore and ray_sphere_intersection modules for large computations that need to satisfy timing requirements (cannot be done combinationally) |

| Module 	| multiplier | 
| ------ 	| --- | 
| Inputs 	| CLK, signed [127:0] NUMA, signed [127:0] NUMB| 
| Outputs 	| signed [127:0] PRODUCT |
| Description | This module computes the quotient of a 128 bit NUMA divided by a 128 bit NUMB in 16 clock cycles while satisfying th 100MHz timing requirement. This was achieved using a slow clock to drive the input-output registers. |
| Purpose 	| This module is used by the RTCore and ray_sphere_intersection modules for large computations that need to satisfy timing requirements (cannot be done combinationally) |

| Module 	| ray_sphere_intersection | 
| ------ 	| --- | 
| Inputs 	| CLK, ENABLE, in_BOUNDED, [3:0] in_THRESHOLD, [15:0] in_sphere [4], [15:0] in_p0 [3], [15:0] in_p1[3]| 
| Outputs 	| READY, COLLIDE, [15:0] pint0[3], [15:0] pint1[3] |
| Description | This module determines (using 3501 clock cycles, worst case) if the ray formed by in_p0 and in_p1, two cartesian points, intersects with the sphere in_sphere. If such an intersection exists, the two points of intersection are returned. |
| Purpose 	| This module was used to determine the collisions between rays and objects in the scene by the RTCore module. |

| Module 	| square | 
| ------ 	| --- | 
| Inputs 	| CLK, signed [63:0] NUM| 
| Outputs 	| signed [127:0] SQUARE |
| Description | This module uses a multiplier to compute the square of NUM. |
| Purpose 	| This module is used by the RTCore and ray_sphere_intersection modules for large square computations that need to satisfy timing requirements (cannot be done combinationally) |

| Module 	| single_port_ocm | 
| ------ 	| --- | 
| Inputs 	| CLK, WE, [18:0] ADDRESS, [3:0] DATA_IN| 
| Outputs 	| [3:0] DATAOUT |
| Description | This module instantiates a modified version of OCM which has lower latency and datawidth than possible using the megafunction. It also contains some logic to work as a framebuffer. |
| Purpose 	| This module is used by RTRT to help create the framebuffer for this project, with 4 bits per pixel. |

Any other included modules are exclusively for the purpose of simulation, or are unused placeholders. 

## Results and Verification
### Simulation Results
ModelSim was used to test the core pieces of the project, the RTCore and the ray_sphere intersect modules. A unified tester (which requires a large time to run and show reasonable results) was used to show that the different pieces were working.

This first simulation is just for rendering a single frame. Note that the timing is off because the clock speed has been slowed by a factor of four. ![[big_picture.PNG]]

This result is pretty useless though. We can see that for rows and columns where the sphere does not appear, the result is dark. This is good! However, we cannot verify the operation of the internal pieces. 

![[y_values.PNG]] Zooming in a bit, we can now make out individual rows for Y. The shading at the start and end of each row (where no sphere is) are dark, as expected. The shading within each row, however, is harder to analyze. We need to zoom in further. 

![[on_border.PNG]] Here we are just bordering the sphere. This means that our shading will be brightly lit in some pixels, and dark on others. Every other pixel is lit because we are *just* touching the ray trace on this particular row. 

Simulation appears to indicate that our behavior is as expected. We can now view the direct results from the FPGA!

### Rendered Results
![[Screen Shot 2022-05-11 at 22.40.58.png]] *A frame from the animation used for the demo, captured in high quality.*

![[Screen Shot 2022-05-11 at 22.42.22.png]] *A low FOV version of the final render capture (not shown during demo)*
![[Screen Shot 2022-05-11 at 22.43.53.png]] *A more-complex multi-sphere render done using the C-program*
## Design Statistics
| Design Resource | Resource Count |
| --------------- | -------------- |
| LUT             | 37,918 |
| DSP  Multipliers| 154 |
| BRAM            | 1,228,800 |
| Flip Flop       | 11,018  |
| Frequency       | 91.26 MHz |
| Static Power    | 0.111 W |
| Dynamic Power   | 2.459 W |
| Total Power     | 2.582 W |

Granted, this is a large amount of power for an FPGA. But the real question is, what is the performance per watt? 

On my i7 notebook, the frame rate computed was 65 FPS. The corresponding TDP is around 25W, which can be used as a rough estimate of the power consumption doing this task. Meanwhile, the FPGA used around 2.5W for 0.7 FPS. Without computing anything, the efficiency of the FPGA implementation of raytracing is downright awful.

## Difficulty
**I believe that the final version of this project should receive atleast a 9 on the difficulty scale.** 

The core difficulty in this project is related to researching algorithms and implementations that satisfy the high data-width and clock frequencies as required by this project. In the base version of my project, my goal was to create a rasterized, unshaded and unlit version of a sphere on a screen with a functional frame buffer. According to the proposal *feedback*, the difficulty of achieving this base functionality was a 7/10. ![[Screen Shot 2022-05-11 at 22.09.01.png]] *Rasterized, unshaded and unlit image of the scene. Note that this has two objects, which was not in the original proposal.*

Now, the first improvement beyond the proposal is the increased scene size. Note that while there is no way to control the scene size with inputs at the moment, internally it is simply a register value that can be changed with animation. This is the reason why the 128 bit width is used for so many computations in the first place!

Another feature which was in the proposal was the non-orthographic camera. As shown by distortion due to smaller values for FOV, it is possible for the FOV to be non-orthographic, that is, there is a "real" FOV and focal length for this camera. 

Raytraced lighting does implement shadows in the final render. These are seen by the instant drop off of light when the surface of the sphere no longer has direct exposure to light. As a bonus, the inverse square relation for light is also implemented, which is the source of the shading. 

Robust controllers were also implemented. This is the dynamic frame rate that was implemented on a per-pixel basis, which was an essential feature of this project to get high quality renders for each frame. 

On the topic of frame, some basic animation was realized. The low frame rate (0.7FPS on the FPGA) made this animation somewhat anti-climatic, but animation is at least partially functional.

Given that in addition to the 7/10 difficulty, I also implemented many of the other "additional features" in my proposal, I believe that I should get at least an 8/10 for difficulty. 

However, I think that the more impressive component of this project, in terms of difficulty, is the design of algorithms to redefine the division, multiplication, square root and on chip memory logic to run at the necessary speeds to maximize the frame rate. In this case, I used a 100MHz PLL to accelerate the 50MHz clock. The difficulty of designing this algorithms was further increased because existing raytracing algorithms on the internet are all in at least one of three categories: 
1. Use floating point, which is something that I don't want to use to maximize efficiency
2. Work with triangles instead of spheres, which increases the computational power needed to render a scene containing a series of spheres
3. Software-assisted raytracing, while my implementation is purely hardware
A majority of my time was spent working on algorithms that function in fixed point, purely in hardware, and are able to render simple scenes in realtime on a small FPGA. The uniqueness of this project definitely contributed to the difficulty score. 

I think that the work on the c-code and algorithm design necessary bump me up to a 9/10 for difficulty for this final project. This report contains the derivations necessary for any justification. Specifically, the written description section contains an overview of my methods, why my implementation was particularly difficult, and justifies a 9/10 difficulty score. 

## Conclusions
Overall, this project was primarily useful as a learning experience about raytracing. I also learned a great deal about FPGAs, timing in hardware and algorithms that use parallelism. While it was disappointing that the LUTs ran out on the FPGA much faster than intended, I still believe that with some additional work, this project will be capable of matching the performance of an i7 CPU by taking advantage of parallelism. The primary bottlenecks at the moment are the bit length, which can be solved with further analysis, memory usage, which could be fixed by using SDRAM, and finally, timing, which can be fixed with modules with ready signals. Most of my extensions for this project have been sprinkled throughout the report, hopefully I'm able to improve on this over the summer. 