# Unserstanding Face Tracking from Apple's Sample Code

After searching for some time, I realized that there are no easy tutorials on the internet for Face Tracking with Apple's [Vision](https://developer.apple.com/documentation/vision) Framework, so I decided to give Apple's own [sample code](https://developer.apple.com/documentation/vision/tracking_the_user_s_face_in_real_time) a try. At the moment I'm trying to understand the easiest way to track and follow the face of any person in front of the camera.  

## First Steps

In order to make it work on my devices I had to change the iOS Target from 12.0 to 11.4. Then in the `AddDelegate` file I changed this code `UIApplication.LaunchOptionsKey` to `UIApplicationLaunchOptionsKey`.  
After that I removed all the code regarding "Face Landmarks" as I only wanted to track a Rectangle around the tracked face(s), and as a last setup step I decided to move some of the code to a new class called `CameraSetup`, in order to visualize more easily what is going on. 

## Development
At the moment I'd like to add a transparent .png over the face, and to flip the camera from front to back following a swiping gesture. 

